#!/usr/bin/env sh
VERSION=0.3
HOSTNAME=almalinux
HOSTNAME_DEST=10.0.0.5

if [ $(id -u) -ne 0 ]
   then echo Please run this script as root or using sudo!
   exit
fi

function mountpoints() {
mkdir -p /mnt/system && mount -t xfs /dev/$HOSTNAME/root /mnt/system
#mount -t xfs /dev/backup/usr /mnt/system/usr
mount -t xfs /dev/mapper/almalinux-usr /mnt/system/usr
#mkdir /mnt/shadow && mount -t xfs /dev/backup/sys /mnt/shadow
mkdir -p /mnt/remote; mount -t nfs -o nolock $HOSTNAME_DEST:/volume1/Alex/Backup/$HOSTNAME/almalinux-system /mnt/remote
}

function list() {
mountpoints
ls -lh /mnt/remote/
}

function backup() {
 echo "preparing backup..."
mountpoints

SRC=/mnt/system/
DEST=/mnt/remote
NAME=system-backup
BACKUPS=11
mount -o remount,ro $SRC

# mount filessystems
if [ $? != 0 ]; then exit; fi
echo "mountpoints created"
 
# Exit if no source directory exists
if [ ! -d $SRC ]; then
  exit
fi
 
# Create backup directory if neccessary
if [ ! -d $DEST ]; then
  mkdir $DEST
fi
 
# Delete oldest backup directory
if [ -d $DEST/$NAME.$(($BACKUPS-1)) ];  then
   printf "delete oldest backup directory: $DEST/$NAME.$(($BACKUPS-1))"
   rm -rf $DEST/$NAME.$(($BACKUPS-1))
fi
 
echo "rotating backups..."
# Rotate backups
i=$(($BACKUPS-2))
while [ "$i" -ge "0" ]; do
   j=$(($i+1))
   if [ -d $DEST/$NAME.$i ]; then
       mv $DEST/$NAME.$i $DEST/$NAME.$j
   fi
   i=$(($i-1))
done
echo "rotating backups finished"
 
# Make next backup
 echo "link-dest: $DEST/$NAME.1"
 echo "src: $SRC"
 echo "dest: $DEST/$NAME.0/"
 read -p "Press Enter to run the backup..."
 echo "backing up system '$HOSTNAME' to remote '$HOSTNAME_DEST'..."
 rsync -axHAXv --delete --exclude={'/home/alex/containers', '/tmp'} --link-dest=$DEST/$NAME.1 $SRC $DEST/$NAME.0/
}

function help() {
   echo "commands: backup restore list clean help"
}

function restore() {
   echo "experimental"
   mountpoints
   mount -o remount,ro /mnt/remote
   echo "select a backup"
   list
   read -p "please select a backup to restore " backup_number
   if [[ -z "$backup_number" ]]; then backup_number=0; fi
   SRC=/mnt/remote/system-backup.$backup_number
   DEST=/mnt/system
   printf "src: $SRC\ndest: $DEST\n"
   read -p "Press Enter to run the restore..."

   mkdir -p "$DEST/dev"; mkdir -p "$DEST/proc"; mkdir -p "$DEST/sys"; mkdir -p "$DEST/tmp"; mkdir -p "$DEST/run"; mkdir -p "$DEST/mnt"; mkdir -p "$DEST/media"
   rsync -avHAX --delete --exclude={"/home/*", "/dev/*", "/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} "$SRC" "$DEST"
}

function clean() {
umount /mnt/system/usr &&
umount /mnt/system && rmdir /mnt/system
umount /mnt/remote && rmdir /mnt/remote
}

if [[ $1 == "clean" ]]; then clean; exit; fi
if [[ $1 == "list" ]]; then list; clean; exit; fi
if [[ $1 == "backup" ]]; then backup; clean; exit; fi
if [[ $1 == "restore" ]]; then restore; clean; exit; fi
if [[ $1 == "mountpoints" ]]; then mountpoints; exit; fi
if [[ $1 == "help" ]]; then help; exit; fi

backup
clean
