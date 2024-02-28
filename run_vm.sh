#!/usr/bin/env bash

cd `dirname $0`
source params

if [ ! -f linux/uImage ]; then
  echo "Cannot find kernel, run ./get_linux.sh first!"
  exit 1
fi

qemu-system-arm \
  -machine xilinx-zynq-a9 -cpu cortex-a9 -m $RAM_SIZE \
  -kernel linux/uImage -dtb linux/devicetree.dtb \
  -display none -serial null -serial mon:stdio \
  -append "clocksource=hpet init=/sbin/init console=ttyPS0,115200 earlyprintk root=/dev/mmcblk0 rw" \
  -net user,hostfwd=tcp::${LOCAL_SSH_PORT}-:22,hostfwd=tcp::1741-:1741,hostfwd=tcp::1742-:1742,hostfwd=udp::1164-:1164,hostfwd=udp::1166-:1166\
  -net nic \
  -rtc base=localtime,clock=vm\
  -sd "$IMG_FILE"

# TODO: how to safely shutdown the system?
