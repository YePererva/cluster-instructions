1. Install OS

2. Install needed software

3. Install SLURM / Munge

```
sudo dnf -y install munge munge-libs munge-devel slurm slurm-perlapi slurm-slurmd slurm-slurmctld slurm-torque
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

P.S. Just in case, you can check the version of SLURM via `sinfo -V`


4.  Collect the info regarding the node itself:

```
slurmd -C
```

```
NodeName=localhost CPUs=4 Boards=1 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=1 RealMemory=3818
UpTime=0-00:28:47
```

5. Edit `/etc/slurm/slurm.conf`

Edit content of following parameters:

```
ControlMachine=localhost
ControlAddr=127.0.0.1
ReturnToService=2
ClusterName=nosferatu
ProctrackType=proctrack/linuxproc
```

```
# COMPUTE NODES
NodeName=localhost CPUs=4 Boards=1 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=1 RealMemory=3818
# PARTITIONS
PartitionName=nosferatu Nodes=localhost Default=YES MaxTime=INFINITE State=UP Shared=EXCLUSIVE
```

6. Test settings:
```
sudo systemctl start slurmd
sudo systemctl start slurmctld
# modify -n key with number of processors in your CPU
time srun -n4 sleep 1
```


7. Set-up shared storage

Assuming, the node has a separate HDD/SSD as `sdb1` for sharing inside the network and it has IP `192.168.1.100`

### Prepare the separate HDD / SSD for NFS share

Install the second HDD/SSD or other disk, which is needed to share as storage across all nodes.

Find the needed one with `sudo fdisk -l` or `sudo lsblk`. Assuming the target is `/dev/sdb`.

### Deleting all partitions
- Type `sudo fdisk /dev/sdb`
- Type `d` to proceed to delete a partition
- Type `1` to select the 1st partition and press `Enter`. If disk contains only one partition it will be deleted instantly at `d`
- Repeat deletion for other partitions on disk

### Creating a partition
```
sudo fdisk /dev/sdb
```
- Type `n` to create a new partition
- Type `p` to indicate a primary partition
- Press `ENTER` to accept the default partition number
- Press `ENTER` to accept the default starting sector
- Press `ENTER` to accept the default ending sector
  - There could be message:
  ```
  Partition #1 contains a *** signature.

  Do you want to remove the signature? [Y]es/[N]o:
  ```
  Confirm deletion and proceed
- Type `p` again to print a list of partitions
- If everything is correct, `w` to write the change.

This will create a partition `/dev/sdb1`. Now, create the file system there (may need to unmount it first: `sudo umount /dev/sdb1`):
- for ext4 : `sudo mkfs.ext4 /dev/sdb1`
- for ntfs : `sudo mkfs.ntfs /dev/sdb1`
    NB! : requires `sudo dnf install -y ntfs-3g`
- for FAT32 : `sudo mkfs.vfat /dev/sdb1`
    NB! : Don't use this. Not suitable for files > 4 GB

### Automatic mounting of after each reboot
- check mounting of `sdb1` to `/storage`:
  ```
  sudo mount /dev/sdb1 /storage
  df -hT
  ```
- set automount with `/etc/fstab`:
  - with partition label `/dev/sdb1`
      - for ext4 filesystem:
    ```
    /dev/sdb1 /storage  ext4  defaults  0 0
    ```
      - for ntfs:
    ```
    /dev/sdb1 /storage  ntfs  defaults  0 0
    ```
  - with drive ID. Obtain it with `sudo blkid`
    NB! Without `sudo` not always show the mounted USB drives.
    Output should looks like:
    ```
    /dev/sdb1: UUID="16a7e9b6-896e-4c48-8172-3d89b8472830" TYPE="ext4" PARTUUID="16dae6bc-01"
    ```
    The target is `UUID="16a7e9b6-896e-4c48-8172-3d89b8472830"`.
    ```
    UUID=16a7e9b6-896e-4c48-8172-3d89b8472830 /storage  ext4  defaults  0 0
    ```
    for ntfs:
    ```
    UUID=16a7e9b6-896e-4c48-8172-3d89b8472830 /storage  ntfs  defaults  0 0
    ```

For some reason, I lost a permission to write into `/storage` folder, needed to reassign it:
```
sudo chown -R nobody.nogroup /storage
sudo chmod -R 777 /storage
```

### Setting the NFS share
Edit file `/etc/exports` to add the storage based on template:
`path_to_share_folder IP_range/Netmask(parameters)`

In our case:
`/storage 10.42.42.0/24(rw,sync,no_root_squash,no_subtree_check)`

Now start and enable auto-start of NFS services:
```
sudo systemctl start rpcbind nfs-server
sudo systemctl status rpcbind nfs-server
sudo systemctl enable rpcbind nfs-server
```

Add those services to firewall exceptions:
```
sudo firewall-cmd --add-service={nfs,mountd,rpc-bind} --permanent
sudo firewall-cmd --reload
```

You can always check, what is allowed via running:
```
firewall-cmd --list-services
```

**NB! :** For Linux environment - don't used SMB for sharing files between nodes. It is [slower](https://ferhatakgun.com/network-share-performance-differences-between-nfs-smb/). SAMBA (SMB) still can be usable to have access to files from Windows.

8. Cloud storage synchronization

  8.1. Mega

Check the latest version of client [here](https://mega.nz/linux/MEGAsync/) and download them:
```
wget https://mega.nz/linux/MEGAsync/Fedora_33/x86_64/megasync-4.3.8-1.1.x86_64.rpm
wget https://mega.nz/linux/MEGAsync/Fedora_33/x86_64/megacmd-1.4.0-2.1.x86_64.rpm
wget https://mega.nz/linux/MEGAsync/Fedora_33/x86_64/nautilus-megasync-3.6.6-2.1.x86_64.rpm
```

And install them:
```
rpm -i megasync-*.rpm  nautilus-megasync-*.rpm megacmd-*.rpm
```
