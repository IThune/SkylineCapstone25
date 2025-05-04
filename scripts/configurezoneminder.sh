#!/bin/sh

# Script Params
# $1 - Zoneminder Database Username.
# $2 - Zoneminder Database Password. TODO find and clean stdout/stderr/other logs that would show this pass in the clear

# Step 1 - Create a filesystem on and mount the 64GB footage disk
DISK_SYMLINK="/dev/disk/azure/scsi1/lun0"   # specify the data disk as defined in azure which should be lun0
DISK_UDEV="$(readlink -f $DISK_SYMLINK)"    # get the /dev/sd* of the datadisk
MOUNT_POINT="/mnt/footage"  # partition mount point

# install necessary utilities
apt update && apt upgrade -y && apt install parted -y

# Create a partition if not already present
if ! lsblk "$DISK_SYMLINK" | grep -q part; then
  parted "$DISK_SYMLINK" --script mklabel gpt mkpart primary ext4 0% 100%
  mkfs.ext4 "${DISK_UDEV}1"
fi

# Create mount point and mount the disk
mkdir -p "$MOUNT_POINT"
mount "${DISK_UDEV}1" "$MOUNT_POINT"

# Persist in /etc/fstab
UUID=$(blkid -s UUID -o value "${DISK_UDEV}1")
echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab

# Step 2 - Install Zoneminder package and dependencies
apt install apache2 mariadb-server zoneminder -y

# Step 3 - Create the zoneminder database and database user
mariadb <<EOF
CREATE DATABASE zm;
CREATE USER $1@localhost IDENTIFIED BY '$2';
GRANT ALL ON zm.* TO $1@localhost;
FLUSH PRIVILEGES;
EOF

# Step 4 - Configure the ZM database
mariadb -u $1 -p"$2" zm < /usr/share/zoneminder/db/zm_create.sql

# Step 5 - Set permissions for zm.conf
chgrp -c www-data /etc/zm/zm.conf # allows apache access to the conf
chmod 0640 /etc/zm/zm.conf  # rw access for root, ro access for www-data group, none for world

# Step 6 - Create custom zm config file
echo "ZM_DB_PASS=$2" >> /etc/zm/conf.d/skyline.conf
chgrp -c www-data /etc/zm/conf.d/skyline.conf   # allows apache access to the conf
chmod 0640 /etc/zm/zm.conf  # rw access for root, ro access for www-data group, none for world

# Step 7 - Set the Apache configuration
a2enconf zoneminder # enable Zoneminder apache2 config
a2enmod cgi # enable cgi module
# reload, start and enable services
systemctl reload apache2.service
systemctl restart zoneminder.service
systemctl status enable zoneminder.service