# Ubuntu Desktop as Single Node Variation

In this "tutorial" I consider the 64-bit Ubuntu:
- latest revision (currently Ubuntu 21.04)
- latest LTS (currently Ubuntu 20.04.3 LTS)

If there are differences in set-up, I'll mention it!

## Before we start
Make sure, you have a computer which is computational enough to run software you need. I also prefer to have PC with 2 disk:
- high-speed SSD (preferably, NVME) with at least 512 GB
- large HDD with at least 2 TB

## Instructions

1. Install OS
  - install it to the high-speed SSD
  - select auto-mounting of HDD as `/storage`

2. Install needed software

  2.1. General purpose tools and programming languages interpreters / compilers

  ```
  sudo apt update && sudo apt full-upgrade -y
  # general purpose libraries /utilities
  sudo apt install zlib1g cmake gzip bzip2 unzip gcc dos2unix curl build-essential -y
  # installing Python 3
  sudo apt install python3 python3-pip python3-venv -y
  pip install setuptools wheel
  # Conda for Python 3
  # go to https://www.anaconda.com/products/individual to check the latest release and get its link
  wget https://repo.anaconda.com/archive/Anaconda3-2021.05-Linux-x86_64.sh
  bash Anaconda3*.sh
  # set hooks
  /home/username/anaconda3/bin/conda shell.bash hook
  /home/username/anaconda3/bin/conda init
  conda config --set auto_activate_base false
  # installing R with dependencies
  sudo apt install dirmngr gnupg apt-transport-https ca-certificates software-properties-common -y
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
  # Installing COBOL
  sudo apt install open-cobol
  # Installing Delphi / Object Pascal / Lazarus
  sudo apt install lazarus
  # multi-thread calculations
  sudo apt install mpich
  pip install mpi4py h5py
  # media processing
  sudo apt install ffmpeg opus-tools ubuntu-restricted-extras
  # network shared utilities
  sudo apt install samba ntfs-3g nfs-common nfs-kernel-server netatalk
  ```

3. Install SLURM / Munge

  Install packages from repositories
  ```
  sudo apt install munge libmunge-dev slurm-wlm slurm-wlm-doc -y
  ```

