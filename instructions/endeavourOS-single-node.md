# EndeavourOS 2021.08.27

[Latest release](https://endeavouros.com/latest-release/)

Assuming, you'll use it remotely from another PC in your network. Hereinafter:
- `target` is a computer used as a single node
- `host` another PC from which you're accessing the `target`

## 00. Media preparation

Used [Rufus](https://rufus.ie/en/) 3.17 to prepare bootable USB with parameters:
- Partition Scheme : `GTP`
- Target System : `UEFI (non CMS)`
- File System : `FAT32` (Important! Didn't boot if `NTFS` was selected)

## 01. Install OS


## 02. Create the SSH channel from your PC to the target
After booting to `target`:
```
# update system
sudo pacman -Syu
# install openssh
sudo pacman -S openssh
# make it autostart
sudo systemctl enable --now sshd
# make sure it works
sudo systemctl status sshd
# create empty folder and key file for further use
mkdir ~/.ssh
touch ~/.ssh/authorized_keys
# get the IP address of target
ip a
```

Now, test the connection from the `host`. If everything is good, make an password-less remote login:

```
# running on the host
ssh-keygen -t rsa -b 4096
cat ~/.ssh/id_rsa.pub | ssh target_username@target_ip 'cat >> ~/.ssh/authorized_keys'
```

If your username on the `target` is different from `host` username or you just don't want to enter it manually every time, create `~/.ssh/config` on the `host` and fill it out according to template:
```
Host target_host_name
    HostName target_ip
    User target_username
    Port port
```

Now, the target should be available just by running `ssh target_host_name` from the `host` terminal.

### Preventing sleeping

```
# prevent system from sleep/hibernate/suspend
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
# now, the reboot is required
sudo reboot
```

After reboot check if it worked:
```
sudo systemctl status sleep.target suspend.target hibernate.target hybrid-sleep.target
```

Also, edit `/etc/systemd/logind.conf` to have following:

```
[Login]
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
```

## 03. Installing general purpose tools
On the `target` run:

```
sudo -i
# update everything
pacman -Syu
# archiving and building
pacman -S base-devel haskell-zlib zlib gzip bzip2 unzip cmake dos2unix
# network
pacman -S rpcbind git
# disk utilities
pacman -S ntfs-3g hdf5 samba nfs-utils afpfs-ng gvfs-smb
# GCC, Fortran compilers
pacman -S gcc gcc-libs gcc-d gcc-fortran
# Java JDK
pacman -S jdk-openjdk
# Python additions
pacman -S python-setuptools python-pip python-wheel python-tensorflow python-matplotlib python-h5py
# Golang
pacman -S go
# Perl
pacman -S perl
# Assembler
pacman -S nasm
# COBOL
pacman -S gnucobol
# Delphi / Object Pascal / Lazarus
pacman -S lazarus lazarus-qt5
# Haskell
pacman -S ghc
# LaTeX
pacman -S texlive-core texlive-latexextra
# C#
pacman -S dotnet-runtime dotnet-sdk
# If needed PowerShell in Linux from .NET
dotnet tool install --global PowerShell

# R-studio
yay -S rstudio-desktop

# MPICH
yay -S mpich
pacman -S python-mpi4py python-matplotlib python-tensorflow

# RUST
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

## 04. Mounting additional disks

Here is assumed having the second HDD in the PC as `/dev/sdb`. Endeavour OS by default wouldn't mount it.
Needed to:
- remove all existing partition on disk
- create the new partition
- format the partition, either `ext4` ot `ntfs`:
  - `ext4`:
  - `ntfs`:
- make it automatically mounted at system start-up

### Preparing the disk partition

```
sudo fdisk /dev/sdb
```
Now, the terminal will switch to `fdisk` interface:
- Type `d` to proceed to delete a partition
- Type `1` to select the 1st partition and press `Enter`. \
  If disk contains only one partition it will be deleted instantly at `d`
- Repeat deletion for other partitions on disk
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
- If everything is correct, `w` to write the change

This will create a partition `/dev/sdb1`
- for `ext4` : `sudo mkfs.ext4 /dev/sdb1`
- for `ntfs` : `sudo mkfs.ntfs /dev/sdb1`
- for `FAT32` : `sudo mkfs.vfat /dev/sdb1` \
  NB! : Don't use `FAT32`. It is not suitable for files > 4 GB

### Mounting disk
```
# create a folder to mount disk
sudo mkdir /mnt/storage
# adjust the permissions and ownership
sudo chown nobody: -R /mnt/storage
sudo mount /dev/sdb1 /mnt/storage
# if mounts successfully, unmount it
sudo umount /dev/sdb1
```

Now, configure automatic mounting by editing `/etc/fstab` and adding to it:
```
/dev/sdb1 /mnt/storage  ext4  exec,nofail  0 0
```
Keys:
- `exec` : to allow running executables from it
- `nofail` : keep booting system if mounting fails

NB!: if you need `NTFS` file system, specify `ntfs` instead of `ext4`. Some  other operating system ask to specify `NTFS` as `ntfs-3g`

Check the mounting by running:
```
sudo mount -a
```

If no problem occured, the system will automatically mount folder at start-up.

## 05. SLURM and MUNGE

```
# Currently, installs SLURM 21.08.3.1-1 + MUNGE 0.5.14-2
yay -S slurm-llnl munge
# Generate the encrytption keys for `munge`
sudo rm -f /etc/munge/munge.key
sudo /usr/sbin/mungekey
sudo chown munge /etc/munge/munge.key
# check if munge working
munge -n | unmunge
# if everythign is OK, add to auto-start
sudo systemctl enable --now munge
# get and keep the properties of running machine
slurmd -C
```

Output should be alike:
```
NodeName=target CPUs=8 Boards=1 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=2 RealMemory=15933
UpTime=0-00:42:42
```

Discard part with `UpTime...` and reduce the `RealMemory` parameter by at least 0.5 GB (approximately), prepare that part as:

```
NodeName=target CPUs=8 Boards=1 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=2 RealMemory=15000
```

Copy existing example config file:
```
sudo cp /etc/slurm-llnl/slurm.conf.example /etc/slurm-llnl/slurm.conf
```

Edit `/etc/slurm-llnl/slurm.conf` file for following parameters:
- `SlurmctldHost` should be the name of machine
- `ProctrackType` should be `proctrack/linuxproc`
- `ReturnToService` should be `2`

And add in the end:
```
NodeName=target CPUs=8 Boards=1 SocketsPerBoard=1 CoresPerSocket=4 ThreadsPerCore=2 RealMemory=15000 State=UNKNOWN
PartitionName=superbrain Nodes=target Default=YES MaxTime=INFINITE State=UP Shared=EXCLUSIVE
```

Now, fixing the folders and permissions:
```
# Creating and owning folders from SlurmdSpoolDir and StateSaveLocation
sudo mkdir -p /var/spool/slurmd /var/spool/slurmctld
sudo chown slurm: /var/spool/slurmd /var/spool/slurmctld

# Creating and owning files from SlurmctldPidFile and SlurmdPidFile
sudo touch /var/run/slurmctld.pid /var/run/slurmd.pid
sudo chown slurm: /var/run/slurmctld.pid /var/run/slurmd.pid

# Owning the  config file itself
sudo chown slurm: /etc/slurm-llnl/slurm.conf
```

Test if it works:
```
sudo systemctl start slurmd slurmctld
srun -n$(nproc) echo "Hello!"
# if everything is fine:
sudo systemctl enable --now slurmd slurmctld
```
## -01. Secondary stuff, if `target` is used multipurpose

Bluetooth support ([instructions](https://discovery.endeavouros.com/bluetooth/bluetooth/2021/03/)):
```
sudo pacman -S --needed bluez bluez-utils pulseaudio-bluetooth
sudo systemctl enable --now bluetooth
```

nVidia drivers: read [instruction](https://discovery.endeavouros.com/nvidia/nvidia-installer/2021/03/)
```
# install the installer
sudo pacman -S nvidia-installer-dkms
# run compatibility check
nvidia-installer-check
# if it returns something alike "Your graphics card ... is supported by the nvidia-dkms driver" install the driver
sudo nvidia-installer-dkms
# mandatory reboot after installation
sudo reboot
```

Media playback:
```
sudo pacman -Syu libdvdcss opus opus-tools libdvdread libaacs libbluray v4l2loopback-dkms
sudo pacman -Syu ffmpeg youtube-dl

# Replace the default Totem player with VLC
sudo pacman -R totem
sudo pacman -Syu vlc

yay -S aacskeys libxc libbdplus
mkdir ~/.config/aacs/
cd ~/.config/aacs/ && wget http://vlc-bluray.whoknowsmy.name/files/KEYDB.cfg

sudo wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp

# alternatively, if pacman -S youtube-dl didn't work:
sudo wget https://yt-dl.org/downloads/latest/youtube-dl -O /usr/local/bin/youtube-dl
sudo chmod a+rx /usr/local/bin/youtube-dl
```

Kicad:
```
# stable kicad
sudo pacman -S kicad kicad-library kicad-library-3d
# some additional tools
sudo pacman -S pcbdraw python-kikit
# development version
yay -S kicad-git kicad-library-nightly
```

Steam:
```
sudo pacman -S steam
```

Microcontrollers programming:
```
# General purpose pre-requisites
sudo pacman -S dfu-util libusb

# ATMEL microcontrollers
sudo pacman -S avrdude avr-{gcc,binutils,libc}
yay -S avra

# STMicroelectronics
sudo pacman -S stlink openocd gdb
# STM32CubeIDE
yay -S stm32cubeide stm32cubemx sw4stm32

# Some bare metal compilers
sudo pacman -S arm-none-eabi-gcc arm-none-eabi-gdb arm-none-eabi-binutils arm-none-eabi-newlib


# For Arduino IDE
sudo pacman -S arduino arduino-docs hid-flash
# For STM32F10x with Arduino bootloader
yay -S hid-flash

```


## configuring of youtube-dl

Edit or create file `/etc/youtube-dl.conf` or `/etc/yt-dlp.conf`:

```
# always merge to mkv
--merge-output-format mkv

# Number of retries for a fragment
--fragment-retries 500
--retries 500

# Abort download of video if there is unavailable fragment
--abort-on-unavailable-fragment

# ignore errors
--ignore-errors

# downloaded formats
--format bestvideo+bestaudio
```

## Setting-up samba for windows access

```
sudo wget -O /etc/samba/smb.conf https://git.samba.org/samba.git/?p=samba.git;a=blob_plain;f=examples/smb.conf.default;hb=HEAD
sudo chown -R root:root /etc/samba/smb.conf
```

edit the /etc/samba/smb.conf for public folder:
```
# A publicly accessible directory, read/write to all users. Note that all files
# created in the directory by users will be owned by the default user, so
# any user with access can delete any other user's files. Obviously this
# directory must be writable by the default user. Another user could of course
# be specified, in which case all files would be owned by that user instead.
[public]
   comment = Station Storage
   path = /mnt/storage
   public = yes
   only guest = yes
   writable = yes
   browseable = yes
   printable = no
```


## If drained for unknown reason

```
sudo scontrol update nodename=target state=DOWN Reason="undraining"
sudo scontrol update nodename=target state=UNDRAIN
```


## If needed chromium instead of firefox
```
sudo pacman -Syu chromium
yay -S chromium-widevine
sudo pacman -R firefox
```

## If needed GUI python development
```
pip install pyqt6
pip install pyqt-tools
```
