# Ubuntu 21.04 x64
1. Install OS

2. Install needed software

  Optionally, install general-purpose tools, like `Go`, `Python`, compilers:

  ```
  sudo apt update && sudo apt full-upgrade -y
  # installing Python 3
  sudo apt install python3 python3-pip python3-venv -y
  pip install setuptools wheel
  # installing R with dependencies
  sudo apt install dirmngr gnupg apt-transport-https ca-certificates software-properties-common build-essential -y
  sudo apt install r-base-dev
  # Installing RUST
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  # Installing Haskell
  sudo apt-get install haskell-platform
  # Installing Julia
  sudo apt install julia
  # installing JDK
  # search, what is available with
  sudo apt search openjdk
  # install the freshest version. So far it is
  sudo apt install openjdk-16-jdk
  # installing Golang
  sudo apt install golang-go
  # Installing assembler
  sudo apt install nasm
  # Installing fortran
  sudo apt install gfortran
  # Installing Perl
  sudo apt install perl
  # general purpose libraries
  sudo apt install zlib1g cmake gzip bzip2 unzip gcc dos2unix
  # multi-thread calculations
  sudo apt install mpich
  pip install mpi4py h5py
  # media processing
  sudo apt install ffmpeg opus-tools
  sudo apt install ubuntu-restricted-extras
  ```

3. Install SLURM / Munge
```
sudo apt install munge libmunge-dev slurm-wlm slurm-wlm-doc -y
```
and generate munge keys:
```
sudo systemctl start munge
sudo /usr/sbin/mungekey
sudo chown munge /etc/munge/munge.key
```

NB!: Before, the key file was created by `sudo /usr/sbin/create-munge-key -r`. Since [March](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=693786) this was changed to command above.
Alternatively, the Munge key file can be  created as :
- `dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key`
- `dd if=/dev/random bs=1 count=1024 > /etc/munge/munge.key`


and try if that worked:
```
munge -n | unmunge
```
If yes: enable munge at autostart:
```
sudo systemctl enable munge
```

4.  Collect the info regarding the node itself:

```
slurmd -C
```

```
NodeName=station CPUs=4 Boards=1 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=1 RealMemory=15903
UpTime=0-00:28:47
```


5. Edit SLURM Settings

5.1 Built-in editor on local machine or web-configurator

  From desktop environment open file `/usr/share/doc/slurm-wlm/html/configurator.html` with any web browser and:
  - Fix your hostname in `SlurmctldHost` and `NodeName`
  - Adjust values of `CPU`, `Sockets`, `CoresPerSocket` and `ThreadsPerCore` according to output of `slurmd -C`
  - Set `RealMemory` below the `RealMemory` of `slurmd -C` output to limit, what the SLURM task can use
  - Specify `StateSaveLocation` as `/var/spool/slurm-llnl`
  - Change `ProctrackType` value to `linuxproc`
  - Set `SelectType` to `Cons_res`; and `SelectTypeParameters` to `CR_Core_Memory`
  - Set `ReturnToService` to `2`

  Click `Generate` button and copy the output to `/etc/slurm-llnl/slurm.conf` file.

  If you can't open th e configurator locally, you can use the [online-version](https://slurm.schedmd.com/configurator.html) and then copy the content to the machine. BUT! Online configurator is available for the most recent version only! Check if it matches the installation.

  NB!: If needed to make sure that machine works only with one task simultaneously, adjust the partition description in the end of file from something like this:

  ```
  NodeName=station CPUs=4 RealMemory=15903 CoresPerSocket=4 ThreadsPerCore=1 State=UNKNOWN
  PartitionName=debug Nodes=station Default=YES MaxTime=INFINITE State=UP
  ```

  To something like this:

  ```
  NodeName=station CPUs=4 RealMemory=15903 CoresPerSocket=4 ThreadsPerCore=1 State=UNKNOWN
  PartitionName=debug Nodes=station Default=YES MaxTime=INFINITE State=UP Shared=EXCLUSIVE
  ```

5.2 Write it from scratch

  Use the following template, edit as you need and place it at `/etc/slurm-llnl/slurm.conf`

  ```
  SlurmctldHost=<put_name_of_your_node_here>
  #MaxJobCount=5000
  MpiDefault=none
  #MpiParams=ports=#-#
  ProctrackType=proctrack/linuxproc
  ReturnToService=2
  SlurmctldPidFile=/var/run/slurmctld.pid
  SlurmctldPort=6817
  SlurmdPidFile=/var/run/slurmd.pid
  SlurmdPort=6818
  SlurmdSpoolDir=/var/spool/slurmd
  SlurmUser=slurm
  StateSaveLocation=/var/spool/slurm-llnl
  SwitchType=switch/none
  TaskPlugin=task/affinity

  # TIMERS
  InactiveLimit=0
  KillWait=30
  MinJobAge=300
  SlurmctldTimeout=120
  SlurmdTimeout=300
  Waittime=0

  # SCHEDULING
  SchedulerType=sched/backfill
  SelectType=select/cons_res
  SelectTypeParameters=CR_Core_Memory

  # LOGGING AND ACCOUNTING
  AccountingStorageType=accounting_storage/none
  AccountingStoreJobComment=YES
  ClusterName=<pick_a_random_name_here>
  JobCompType=jobcomp/none
  JobAcctGatherFrequency=30
  JobAcctGatherType=jobacct_gather/none
  SlurmctldDebug=info
  SlurmdDebug=info

  # COMPUTE NODES
  # the following line should be from `slurmd -C` output
  NodeName=<put_name_of_your_node_here> CPUs=16 Boards=1 SocketsPerBoard=1 CoresPerSocket=8 ThreadsPerCore=2 RealMemory=<make_it_lower_than_real_memory>
  PartitionName=<put_a _randome_name_here> Nodes=<put_name_of_your_node_here> Default=YES MaxTime=INFINITE State=UP Shared=EXCLUSIVE
  ```

6. Test settings:

```
sudo mkdir -p /var/spool/slurm-llnl
sudo touch /var/log/slurm_jobacct.log
sudo chown slurm:slurm /var/spool/slurm-llnl /var/log/slurm_jobacct.log
```

```
sudo systemctl start slurmd
sudo systemctl start slurmctld
time srun -n$(nproc) sleep 1
```

if everything is fine:
```
sudo systemctl enable slurmd
sudo systemctl enable slurmctld
```