4. Edit Slurm / Munge settings

  4.1. Generate `munge` encryption keys:
  ```
  sudo /usr/sbin/mungekey
  sudo chown munge /etc/munge/munge.key
  sudo systemctl start munge
  ```

  **NB!**: Before, the key file was created by `sudo /usr/sbin/create-munge-key -r`. Since [March 2021](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=693786) this was changed to command above.
  Alternatively, the Munge key file can be  created as :
  - `dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key`
  - `dd if=/dev/random bs=1 count=1024 > /etc/munge/munge.key`

  Try if that worked:
  ```
  munge -n | unmunge
  ```

  If yes: enable munge at autostart:
  ```
  sudo systemctl enable munge
  ```

  4.2 Collect the information of computer itself:
  ```
  slurmd -C
  ```
  The output should be alike
  ```
  NodeName=station CPUs=4 Boards=1 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=1 RealMemory=15894
  UpTime=0-00:28:47
  ```
  Discard part with `UpTime...` and reduce the `RealMemory` parameter by at least 0.5 GB (approximately), prepare that part as:

  ```
  NodeName=station CPUs=4 Boards=1 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=1 RealMemory=15000
  ```

  4.3 Create SLURM config file
  The location **DIFFERS** across distributions:
  - `/etc/slurm-llnl/slurm.conf` : Ubuntu 20.04 LTS and SLURM 20xxx
  - `/etc/slurm/slurm.conf` : Ubuntu 21.04 + SLURM 20.11.4

  4.3.a Built-in editor on local machine or web-configurator

  From desktop environment open file `/usr/share/doc/slurm-wlm/html/configurator.html` with any web browser and:
  - Fix your hostname in `SlurmctldHost` and `NodeName`
  - Adjust values of `CPU`, `Sockets`, `CoresPerSocket` and `ThreadsPerCore` according to output of `slurmd -C`
  - Set `RealMemory` below the `RealMemory` of `slurmd -C` output to limit, what the SLURM task can use
  - Specify `StateSaveLocation` as `/var/spool/slurm`
  - Change `ProctrackType` value to `linuxproc`
  - Set `SelectType` to `Cons_res`; and `SelectTypeParameters` to `CR_Core_Memory`
  - Set `ReturnToService` to `2`

  Click `Generate` button and copy the output to `/etc/slurm-llnl/slurm.conf` file.

  If you can't open the configurator locally, you can use the [online-version](https://slurm.schedmd.com/configurator.html) and then copy the content to the machine. BUT! Online configurator is available for the most recent version only! Check if it matches the installation.

  **NB!**: If needed to make sure that machine works only with one task simultaneously, adjust the partition description in the end of file from something like this:
  ```
  NodeName=station CPUs=4 Boards=1 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=1 RealMemory=15000
  PartitionName=debug Nodes=station Default=YES MaxTime=INFINITE State=UP
  ```
  To something like this:
  ```
  NodeName=station CPUs=4 Boards=1 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=1 RealMemory=15000
  PartitionName=debug Nodes=station Default=YES MaxTime=INFINITE State=UP Shared=EXCLUSIVE
  ```

  4.3.b Write it from scratch [I prefer this option!]

  Use the following template:

  ```
# slurm.conf file generated by configurator.html.
# Put this file on all nodes of your cluster.
# See the slurm.conf man page for more information.
#
SlurmctldHost=station
#SlurmctldHost=
#
#DisableRootJobs=NO
#EnforcePartLimits=NO
#Epilog=
#EpilogSlurmctld=
#FirstJobId=1
#MaxJobId=999999
#GresTypes=
#GroupUpdateForce=0
#GroupUpdateTime=600
#JobFileAppend=0
#JobRequeue=1
#JobSubmitPlugins=1
#KillOnBadExit=0
#LaunchType=launch/slurm
#Licenses=foo*4,bar
#MailProg=/bin/mail
#MaxJobCount=5000
#MaxStepCount=40000
#MaxTasksPerNode=128
MpiDefault=none
#MpiParams=ports=#-#
#PluginDir=
#PlugStackConfig=
#PrivateData=jobs
ProctrackType=proctrack/linuxproc
#Prolog=
#PrologFlags=
#PrologSlurmctld=
#PropagatePrioProcess=0
#PropagateResourceLimits=
#PropagateResourceLimitsExcept=
#RebootProgram=
ReturnToService=2
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmctldPort=6817
SlurmdPidFile=/var/run/slurmd.pid
SlurmdPort=6818
SlurmdSpoolDir=/var/spool/slurmd
SlurmUser=slurm
#SlurmdUser=root
#SrunEpilog=
#SrunProlog=
StateSaveLocation=/var/spool/slurm_state
SwitchType=switch/none
#TaskEpilog=
TaskPlugin=task/affinity
#TaskProlog=
#TopologyPlugin=topology/tree
#TmpFS=/tmp
#TrackWCKey=no
#TreeWidth=
#UnkillableStepProgram=
#UsePAM=0
#
#
# TIMERS
#BatchStartTimeout=10
#CompleteWait=0
#EpilogMsgTime=2000
#GetEnvTimeout=2
#HealthCheckInterval=0
#HealthCheckProgram=
InactiveLimit=0
KillWait=30
#MessageTimeout=10
#ResvOverRun=0
MinJobAge=300
#OverTimeLimit=0
SlurmctldTimeout=120
SlurmdTimeout=300
#UnkillableStepTimeout=60
#VSizeFactor=0
Waittime=0
#
#
# SCHEDULING
#DefMemPerCPU=0
#MaxMemPerCPU=0
#SchedulerTimeSlice=30
SchedulerType=sched/backfill
SelectType=select/cons_res
SelectTypeParameters=CR_Core
#
#
# JOB PRIORITY
#PriorityFlags=
#PriorityType=priority/basic
#PriorityDecayHalfLife=
#PriorityCalcPeriod=
#PriorityFavorSmall=
#PriorityMaxAge=
#PriorityUsageResetPeriod=
#PriorityWeightAge=
#PriorityWeightFairshare=
#PriorityWeightJobSize=
#PriorityWeightPartition=
#PriorityWeightQOS=
#
#
# LOGGING AND ACCOUNTING
#AccountingStorageEnforce=0
#AccountingStorageHost=
#AccountingStoragePass=
#AccountingStoragePort=
AccountingStorageType=accounting_storage/none
#AccountingStorageUser=
AccountingStoreJobComment=YES
ClusterName=cluster
#DebugFlags=
#JobCompHost=
#JobCompLoc=
#JobCompPass=
#JobCompPort=
JobCompType=jobcomp/none
#JobCompUser=
#JobContainerType=job_container/none
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=debug
SlurmctldLogFile=/var/log/slurmctld.log
SlurmdDebug=debug
SlurmdLogFile=/var/log/slurmd.log
#SlurmSchedLogFile=
#SlurmSchedLogLevel=
#
#
# POWER SAVE SUPPORT FOR IDLE NODES (optional)
#SuspendProgram=
#ResumeProgram=
#SuspendTimeout=
#ResumeTimeout=
#ResumeRate=
#SuspendExcNodes=
#SuspendExcParts=
#SuspendRate=
#SuspendTime=
#
#
# COMPUTE NODES
# this line should be taken as output from slurmd -C
NodeName=station CPUs=4 Boards=1 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=1 RealMemory=15000
PartitionName=debug Nodes=station Default=YES MaxTime=INFINITE State=UP Shared=EXCLUSIVE
  ```

5.4. Test settings:

```
Creating and owning folders from SlurmdSpoolDir and StateSaveLocation
sudo mkdir -p /var/spool/slurmd /var/spool/slurm_state
sudo chown slurm: /var/spool/slurmd /var/spool/slurm_state

# Creating and owning files from SlurmctldPidFile and SlurmdPidFile
sudo touch /var/run/slurmctld.pid /var/run/slurmd.pid
sudo chown slurm: /var/run/slurmctld.pid /var/run/slurmd.pid

# Owning the  config file itself
sudo chown slurm: /etc/slurm/slurm.conf
# or for previous versions of slurm
sudo chown slurm: /etc/slurm-llnl/slurm.conf
```

Actually testing the settings:
```
sudo systemctl start slurmd slurmctld
srun -n$(nproc) echo "Hello!"
```

If everything is fine:
```
sudo systemctl enable slurmd slurmctld
```

**NB!** : for some reason with SLURM 20.11.4 and Ubuntu 21.04 there is a problem when neither Slurm nor Slurmctld do not start at autostart of system, but starts perfectly later with manual `sudo systemctl restart slurmd slurmctld`. To fix it edit `slurmd` and `slurmctld` and add part:
```
[Unit]
After=network-online.target munge.service
Wants=network-online.target
```
when calling `sudo systemctl edit slurmd` and `sudo systemctl edit slurmctld`
