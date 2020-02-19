#!/system/bin/sh

# -------------------------------
#     parasite.sh  by nooriro
# -------------------------------
# * Based on Airpil's custom Magisk for enabling diag mode on Pixel 2 XL [1][2]
# * Improved using Magisk 19.4+'s 'Root Directory Overlay System' [3]
# [1] https://forum.xda-developers.com/pixel-2-xl/how-to/guide-qxdm-port-activation-pixel-2-xl-t3884967
# [2] https://github.com/AGagarin/Magisk/blob/master/native/jni/core/magiskrc.h
# [3] https://github.com/topjohnwu/Magisk/blob/master/docs/guides.md#root-directory-overlay-system
# 
# Thanks: Airpil, daedae, gheron772, 파이어파이어, 픽셀2VOLTE, and topjohnwu
# ------------------------------------------------------------------------------
# Usage: (1) Make sure 'magisk_patched.img' exists in   /sdcard/Download
#        (2) Download latest (or 19.4+) Magisk zip into /sdcard/Download
#        (3) Place this script in /data/local/tmp and set execution permission
#        (4) Run this script
# ------------------------------------------------------------------------------


# ---------- start of diag.rc contents ----------
DIAG_RC_CONTENTS='on init
    chmod 666 /dev/diag

on post-fs-data
    # Modem logging collection
    mkdir /data/vendor/radio 0777 radio radio
    mkdir /data/vendor/radio/diag_logs 0777 system system
    # WLAN logging collection
    mkdir /data/vendor/wifi 0777 system system
    mkdir /data/vendor/wifi/cnss_diag 0777 system system

on property:sys.usb.config=diag,serial_cdev,rmnet_gsi,adb && property:sys.usb.configfs=1
    start adbd
    start port-bridge

on property:sys.usb.ffs.ready=1 && property:sys.usb.config=diag,serial_cdev,rmnet_gsi,adb && property:sys.usb.configfs=1
    write /config/usb_gadget/g1/configs/b.1/strings/0x409/configuration diag_serial_cdev_rmnet_gsi_adb
    rm /config/usb_gadget/g1/configs/b.1/function0
    rm /config/usb_gadget/g1/configs/b.1/function1
    rm /config/usb_gadget/g1/configs/b.1/function2
    rm /config/usb_gadget/g1/configs/b.1/function3
    rm /config/usb_gadget/g1/configs/b.1/function4
    rm /config/usb_gadget/g1/configs/b.1/function5
    rm /config/usb_gadget/g1/configs/b.1/f0
    rm /config/usb_gadget/g1/configs/b.1/f1
    rm /config/usb_gadget/g1/configs/b.1/f2
    rm /config/usb_gadget/g1/configs/b.1/f3
    rm /config/usb_gadget/g1/configs/b.1/f4
    rm /config/usb_gadget/g1/configs/b.1/f5
    write /config/usb_gadget/g1/idVendor 0x05C6
    write /config/usb_gadget/g1/idProduct 0x9091
    write /config/usb_gadget/g1/os_desc/use 1
    symlink /config/usb_gadget/g1/functions/diag.diag /config/usb_gadget/g1/configs/b.1/function0
    symlink /config/usb_gadget/g1/functions/cser.dun.0 /config/usb_gadget/g1/configs/b.1/function1
    symlink /config/usb_gadget/g1/functions/gsi.rmnet /config/usb_gadget/g1/configs/b.1/function2
    symlink /config/usb_gadget/g1/functions/ffs.adb /config/usb_gadget/g1/configs/b.1/function3
    write /config/usb_gadget/g1/UDC ${sys.usb.controller}
    setprop sys.usb.state ${sys.usb.config}
'
# ---------- end of diag.rc contents ----------

MAGISKPATCHEDIMG=`ls -1 /sdcard/Download/magisk_patched.img`
if [ -z "$MAGISKPATCHEDIMG" ]; then
  echo "! magisk_patched.img does not exist in /sdcard/Download" 1>&2
  exit 1
else
  echo "* Magisk patched boot image: [${MAGISKPATCHEDIMG}]" 1>&2
fi

MAGISKZIP=`ls -1 /sdcard/Download/Magisk-v[1-9][0-9].[0-9].zip | tail -n 1`
if [ -z "$MAGISKZIP" ]; then
  echo "! Magisk zip does not exist in /sdcard/Download" 1>&2
  exit 2
else
  echo "* Magisk zip:                [${MAGISKZIP}]" 1>&2
  echo "* Magisk zip version:        [${MAGISKZIP:25:4}]" 1>&2
  MAGISKZIPVER="${MAGISKZIP:25:2}${MAGISKZIP:28:1}"
  if [ "$MAGISKZIPVER" -lt 194 ]; then
    echo "! Magisk zip version is less than 19.4" 1>&2
    exit 3
  fi
fi

DIR=`mktemp -d`
cd "$DIR"
echo "- Extracting Magisk zip                           (unzip)" 1>&2
unzip "$MAGISKZIP" >/dev/null
echo "- Dropping diag.rc contained within this script   (printf & redirection)" 1>&2
printf "%s" "$DIAG_RC_CONTENTS" > diag.rc


if [ ! -f "arm/magiskboot" ]; then
  echo "! magiskboot does not exist in Magisk zip" 1>&2
  cd ..
  rm -rf "$DIR"
  exit 4
fi

echo "- Unpacking magisk_patched.img                    (magiskboot unpack)" 1>&2
./arm/magiskboot unpack /sdcard/Download/magisk_patched.img 2>/dev/null

echo "- Inserting diag.rc into ramdisk.cpio             (magiskboot cpio)" 1>&2
./arm/magiskboot cpio ramdisk.cpio \
  "mkdir 755 overlay.d" \
  "add 644 overlay.d/diag.rc diag.rc" 2>/dev/null

echo "- Repacking boot image                            (magiskboot repack)" 1>&2
./arm/magiskboot repack /sdcard/Download/magisk_patched.img 2>/dev/null

echo "- Copying new boot image into /sdcard/Download    (cp)" 1>&2
cp new-boot.img /sdcard/Download/magisk_patched_diag.img 2>/dev/null

echo "* New patched boot image:    [/sdcard/Download/magisk_patched_diag.img]" 1>&2
SHA1_ORIG=`./arm/magiskboot cpio ramdisk.cpio sha1 2>/dev/null`
echo "* Stock boot image SHA1:     [${SHA1_ORIG}]" 1>&2

# echo 1>&2
sha1sum /sdcard/Download/boot.img /sdcard/Download/magisk_patched.img 1>&2
sha1sum /sdcard/Download/magisk_patched_diag.img

cd ..
rm -rf "$DIR"
rm "$0"
exit 0
