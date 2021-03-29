# Ubuntu 20.04 LTS x64
1. Install OS

2. Install needed software

3. Install SLURM / Munge
```
sudo apt install munge libmunge-dev slurm-wlm slurm-wlm-doc -y
```
  and generate munge keys:
```
sudo systemctl start munge
sudo /usr/sbin/create-munge-key -r
```
and try id that worked:
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

5.1. Built-in editor on local machine or web-configurator

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

6. Test settings:

```
sudo mkdir -p /var/spool/slurm-llnl
sudo touch /var/log/slurm_jobacct.log
sudo chown slurm:slurm /var/spool/slurm-llnl /var/log/slurm_jobacct.log
```

```
sudo systemctl start slurmd
sudo systemctl start slurmctld
# modify -n key with number of processors in your CPU
time srun -n4 sleep 1
```

if everything is fine:
```
sudo systemctl enable slurmd
sudo systemctl enable slurmctld
```
