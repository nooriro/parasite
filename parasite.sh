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
# Usage: (1) Make sure 'magisk_patched.img' or 'magisk_patched_XXXXX.img' file
#            exists in /sdcard/Download directory
#        (2) Make sure Magisk app (version code 21402+) is installed (recommended)
#            or download Magisk zip (version 19.4+) into /sdcard/Download
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

# $1=APKPATH
function extract_magiskboot_fromapk() {
  unzip "$1" lib/armeabi-v7a/libmagiskboot.so > /dev/null
  if [ -f lib/armeabi-v7a/libmagiskboot.so ]; then
    mv lib/armeabi-v7a/libmagiskboot.so magiskboot
    rm -rf lib
    return 0
  else
    return 1
  fi
}

# $1=ZIPPATH
function extract_magiskboot_fromzip() {
  unzip "$1" arm/magiskboot > /dev/null
  if [ -f arm/magiskboot ]; then
    mv arm/magiskboot .
    rm -rf arm
    return 0
  else
    return 1
  fi
}

function prepare_magiskboot() {
  local DIR

  # Detect Magisk app 21402+
  local APP=$( pm path com.topjohnwu.magisk )
  APP=${APP:8}    # Strip "Package:" prefix
  if [ -n "$APP" ]; then
    local APP_VER=$( dumpsys package com.topjohnwu.magisk | grep versionCode | awk '{print $1}' | awk -F"=" '{print $2}' )
    if [ "$APP_VER" -ge 21402 ]; then
      echo "* Magisk app version code:   [${APP_VER}] >= 21402" 1>&2
      DIR=$( mktemp -d )    # $DIR has the absolte path
      cd "$DIR"
      echo "- Extracting magiskboot from Magisk app           (unzip)" 1>&2
      if extract_magiskboot_fromapk "$APP"; then
        return 0
      else
        echo "! 'lib/armeabi-v7a/libmagiskboot.so' does not exist in Magisk app" 1>&2
      fi
    else
      echo "! Magisk app version code:   [${APP_VER}] < 21402" 1>&2
    fi
  else
    echo "! Magisk app is not installed" 1>&2
  fi

  echo "! Fallback to Magisk zip (version code 19400+) in /sdcard/Download" 1>&2
  
  # $ZIP_TYPE0     = canary,          no version in filename
  # $ZIP_TYPE1     = canary,         has version in filename
  # $ZIP_TYPE[2-4] = stable or beta, has version in filename
  #
  # If at least one of $ZIP_TYPE[1-4] exists, the latest version of $ZIP_TYPE[1-4] is used.
  # Otherwise $ZIP_TYPE0 is used, if it exists.
  
  local ZIP_TYPE0=$( ls -1 /sdcard/Download/magisk-debug.zip 2>/dev/null )
  local ZIP_TYPE1=$( ls -1 /sdcard/Download/Magisk-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\(194[0-9][0-9]\).zip  \
      /sdcard/Download/Magisk-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\(20[0-4][0-9][0-9]\).zip  \
      /sdcard/Download/Magisk-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\(21[0-3][0-9][0-9]\).zip  \
      /sdcard/Download/Magisk-f5593e05\(21401\).zip  \
      2>/dev/null | sort -k 2 -t \( | tail -n 1  )
  local ZIP_TYPE2=$( ls -1 /sdcard/Download/Magisk-v19.4.zip \
      /sdcard/Download/Magisk-v2[0-1].[0-4].zip  \
      2>/dev/null | tail -n 1  )
  local ZIP_TYPE3=$( ls -1 /sdcard/Download/Magisk-v19.4\(19400\).zip \
      /sdcard/Download/Magisk-v20.0\(20000\).zip  /sdcard/Download/Magisk-v20.1\(20100\).zip \
      /sdcard/Download/Magisk-v20.2\(20200\).zip  /sdcard/Download/Magisk-v20.3\(20300\).zip \
      /sdcard/Download/Magisk-v20.4\(20400\).zip  /sdcard/Download/Magisk-v21.0\(21000\).zip \
      /sdcard/Download/Magisk-v21.1\(21100\).zip  /sdcard/Download/Magisk-v21.2\(21200\).zip \
      /sdcard/Download/Magisk-v21.3\(21300\).zip  /sdcard/Download/Magisk-v21.4\(21400\).zip \
      2>/dev/null | tail -n 1  )
  local ZIP_TYPE4=$( ls -1 /sdcard/Download/Magisk-19.4\(19400\).zip \
      /sdcard/Download/Magisk-20.0\(20000\).zip  /sdcard/Download/Magisk-20.1\(20100\).zip \
      /sdcard/Download/Magisk-20.2\(20200\).zip  /sdcard/Download/Magisk-20.3\(20300\).zip \
      /sdcard/Download/Magisk-20.4\(20400\).zip  /sdcard/Download/Magisk-21.0\(21000\).zip \
      /sdcard/Download/Magisk-21.1\(21100\).zip  /sdcard/Download/Magisk-21.2\(21200\).zip \
      /sdcard/Download/Magisk-21.3\(21300\).zip  /sdcard/Download/Magisk-21.4\(21400\).zip \
      2>/dev/null | tail -n 1  )
  local ZIP_TYPE1_VER="-1"; [ -n "$ZIP_TYPE1" ] && ZIP_TYPE1_VER="${ZIP_TYPE1:33:5}"
  local ZIP_TYPE2_VER="-1"; [ -n "$ZIP_TYPE2" ] && ZIP_TYPE2_VER="${ZIP_TYPE2:25:2}${ZIP_TYPE2:28:1}00"
  local ZIP_TYPE3_VER="-1"; [ -n "$ZIP_TYPE3" ] && ZIP_TYPE3_VER="${ZIP_TYPE3:30:5}"
  local ZIP_TYPE4_VER="-1"; [ -n "$ZIP_TYPE4" ] && ZIP_TYPE4_VER="${ZIP_TYPE4:29:5}"
  # echo "$ZIP_TYPE1_VER  $ZIP_TYPE2_VER  $ZIP_TYPE3_VER  $ZIP_TYPE4_VER"
  
  local ZIP 
  # If all of the $ZIP_TYPE[1-4] are empty (= that is, if there's no versioned Magisk zip file),
  #    ---> Use $ZIP_TYPE0 or return error code
  # Otherwise,
  #    ---> Use the latest version of $ZIP_TYPE[1-4]
  if [ -z "$ZIP_TYPE1" -a -z "$ZIP_TYPE2" -a -z "$ZIP_TYPE3" -a -z "$ZIP_TYPE4" ]; then
    if [ -z "$ZIP_TYPE0" ]; then
      echo "! Magisk zip (version 19.4+) is not found in /sdcard/Download" 1>&2
      if [ -n "$DIR" ]; then
        cd ..
        rm -rf "$DIR"
      fi
      return 2
    else
      ZIP=$ZIP_TYPE0
    fi 
  elif [ "$ZIP_TYPE1_VER" -ge "$ZIP_TYPE2_VER" -a "$ZIP_TYPE1_VER" -ge "$ZIP_TYPE3_VER" -a "$ZIP_TYPE1_VER" -ge "$ZIP_TYPE4_VER" ]; then
    ZIP=$ZIP_TYPE1
  elif [ "$ZIP_TYPE2_VER" -ge "$ZIP_TYPE3_VER" -a "$ZIP_TYPE2_VER" -ge "$ZIP_TYPE4_VER" ]; then
    ZIP=$ZIP_TYPE2
  elif [ "$ZIP_TYPE3_VER" -ge "$ZIP_TYPE4_VER" ]; then
    ZIP=$ZIP_TYPE3
  else 
    ZIP=$ZIP_TYPE4
  fi 

  echo "* Magisk zip:                [${ZIP}]" 1>&2
  if [ -z "$DIR" ]; then
    DIR=$( mktemp -d )    # $DIR has the absolte path
    cd "$DIR"
  fi
  echo "- Extracting magiskboot from Magisk zip           (unzip)" 1>&2
  if extract_magiskboot_fromzip "$ZIP"; then
    return 0
  else
    echo "! 'arm/magiskboot' does not exist in Magisk zip" 1>&2
    cd ..
    rm -rf "$DIR"
    return 4
  fi
}

function prepare_magiskpatchedimg() {
  local MAGISKPATCHEDIMG="/sdcard/Download/magisk_patched.img"
  local IMG=$( ls -1t $MAGISKPATCHEDIMG \
      /sdcard/Download/magisk_patched_[0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z].img \
      2>/dev/null | head -n 1 )
  if [ -z "$IMG" ]; then
    echo "! Magisk patched boot image is not found in /sdcard/Download" 1>&2
    return 1
  else
    echo "* Magisk patched boot image: [${IMG}]" 1>&2
    if [ "${#IMG}" -eq 41 ]; then    # /sdcard/Download/magisk_patched_XXXXX.img
      [ -f "$MAGISKPATCHEDIMG" ] && rm $MAGISKPATCHEDIMG
      mv "$IMG" "$MAGISKPATCHEDIMG"
      echo "              -- renamed --> [${MAGISKPATCHEDIMG}]" 1>&2
    fi
  fi
  return 0
}

INPUT="/sdcard/Download/magisk_patched.img"
OUTPUT="/sdcard/Download/magisk_patched_diag.img"

prepare_magiskpatchedimg || exit $?
prepare_magiskboot || exit $?

echo "- Dropping diag.rc contained in this script       (printf & redirection)" 1>&2
printf "%s" "$DIAG_RC_CONTENTS" > diag.rc

echo "- Unpacking magisk_patched.img                    (magiskboot unpack)" 1>&2
./magiskboot unpack $INPUT 2>/dev/null

echo "- Inserting diag.rc into ramdisk.cpio             (magiskboot cpio)" 1>&2
./magiskboot cpio ramdisk.cpio \
  "mkdir 750 overlay.d" \
  "add 644 overlay.d/diag.rc diag.rc" 2>/dev/null

echo "- Repacking boot image                            (magiskboot repack)" 1>&2
./magiskboot repack $INPUT 2>/dev/null

echo "- Copying new boot image into /sdcard/Download    (cp)" 1>&2
cp new-boot.img $OUTPUT 2>/dev/null

echo "* New patched boot image:    [${OUTPUT}]" 1>&2
SHA1_ORIG=$( ./magiskboot cpio ramdisk.cpio sha1 2>/dev/null )
echo "* Stock boot image SHA1:     [${SHA1_ORIG}]" 1>&2

sha1sum /sdcard/Download/boot.img $INPUT 1>&2
sha1sum $OUTPUT

cd ..
rm -rf "$DIR"
# rm "$0"
exit 0
