#!/system/bin/sh

# -------------------------------
#     parasite.sh  by nooriro
# -------------------------------
# * Based on Airpil's custom Magisk for enabling diag mode on Pixel 2 XL [1][2]
# * Improved using Magisk 19.4+'s 'Root Directory Overlay System' [3]
# [1] https://forum.xda-developers.com/pixel-2-xl/how-to/guide-qxdm-port-activation-pixel-2-xl-t3884967
# [2] https://github.com/AGagarin/Magisk/blob/4db651f799/native/jni/core/magiskrc.h
# [3] https://github.com/topjohnwu/Magisk/blob/9164bf22c2/docs/guides.md#root-directory-overlay-system
# 
# Thanks: Airpil, daedae, gheron772, 파이어파이어, 픽셀2VOLTE, and topjohnwu
# ------------------------------------------------------------------------------
# Usage: (1) Make sure magisk patched boot image file ( 'magisk_patched.img'
#            or 'magisk_patched_XXXXX.img' or 'magisk_patched-VVVVV_XXXXX.img' )
#            exists in /sdcard/Download directory
#        (2) Make sure Magisk app (version code 21402+) is installed and not hidden
#            or place Magisk apk (21402+) file into /sdcard/Download
#           * Placing Magisk zip (v19.4+) file into /sdcard/Download is deprecated
#        (3) Place this script file into /data/local/tmp (in adb shell)
#                                or into ~               (in terminal apps)
#            and set execution permission
#        (4) Run this script file
# ------------------------------------------------------------------------------


# In terminal apps or adb shell interactive mode, $COLUMNS has the real value
# Otherwise $COLUMNS is set to be 80
# Note that below integer comparision treats non-number strings as zero integers
[ "$COLUMNS" -gt 0 -a "$COLUMNS" -lt 80 ] && DETAIL="false" || DETAIL="true"


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



# Util functions -------------------------------------------------------

# $1=MSG_PART1
# $2=MSG_PART2  (show only if "$DETAIL" != "false")
function echomsg() {
  if [ "$DETAIL" = "false" ]; then
    echo "$1" 1>&2 
  else 
    echo "$1$2" 1>&2 
  fi 
}

# some modification of grep_prop() in util_functions.sh in Magisk repo
# https://github.com/topjohnwu/Magisk/blob/v22.1/scripts/util_functions.sh#L28-L34
# $1=REGEX
# $2...=PROP_FILE...
function grep_prop() {
  local REGEX="s/^$1=//p"
  shift
  local FILES=$@
  [ -z "$FILES" ] && FILES='default.prop'
  cat $FILES 2>/dev/null | sed -n "$REGEX" | head -n 1
}

# $1=APKPATH
function extract_magiskboot_fromapk() {
  unzip "$1" lib/armeabi-v7a/libmagiskboot.so > /dev/null
  if [ -f lib/armeabi-v7a/libmagiskboot.so ]; then
    mv lib/armeabi-v7a/libmagiskboot.so magiskboot
    chmod u+x magiskboot  # mandatory for Termux app
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
    chmod u+x magiskboot  # mandatory for Termux app
    rm -rf arm
    return 0
  else
    return 1
  fi
}



# Subroutines ----------------------------------------------------------

function check_magiskpatchedimg() {
  local MAGISKPATCHEDIMG="/sdcard/Download/magisk_patched.img"
  # pre 7.1.2(208):                    patched_boot.img
  # app 7.1.2(208)-7.5.1(267):         magisk_patched.img
  # app 8.0.0(302)-1469b82a(315):      magisk_patched.img or 'magisk_patched (n).img'
  # app d0896984(316)-f152b4c2(22005): magisk_patched_XXXXX.img
  # app 66e30a77(22006)-latest:        magisk_patched-VVVVV_XXXXX.img
  local IMG="$( ls -1t $MAGISKPATCHEDIMG \
      /sdcard/Download/magisk_patched\ \([1-9]\).img \
      /sdcard/Download/magisk_patched\ \([1-9][0-9]\).img \
      /sdcard/Download/magisk_patched_[0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z].img \
      /sdcard/Download/magisk_patched-2200[6-7]_[0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z].img \
      /sdcard/Download/magisk_patched-22[1-9][0-9][0-9]_[0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z].img \
      /sdcard/Download/magisk_patched-2[3-9][0-9][0-9][0-9]_[0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z].img \
      2>/dev/null | head -n 1 )"
  if [ -z "$IMG" ]; then
    echo "! Magisk patched boot image is not found in /sdcard/Download" 1>&2
    return 1
  else
    echo "* Magisk patched boot image: [${IMG}]" 1>&2
    if [ "$IMG" != "$MAGISKPATCHEDIMG" ]; then
      [ -f "$MAGISKPATCHEDIMG" ] && rm $MAGISKPATCHEDIMG
      mv "$IMG" "$MAGISKPATCHEDIMG"
      echo "            --- renamed ---> [${MAGISKPATCHEDIMG}]" 1>&2
    fi
  fi
  return 0
}


