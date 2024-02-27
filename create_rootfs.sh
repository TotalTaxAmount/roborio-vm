#!/usr/bin/env bash

NBD_DEVICE=/dev/nbd0
USER=$(logname)

cd `dirname $0`
source params

if [ -f "$IMG_FILE" ]; then
  echo "$IMG_FILE already exists! Deleating"
  rm "$IMG_FILE"
fi

if [ "$1" == "" ]; then
  echo "Usage: $0 /path/to/FRC_roboRIO_*.zip"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
        echo 'This script must be run by root' >&2
        exit 1
fi

ROBORIO_ZIP="$1"

QEMU_NBD=`which qemu-nbd`

function abspath {
  return "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
}

function rm_mount {
  if [ -d mnt ]; then
    umount mnt || true
    rmdir mnt
  fi
  echo "Remove mount"
}

function rm_unpacked {
  [ ! -d unpacked ] || rm -rf unpacked
  echo "Remove unpacked"
}

function cleanup {
  echo "Cleaning up..."
  rm_unpacked
  rm_mount
  
  if [ ! -z "$NBD_DEVICE" ]; then
    "$QEMU_NBD" -d $NBD_DEVICE
  fi
}

trap cleanup EXIT

rm_unpacked
rm_mount

# Unpack the roborio image zipfile, ensure we're sane
mkdir unpacked

unzip "$ROBORIO_ZIP" -d unpacked
# there are two files in there, one is a zip file, unzip the zip file
mkdir unpacked/more
unzip unpacked/${ROBORIO_ZIP%.*}/*.zip -d unpacked/more

# Make sure the file we're looking for is there
if [ ! -f unpacked/more/systemimage.tar.gz ]; then
  echo "Error: Expected to find systemimage.tar.gz, did not find it!"
  exit 1
fi

# Create the qemu image
qemu-img create -f qcow2 "$IMG_FILE" $HDD_SIZE

# Mount it, format it (requires root access!)
modprobe nbd

"$QEMU_NBD" -d /dev/nbd0
"$QEMU_NBD" -c $NBD_DEVICE "$IMG_FILE"

echo "Formatting image, this may take a few minutes..."
# TODO: probably should use a different filesystem
mkfs.ext3 $NBD_DEVICE 

mkdir mnt
mount -t ext3 $NBD_DEVICE mnt

# Untar the file onto the image..
echo "Unpacking FRC image..."
tar -xf unpacked/more/systemimage.tar.gz --directory mnt

# Modify the startup configuration to enable SSHD
STARTUP_INI_FILE=mnt/etc/natinst/share/ni-rt.ini
python _modify_ini.py ${STARTUP_INI_FILE} systemsettings host_name roboRIO-SimVM
python _modify_ini.py ${STARTUP_INI_FILE} systemsettings sshd.enabled True
python _modify_ini.py ${STARTUP_INI_FILE} systemsettings ConsoleOut.enabled True

# Fix lots of erros!!
echo "Fixing erros..."
# Erros to fix:
# TODO: Fix hwclock (mabye DTB or)
### Error: "serial#" not defined
## Error: "serial#" not defined
# grep: /boot/.safe/bootimage.ini: No such file or directory
# ERROR: Unknown ProductID: 0x793C
# StatusIndicator FPGA Error: -52010
# libnipalu.so failed to initialize
# Verify that nipalk.ko is built and loaded.
# FRC_NetworkCommunication version: 23.0.0f125



find patches -type f | while read -r file; do
    # Get the relative path of the file relative to the patches directory
    relative_path="${file#patches/}"
    
    # Determine the destination path
    destination="mnt/$relative_path"
    
    # Create directories if they don't exist
    mkdir -p "$(dirname "$destination")"
    
    # Copy the file to its destination
    cp -f "$file" "$destination"
    echo "Copied $file to $destination"
done

# Unmount it
rm_mount

# Create a snapshot in case someone wants to revert their VM without rebuilding it
# qemu-img snapshot -c initial "$IMG_FILE"

echo "Successfully created $IMG_FILE!"
echo "Changing permissions, $IMG_FILE owned by $USER"
chown "$USER" "$IMG_FILE"
