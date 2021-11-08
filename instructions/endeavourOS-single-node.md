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
```

Now, the target should be available just by running `ssh target_host_name` from the `host`.

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
pacman -S base-devel haskell-zlib zlib gzip bzip2 unzip git cmake dos2unix
# disk utilities
pacman -S ntfs-3g hdf5
# GCC, Fortran compilers
pacman -S gcc gcc-libs gcc-d gcc-fortran
# Java JDK
pacman -S jdk-openjdk
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

# R-studio
yay -S rstudio-desktop

# MPICH
yay -S mpich
pacman -S python-mpi4py python-h5py python-matplotlib python-tensorflow

# RUST
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

## 04. Mounting additional disks

Here, I assume having the second HDD in the PC. Endeavour OS by default wouldn't mount it not make accessible.


```
sudo mkdit /mnt/storage
sudo chown nobody: -R /mnt/storage
sudo mount /dev/sdb1 /mnt/storage
```

edit `/etc/fstab` and add:
```
/dev/sdb1 /mnt/storage  ext4  exec,nofail  0 0
```

Keys:
- `exec` : to allow running executables from it
- `nofail` : keep booting system if mounting fails


## 05. SLURM and MUNGE

```
# Currently, installs SLURM 21.08.3.1-1 + MUNGE 0.5.14-2
yay -S slurm-llnl munge
# get and keep the properties of running machine
slurmd -C
```




## Secondary stuff, if `target` is used multipurpose

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
sudo pacman -Syu vlc

yay -S aacskeys
```

Kicad:
```
# stable kicad
sudo pacman -S kicad
# development version
yay -S kicad-git
```