function extract_magiskboot() {
  # $DIR and $PWD_PREV must be global
  DIR=""
  PWD_PREV="$PWD"

  # (1) Detect Magisk app 21402+

  # In every terminal app without root, pm command does not work
  local APP="$( pm path com.topjohnwu.magisk | grep base\\.apk )"
  [ "${APP:0:8}" = "package:" ] && APP="${APP:8}" || APP=""

  if [ -n "$APP" ]; then
    local APP_VER=$( dumpsys package com.topjohnwu.magisk | grep -o 'versionCode=[0-9]*' | cut -d "=" -f 2 )
    if [ "$APP_VER" -ge 21402 ]; then
      echo "* Magisk app version code:   [${APP_VER}] >= 21402" 1>&2
      # In Terminal Emulator app, $TMPDIR is empty
      DIR="$( [ -n "$TMPDIR" ] && mktemp -d || mktemp -d -p "$( dirname "$0" )" )"
      cd "$DIR"
      echomsg "- Extracting magiskboot from Magisk app" "           (unzip)"
      if extract_magiskboot_fromapk "$APP"; then
        return 0
      else
        echo "! Magisk app does not contain 'lib/armeabi-v7a/libmagiskboot.so'" 1>&2
      fi
    else
      echo "! Magisk app version code:   [${APP_VER}] < 21402" 1>&2
    fi
  else
    echo "! Magisk app is not detected" 1>&2
  fi

  # (2) Detect Magisk apk 21402+ in /sdcard/Download
  echo "             --------------> Fallback to Magisk apk file" 1>&2

  # $APK_TYPE0     = canary,          no version in filename
  # $APK_TYPE1     = canary,         has version in filename
  # $APK_TYPE[2-4] = stable or beta, has version in filename
  #
  # If at least one of $APK_TYPE[1-4] exists, the latest version of $APK_TYPE[1-4] is used.
  # Otherwise $APK_TYPE0 is used, if it exists.

  local APK_TYPE0=$( ls -1 /sdcard/Download/app-debug.apk 2>/dev/null )
  local APK_TYPE1=$( ls -1 /sdcard/Download/Magisk-6951d926\(21402\).apk \
      /sdcard/Download/Magisk-4cc41ecc\(21403\).apk  /sdcard/Download/Magisk-b1dbbdef\(21404\).apk \
      /sdcard/Download/Magisk-07bd36c9\(21405\).apk  /sdcard/Download/Magisk-6fb20b3e\(21406\).apk \
      /sdcard/Download/Magisk-0646f48e\(21407\).apk  /sdcard/Download/Magisk-721dfdf5\(21408\).apk \
      /sdcard/Download/Magisk-8476eb9f\(21409\).apk  /sdcard/Download/Magisk-b76c80e2\(21410\).apk \
      /sdcard/Download/Magisk-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\(2[2-9][0-9][0-9][0-9]\).apk \
      2>/dev/null | sort -k 2 -t \( | tail -n 1  )
  local APK_TYPE2=$( ls -1 /sdcard/Download/Magisk-v2[2-9].[0-9].apk \
      2>/dev/null | tail -n 1  )
  local APK_TYPE3=$( ls -1 /sdcard/Download/Magisk-v2[2-9].[0-9]\(2[2-9][0-9]00\).apk \
      2>/dev/null | tail -n 1  )
  local APK_TYPE4=$( ls -1 /sdcard/Download/Magisk-2[2-9].[0-9]\(2[2-9][0-9]00\).apk \
      2>/dev/null | tail -n 1  )
  local APK_TYPE1_VER="-1"; [ -n "$APK_TYPE1" ] && APK_TYPE1_VER="${APK_TYPE1:33:5}"
  local APK_TYPE2_VER="-1"; [ -n "$APK_TYPE2" ] && APK_TYPE2_VER="${APK_TYPE2:25:2}${APK_TYPE2:28:1}00"
  local APK_TYPE3_VER="-1"; [ -n "$APK_TYPE3" ] && APK_TYPE3_VER="${APK_TYPE3:30:5}"
  local APK_TYPE4_VER="-1"; [ -n "$APK_TYPE4" ] && APK_TYPE4_VER="${APK_TYPE4:29:5}"
  # echo "$APK_TYPE1_VER  $APK_TYPE2_VER  $APK_TYPE3_VER  $APK_TYPE4_VER"

  local APK
  # If all of the $APK_TYPE[1-4] are empty (= that is, if there's no versioned Magisk apk file),
  #    ---> Use $APK_TYPE0 (if exists)
  # Otherwise,
  #    ---> Use the latest version of $APK_TYPE[1-4]
  if [ -z "$APK_TYPE1" -a -z "$APK_TYPE2" -a -z "$APK_TYPE3" -a -z "$APK_TYPE4" ]; then
    if [ -z "$APK_TYPE0" ]; then
      echo "! Magisk apk is not found in /sdcard/Download (v22.0+ required)" 1>&2
    else
      APK=$APK_TYPE0
    fi
  elif [ "$APK_TYPE1_VER" -ge "$APK_TYPE2_VER" -a "$APK_TYPE1_VER" -ge "$APK_TYPE3_VER" -a "$APK_TYPE1_VER" -ge "$APK_TYPE4_VER" ]; then
    APK=$APK_TYPE1
  elif [ "$APK_TYPE2_VER" -ge "$APK_TYPE3_VER" -a "$APK_TYPE2_VER" -ge "$APK_TYPE4_VER" ]; then
    APK=$APK_TYPE2
  elif [ "$APK_TYPE3_VER" -ge "$APK_TYPE4_VER" ]; then
    APK=$APK_TYPE3
  else
    APK=$APK_TYPE4
  fi

  if [ -n "$APK" ]; then
    echo "* Magisk apk:                [${APK}]" 1>&2
    if [ -z "$DIR" ]; then
      # In Terminal Emulator app, $TMPDIR is empty
      DIR="$( [ -n "$TMPDIR" ] && mktemp -d || mktemp -d -p "$( dirname "$0" )" )"
      cd "$DIR"
    fi
    echomsg "- Extracting magiskboot from Magisk apk" "           (unzip)"
    if extract_magiskboot_fromapk "$APK"; then
      return 0
    else
      echo "! Magisk apk does not contain 'lib/armeabi-v7a/libmagiskboot.so'" 1>&2
    fi
  fi


  # (3) Detect Magisk zip 19400+ in /sdcard/Download (legacy method, deprecated)
  echo "             --------------> Fallback to Magisk zip file" 1>&2

  # $ZIP_TYPE0     = canary,          no version in filename
  # $ZIP_TYPE1     = canary,         has version in filename
  # $ZIP_TYPE[2-4] = stable or beta, has version in filename
  #
  # If at least one of $ZIP_TYPE[1-4] exists, the latest version of $ZIP_TYPE[1-4] is used.
  # Otherwise $ZIP_TYPE0 is used, if it exists.

  local ZIP_TYPE0=$( ls -1 /sdcard/Download/magisk-debug.zip 2>/dev/null )
  local ZIP_TYPE1=$( ls -1 /sdcard/Download/Magisk-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\(194[0-9][0-9]\).zip \
      /sdcard/Download/Magisk-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\(20[0-4][0-9][0-9]\).zip \
      /sdcard/Download/Magisk-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\(21[0-3][0-9][0-9]\).zip \
      /sdcard/Download/Magisk-f5593e05\(21401\).zip \
      2>/dev/null | sort -k 2 -t \( | tail -n 1  )
  local ZIP_TYPE2=$( ls -1 /sdcard/Download/Magisk-v19.4.zip \
      /sdcard/Download/Magisk-v2[0-1].[0-4].zip \
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
      echo "! Magisk zip is not found in /sdcard/Download (v19.4+ required)" 1>&2
      if [ -n "$DIR" ]; then
        cd "$PWD_PREV"
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
    # In Terminal Emulator app, $TMPDIR is empty
    DIR="$( [ -n "$TMPDIR" ] && mktemp -d || mktemp -d -p "$( dirname "$0" )" )"
    cd "$DIR"
  fi
  echomsg "- Extracting magiskboot from Magisk zip" "           (unzip)"
  if extract_magiskboot_fromzip "$ZIP"; then
    return 0
  else
    echo "! Magisk zip does not contain 'arm/magiskboot'" 1>&2
    cd "$PWD_PREV"
    rm -rf "$DIR"
    return 4
  fi
}


# must be run after unpacking (magisk patched) boot image
# takes no arguments
function test_bootimg() {
  local SEP="------------------------------------------------------------------------------------------------"
  if [ "$COLUMNS" = 80 -a "$LINES" = 24 ]; then
    :  # 80x24 ---> non-interactive adb shell ---> do not resize $SEP
  elif [ "$COLUMNS" -lt ${#SEP} ]; then
    # Shrink $SEP length to match $COLUMN value
    SEP="$( echo "$SEP" | cut -b 1-"$COLUMNS" )"
  fi

  local MANUFACTURER_THIS="$(getprop ro.product.manufacturer)"
  local        MODEL_THIS="$(getprop ro.product.model)"
  local       DEVICE_THIS="$(getprop ro.product.device)"
  local         NAME_THIS="$(getprop ro.product.name)"
  local  BUILDNUMBER_THIS="$(getprop ro.build.id)"
  local  INCREMENTAL_THIS="$(getprop ro.build.version.incremental)"
  local    TIMESTAMP_THIS="$(getprop ro.build.date.utc)"

  local MANUFACTURER_BOOT MODEL_BOOT DEVICE_BOOT NAME_BOOT
  local BUILDNUMBER_BOOT INCREMENTAL_BOOT TIMESTAMP_BOOT

  # Extrating a file via magiskboot yields 'Bad system call' (exit code 159) in terminal apps w/o root
  # Instead of magiskboot cpio command, Use toybox cpio (Android 6+ built-in) to extract files
  mkdir ramdisk
  cd ramdisk
  /system/bin/cpio -i -F ../ramdisk.cpio 2>/dev/null
  cd ..
  # Normal copy (i.e running cp without any options) suffices.
  # If ramdisk/default.prop is a symlink (like modern Pixel boot images),
  # the dereferenced file is copied actually.
  cp ramdisk/default.prop . 2>/dev/null
  cp ramdisk/selinux_version . 2>/dev/null

  if [ -f default.prop ]; then
    # ALL Pixel boot images has these properties
    # ALL Nexus boot images doesn't have these properties
    MANUFACTURER_BOOT="$(grep_prop ro\\.product\\.manufacturer)"
           MODEL_BOOT="$(grep_prop ro\\.product\\.model       )"
          DEVICE_BOOT="$(grep_prop ro\\.product\\.device      )"
            NAME_BOOT="$(grep_prop ro\\.product\\.name        )"
    [ -z "$MANUFACTURER_BOOT" ] && MANUFACTURER_BOOT="$(grep_prop ro\\.product\\.vendor\\.manufacturer)"
    [ -z        "$MODEL_BOOT" ] &&        MODEL_BOOT="$(grep_prop ro\\.product\\.vendor\\.model       )"
    [ -z       "$DEVICE_BOOT" ] &&       DEVICE_BOOT="$(grep_prop ro\\.product\\.vendor\\.device      )"
    [ -z         "$NAME_BOOT" ] &&         NAME_BOOT="$(grep_prop ro\\.product\\.vendor\\.name        )"
     BUILDNUMBER_BOOT="$(grep_prop ro\\.build\\.id)"
     INCREMENTAL_BOOT="$(grep_prop ro\\.build\\.version\\.incremental)"
       TIMESTAMP_BOOT="$(grep_prop ro\\.build\\.date\\.utc)"

    # ALL Pixel boot images / API 23-27 of Nexus
    [ -z "$TIMESTAMP_BOOT" ] && TIMESTAMP_BOOT="$(grep_prop ro\\.bootimage\\.build\\.date\\.utc)"
    local FP="$(grep_prop ro\\.bootimage\\.build\\.fingerprint)"
    if [ -n "$FP" ]; then
      # https://stackoverflow.com/questions/918886/how-do-i-split-a-string-on-a-delimiter-in-bash/29903172#29903172
      # EXAMPLE of $FP: google/ryu/dragon:8.1.0/OPM8.190605.005/5749003:user/release-keys
      [ -z        "$NAME_BOOT" ] &&        NAME_BOOT="$( echo "$FP" | cut -d "/" -f 2                   )"  # ryu
      [ -z      "$DEVICE_BOOT" ] &&      DEVICE_BOOT="$( echo "$FP" | cut -d "/" -f 3 | cut -d ":" -f 1 )"  # dragon
      [ -z "$BUILDNUMBER_BOOT" ] && BUILDNUMBER_BOOT="$( echo "$FP" | cut -d "/" -f 4                   )"  # OPM8.190605.005
      [ -z "$INCREMENTAL_BOOT" ] && INCREMENTAL_BOOT="$( echo "$FP" | cut -d "/" -f 5 | cut -d ":" -f 1 )"  # 5749003
    fi
  fi

  # API 25 of Pixel / API 21-25 of Nexus
  if [ -f selinux_version ]; then
    local FP2="$(cat selinux_version)"
    if [ -n "$FP2" ]; then
      # https://stackoverflow.com/questions/918886/how-do-i-split-a-string-on-a-delimiter-in-bash/29903172#29903172
      # EXAMPLE of $FP2: google/occam/mako:5.1.1/LMY48T/2237560:user/dev-keys
      [ -z        "$NAME_BOOT" ] &&        NAME_BOOT="$( echo "$FP2" | cut -d "/" -f 2                   )"  # occam
      [ -z      "$DEVICE_BOOT" ] &&      DEVICE_BOOT="$( echo "$FP2" | cut -d "/" -f 3 | cut -d ":" -f 1 )"  # mako
      [ -z "$BUILDNUMBER_BOOT" ] && BUILDNUMBER_BOOT="$( echo "$FP2" | cut -d "/" -f 4                   )"  # LMY48T
      [ -z "$INCREMENTAL_BOOT" ] && INCREMENTAL_BOOT="$( echo "$FP2" | cut -d "/" -f 5 | cut -d ":" -f 1 )"  # 2237560
    fi
  fi

  local RESULT
  if [ -n "$NAME_BOOT" -a -n "$BUILDNUMBER_BOOT" -a -n "$INCREMENTAL_BOOT" ]; then
    # boot image identified
    if [ "$NAME_BOOT" = "$NAME_THIS" -a \
         "$BUILDNUMBER_BOOT" = "$BUILDNUMBER_THIS" -a \
         "$INCREMENTAL_BOOT" = "$INCREMENTAL_THIS" ]; then
      RESULT="good"
    else
      RESULT="bad"
    fi
  else
    # boot image cannot be identified
    RESULT="dontknow"
  fi

  # head command (of toybox) in Oreo 8.0 does not support -c option.
  # Use cut -b / cut -c command instead:
  #   echo "----------" | cut -b 1-3
  # Note that cut -b adds newline at the end of output (like echo), while head -c does not.
  #   echo "----------" | head -c 3 | xxd -g1
  #   echo "----------" | cut -b 1-3 | xxd -g1
  # Another method: Use sed to change every character to '-'
  #   ---> Doesn't work in adb shell on Android 6 on Nexus 7 2013 (infinity loop on sed s/./-/g )
  #   ---> Use cub -b 1-N instead.
  [ -z "$MANUFACTURER_BOOT" ] && MANUFACTURER_BOOT="$( echo "$SEP" | cut -b 1-${#MANUFACTURER_THIS} )"
  [ -z        "$MODEL_BOOT" ] &&        MODEL_BOOT="$( echo "$SEP" | cut -b 1-${#MODEL_THIS}        )"
  [ -z       "$DEVICE_BOOT" ] &&       DEVICE_BOOT="$( echo "$SEP" | cut -b 1-${#DEVICE_THIS}       )"
  [ -z         "$NAME_BOOT" ] &&         NAME_BOOT="$( echo "$SEP" | cut -b 1-${#NAME_THIS}         )"
  [ -z  "$BUILDNUMBER_BOOT" ] &&  BUILDNUMBER_BOOT="$( echo "$SEP" | cut -b 1-${#BUILDNUMBER_THIS}  )"
  [ -z  "$INCREMENTAL_BOOT" ] &&  INCREMENTAL_BOOT="$( echo "$SEP" | cut -b 1-${#INCREMENTAL_THIS}  )"
  [ -z    "$TIMESTAMP_BOOT" ] &&    TIMESTAMP_BOOT="$( echo "$SEP" | cut -b 1-${#TIMESTAMP_THIS}    )"

  echo "$SEP" 1>&2
  if [ "$DETAIL" = "false" ]; then
    echo "  BOOT IMAGE:  [${NAME_BOOT}] [${BUILDNUMBER_BOOT}] [${INCREMENTAL_BOOT}]" 1>&2
    echo "  THIS DEVICE: [${NAME_THIS}] [${BUILDNUMBER_THIS}] [${INCREMENTAL_THIS}]" 1>&2
  else
    echo "  BOOT IMAGE:  [${MANUFACTURER_BOOT}] [${MODEL_BOOT}] [${DEVICE_BOOT}] | [${NAME_BOOT}] [${BUILDNUMBER_BOOT}] [${INCREMENTAL_BOOT}]" 1>&2
    echo "  THIS DEVICE: [${MANUFACTURER_THIS}] [${MODEL_THIS}] [${DEVICE_THIS}] | [${NAME_THIS}] [${BUILDNUMBER_THIS}] [${INCREMENTAL_THIS}]" 1>&2
  fi
  echo "$SEP" 1>&2

  case "$RESULT" in
    "good")
      echo "  su -c \"setenforce 0; setprop sys.usb.configfs 1 && setprop sys.usb.config diag,serial_cdev,rmnet_gsi,adb\"" 1>&2
      echo "$SEP" 1>&2
      return 0
      ;;
    "bad")
      echo "  *** WARNING: DO NOT FLASH 'magisk_patched.img' OR 'magisk_patched_diag.img' ON THIS DEVICE" 1>&2
      echo "$SEP" 1>&2
      return 1
      ;;
    "dontknow")
      echo "  *** CAUTION: Boot image cannot be identified. DOUBLE CHECK where the boot image came from." 1>&2
      echo "$SEP" 1>&2
      return 2
      ;;
  esac
  return 3
}



check_magiskpatchedimg || exit $?
extract_magiskboot || exit $?

INPUT="/sdcard/Download/magisk_patched.img"
OUTPUT="/sdcard/Download/magisk_patched_diag.img"

echomsg "- Dropping diag.rc" "                                (printf >)"
printf "%s" "$DIAG_RC_CONTENTS" > diag.rc

echomsg "- Unpacking magisk_patched.img" "                    (magiskboot unpack)"
./magiskboot unpack $INPUT 2>/dev/null

echomsg "- Inserting diag.rc into ramdisk.cpio" "             (magiskboot cpio)"
./magiskboot cpio ramdisk.cpio \
  "mkdir 750 overlay.d" \
  "add 644 overlay.d/diag.rc diag.rc" 2>/dev/null

echomsg "- Repacking boot image" "                            (magiskboot repack)"
./magiskboot repack $INPUT 2>/dev/null

echomsg "- Copying new boot image into /sdcard/Download" "    (cp)"
cp new-boot.img $OUTPUT 2>/dev/null

echo "* New patched boot image:    [${OUTPUT}]" 1>&2
SHA1_ORIG=$( ./magiskboot cpio ramdisk.cpio sha1 2>/dev/null )
echo "* Stock boot image SHA-1:    [${SHA1_ORIG}]" 1>&2

test_bootimg
sha1sum /sdcard/Download/boot.img $INPUT 1>&2
sha1sum $OUTPUT

cd "$PWD_PREV"
rm -rf "$DIR"
# rm "$0"
exit 0
