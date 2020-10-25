#!/bin/bash
# don't forget to install csh package prior to running this scrip
# To add current user to group of g16 users, run as:
# sudo setup.sh $USER
# For just installation run as:
# sudo setup.sh

# Copy this script to folder containing installer and left it field empty, otherwise:
# specify exact location of instalation folder (the one contains "tar" folder)
installer_location=""

# Installer itself creates g16 folder inside of folder specified below
installation_destination='/'

# Folder to contain all scratch
scratch_folder='/scratch'

# groupname for gaussian users
usergroup_name='gaussian'

# -------------------------------------------------------------------
# Don't edit anything below this point
# -------------------------------------------------------------------
# Some group politics and ownership
groupadd $usergroup_name
usermod -aG $usergroup_name root
if [ ! -z $1 ]; then
	usermod -aG $usergroup_name $1
fi
getent group $usergroup_name

# If location is not specified, assume it is copied to a installer folder
if [ -z $installer_location ]; then
	installer_location="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )";
fi

echo "Setting the environment variables"
export mntpnt="$installer_location"
echo -e "\tmntpnt = $mntpnt"
export g16root="$installation_destination"
echo -e "\tg16root = $g16root"

installed_folder="$g16root/g16"

echo Installer is located in $installer_location
echo Installation will be done to $installed_folder

if [ ! -d $installation_destination ]; then
	mkdir -p $installation_destination
fi

if [ -d $installed_folder ]; then
	echo -e "Found old intallation at $installed_folder"
	echo -e "\tPurging..."
	rm -rf $installed_folder
	echo -e "\tDone!"
fi

echo Scratch folder will be located at $scratch_folder
if [ ! -d $scratch_folder ]; then
	mkdir -p $scratch_folder
fi

cd $g16root

echo "Searching for installer"
if [ -e $installer_location/tar/*.tbJ ]; then
	echo -e "\ttbJ arhive found";
	tar xvfJ $installer_location/tar/*.tbj;
	echo -e "\t\tUnpacked";

elif [ -e $installer_location/tar/*.tbz ]; then
	echo -e "\ttbJ arhive found";
	bzip2 -d -c $installer_location/tar/*.tbz | tar xvf -
	echo -e "\t\tUnpacked";
else
	echo -e "\tNo installer found. Exiting..."
	exit
fi

echo "Changing the ownership and permissions"
chown -R :$usergroup_name $installed_folder
chown -R :$usergroup_name $scratch_folder

chmod -R 754 $installed_folder
chmod -R 774 $scratch_folder

echo "Finishing installation"
cd $installed_folder
bsd/install

echo "Adding required options to bashrc"
# location depends on OS
# /etc/bash.bashrc			: Debian / Ubuntu / Kali / Linux Mint / BackTrack / Elementary OS
#							: Arch Linux / AntergOS / Manjaro
# /etc/bashrc				: CentOS / Fedora / Red Hat Enterprise Linux
# /etc/bash.bashrc.local	: Suse, OpenSuse
# Thats why search for file:

outfile=$(find /etc/*bashrc*)

echo "Found $outfile"
echo "" >> $outfile
echo "g16root=$g16root" >> $outfile
echo "GAUSS_SCRDIR=$scratch_folder" >>  $outfile
echo "export g16root GAUSS_SCRDIR" >>  $outfile
echo '. $g16root/g16/bsd/g16.profile' >>  $outfile
