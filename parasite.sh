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
# Thanks: Airpil, daedae, gheron772, ÌååÏù¥Ïñ¥ÌååÏù¥Ïñ¥, ÌîΩÏÖÄ2VOLTE, and topjohnwu
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


for ARG in "$@"; do
  # How to perform a for loop on each character in a string in Bash?
  # https://stackoverflow.com/questions/10551981/how-to-perform-a-for-loop-on-each-character-in-a-string-in-bash/29906163#29906163
  # A variable modified inside a while loop is not remembered
  # https://stackoverflow.com/questions/16854280/a-variable-modified-inside-a-while-loop-is-not-remembered/16854326#16854326


  # On Android Marshmallow, the code below doesn't work: got this error:
  # /data/local/tmp/parasite.sh[43]: can't create temporary file /data/local/shu896p5.tmp: Permission denied
  # while read -n1 CHAR; do
  #   case "$CHAR" in
  #     "d")  ...   ;;
  #     "r")  ...   ;;
  #     "v")  ...   ;;
  #     "m")  ...   ;;
  #     "l")  ...   ;;
  #   esac
  # done <<< "$ARG"
  #
  # sees to be trying create temp directory for here-doc ( <<< "$ARG" )
  # in /data/local directory, which can't write a file
  # https://unix.stackexchange.com/questions/429285/cannot-create-temp-file-for-here-document-permission-denied

  # So I tried to find another method.
  # https://stackoverflow.com/questions/10551981/how-to-perform-a-for-loop-on-each-character-in-a-string-in-bash/42964584#42964584
  #
  # The code below works on Android Marshmallow, as well as on Android 11
  I=1
  while [ $I -le ${#ARG} ]; do
      CHAR="$(printf '%s' "$ARG" | cut -c $I-$I)"
      case "$CHAR" in
        "k")        KEEP_TEMPDIR="true"     ;;
        "r")        SELF_REMOVAL="true"     ;;
        "m") export PARASITE_MORE="true"    ;;
        "l") export PARASITE_MORE="false"   ;;
        "v") export PARASITE_VERBOSE="true" ;;
        "d") export PARASITE_DEBUG="true"   ;;
      esac
      I=$(expr $I + 1)
  done
done
unset I CHAR ARG


# For detailed output
function is_detail() {
  [ "$PARASITE_MORE" = "true" ] && return 0
  [ "$PARASITE_MORE" = "false" ] && return 1
  # In terminal apps or adb shell interactive mode, $COLUMNS has the real value
  # Otherwise $COLUMNS is set to be 80
  # Note that below integer comparision treats non-number strings as zero integers
  [ "$COLUMNS" -gt 0 -a "$COLUMNS" -lt 70 ] && return 1 || return 0
}

# For verbose output
function is_verbose() {
  [ "$PARASITE_VERBOSE" = "true" ] && return 0 || return 1
}

# For debugging
function is_debug() {
  [ "$PARASITE_DEBUG" = "true" ] && return 0 || return 1
}
is_debug && set -x


# For Termux on some old Android versions
printenv LD_LIBRARY_PATH > /dev/null && LD_LIBRARY_PATH_BACKUP="$LD_LIBRARY_PATH"
printenv LD_PRELOAD      > /dev/null && LD_PRELOAD_BACKUP="$LD_PRELOAD"

# Absolute cannonical path of this script
# On Oreo 8.1, readlink -f does not work. Use realpath instead.
SCRIPT="$(realpath "$0")"

# OS API level
# 21 = Lollipop 5.0   22 = Lollipop 5.1   23 = Marshmallow 6.0
# 24 = Nougat 7.0     25 = Nougat 7.1     26 = Oreo 8.0          27 = Oreo 8.1
# 28 = Pie 9.0        29 = Q 10.0         30 = R 11.0            31 = S 12.0
API=$(getprop ro.build.version.sdk)


# CRC32 / MD5 / SHA-1 / SHA-256 hash values of classes.dex
DEX_EXPECTED_CRC32="e1670320"
DEX_EXPECTED_MD5="190ac5d2a952fb86fcaa241f7319ec8f"
DEX_EXPECTED_SHA1="ca77ec579602572e336aed3ce90e5527119feb45"
DEX_EXPECTED_SHA256="a1e9b299e030cd4e9a7cd42a2d1eec4b60e0af7b722d0cc62cbb82bf9da6cb4f"

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
# $2=MSG_PART2  (show only if is_detail returns zero)
function echomsg() {
  is_detail && echo "$1$2" 1>&2 || echo "$1" 1>&2
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

# $1=EXITCODE
# If no $1, do not exit (finalize only)
function finalize() {
  if [ -n "$DIR" ]; then
    cd ..
    is_debug || [ "$KEEP_TEMPDIR" = "true" ] || rm -rf "$DIR"
  fi
  if [ "$1" -eq 0 ]; then
    is_debug || [ "$SELF_REMOVAL" != "true" ] || rm "$SCRIPT"
  fi
  [ -n "$1" ] && exit "$1"
}

function run_class() {
  is_verbose && [ ! -f classes.dex ] && { local DATETIME="$(date '+%Y-%m-%d %H:%M:%S.%N')"; echo "* DEX extracting start:      [${DATETIME:0:23}]" 1>&2; }
  [ -f classes.dex ] || tail -n +523 "$SCRIPT" > classes.dex
  
  is_verbose && { local DATETIME="$(date '+%Y-%m-%d %H:%M:%S.%N')"; echo "* DEX running start:         [${DATETIME:0:23}]" 1>&2; }
  unset LD_LIBRARY_PATH LD_PRELOAD
  if [ $API -ge 26 ]; then
    /system/bin/app_process -cp classes.dex . "$@"
  else 
    CLASSPATH=$DIR/classes.dex /system/bin/app_process . "$@"
  fi 
  local EXITCODE=$?
  is_verbose && { local DATETIME="$(date '+%Y-%m-%d %H:%M:%S.%N')"; echo "* DEX running finish:        [${DATETIME:0:23}]" 1>&2; }
  
  # How to check if a variable is set in Bash?
  # https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash/13864829#13864829
  [ -z ${LD_LIBRARY_PATH_BACKUP+x} ] || export LD_LIBRARY_PATH="$LD_LIBRARY_PATH_BACKUP"
  [ -z ${LD_PRELOAD_BACKUP+x}      ] || export LD_PRELOAD="$LD_PRELOAD_BACKUP"
  return $EXITCODE
} 



# Subroutines ----------------------------------------------------------

function check_os_api_level() {
  local MIN_API=23   # Marshmallow (Android 6.0)
  if [ "$API" -ge "$MIN_API" ]; then
    is_verbose && echo "* Android API level:         [${API}] >= ${MIN_API}" 1>&2
    return 0
  else
    echo "! Android API level:         [${API}] < ${MIN_API}" 1>&2
    return 1
  fi
}


function check_storage_permission() {
  local PATH="/sdcard/Download"
  local READ WRITE EXECUTE
  [ -r "$PATH" ] && READ="r" || READ="-"
  [ -w "$PATH" ] && WRITE="w" || WRITE="-"
  [ -x "$PATH" ] && EXECUTE="x" || EXECUTE="-"
  local PERMISSION="${READ}${WRITE}${EXECUTE}"
  if [ "$PERMISSION" = "rwx" ]; then
    is_verbose && echo "* Storage permission:        [${PERMISSION}] = rwx" 1>&2
    return 0
  else
    echo "! Storage permission:        [${PERMISSION}] != rwx" 1>&2
    return 1
  fi
}


function check_magiskpatchedimg() {

  # pre 7.1.2(208):                    patched_boot.img
  # app 7.1.2(208)-7.5.1(267):         magisk_patched.img
  # app 8.0.0(302)-1469b82a(315):      magisk_patched.img or 'magisk_patched (n).img'
  # app d0896984(316)-f152b4c2(22005): magisk_patched_XXXXX.img
  # app 66e30a77(22006)-latest:        magisk_patched-VVVVV_XXXXX.img

  # Marshmallow's toolbox ls command has neither -1 nor -t option
  # Workaround: Run toybox ls directly using '/system/bin/toybox ls' command
  local MAGISKPATCHEDIMG="/sdcard/Download/magisk_patched.img"
  local IMG="$( /system/bin/toybox ls -1t $MAGISKPATCHEDIMG \
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
    if is_verbose; then
      local TIME="$(stat -c %y "$MAGISKPATCHEDIMG")"
      echo "* Patched boot image mtime:  [${TIME:0:23}]" 1>&2
    fi
  fi
  return 0
}


function initialize_tempdir() {
  # global $SCRIPT must be set before calling this function
  local SCRIPTDIR="$( dirname "$SCRIPT" )"

  # $DIR must be global
  # DO NOT set global $DIR outside of this function

  [ -n "$DIR" ] && return 0     # If already created & entered, do nothing and return

  if [ -n "$TMPDIR" ] && [[ "$(realpath "$TMPDIR")" != /storage/* ]] && [ -r "$TMPDIR" -a -w "$TMPDIR" -a -x "$TMPDIR" ]; then
    cd "$TMPDIR"
  elif [ -n "$HOME" ] && [[ "$(realpath "$HOME")" != /storage/* ]] && [ -r "$HOME" -a -w "$HOME" -a -x "$HOME" ]; then
    cd "$HOME"
  elif [ -n "$SCRIPTDIR" ] && [[ "$(realpath "$SCRIPTDIR")" != /storage/* ]] && [ -r "$SCRIPTDIR" -a -w "$SCRIPTDIR" -a -x "$SCRIPTDIR" ]; then
    cd "$SCRIPTDIR"
  else
    echo "! Can't do file I/O in TMPDIR('${TMPDIR}') or HOME('${HOME}') or SCRIPTDIR('${SCRIPTDIR}')" 1>&2
    return 1;
  fi

  local NAME="par-$(date '+%y%m%d-%H%M%S')"
  if [ ! -e "$NAME" ]; then
    mkdir "$NAME"
  else
    local A B C
    for A in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z; do
      for B in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z; do
        for C in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z; do
          if [ ! -e "$NAME-$A$B$C" ]; then
            NAME="$NAME-$A$B$C"
            mkdir "$NAME"
            break 3
          fi
        done
      done
    done
  fi

  chmod 700 "$NAME"
  cd "$NAME"
  DIR="$PWD"
  return 0
}


function extract_magiskboot() {
  run_class ParasiteEmb > magiskboot
  local EXITCODE=$?
  # For Termux app, setting execution permission is mandatory
  [ $EXITCODE -eq 0 ] && chmod u+x magiskboot || rm magiskboot
  return $EXITCODE
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
  cp ramdisk/system/etc/ramdisk/build.prop . 2>/dev/null   # bramble/redfin of Android S

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
  elif [ -f build.prop ]; then
    # ramdisk/system/etc/ramdisk/build.prop exists ONLY IN bramble/redfin boot image of Android 12 (DP1~)
    MANUFACTURER_BOOT="$(grep_prop ro\\.product\\.bootimage\\.manufacturer        build.prop)"
           MODEL_BOOT="$(grep_prop ro\\.product\\.bootimage\\.model               build.prop)"
          DEVICE_BOOT="$(grep_prop ro\\.product\\.bootimage\\.device              build.prop)"
            NAME_BOOT="$(grep_prop ro\\.product\\.bootimage\\.name                build.prop)"
     BUILDNUMBER_BOOT="$(grep_prop ro\\.bootimage\\.build\\.id                    build.prop)"
     INCREMENTAL_BOOT="$(grep_prop ro\\.bootimage\\.build\\.version\\.incremental build.prop)"
       TIMESTAMP_BOOT="$(grep_prop ro\\.bootimage\\.build\\.date\\.utc            build.prop)"
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
  if is_detail; then
    echo "  BOOT IMAGE:  [${MANUFACTURER_BOOT}] [${MODEL_BOOT}] [${DEVICE_BOOT}] | [${NAME_BOOT}] [${BUILDNUMBER_BOOT}] [${INCREMENTAL_BOOT}]" 1>&2
    echo "  THIS DEVICE: [${MANUFACTURER_THIS}] [${MODEL_THIS}] [${DEVICE_THIS}] | [${NAME_THIS}] [${BUILDNUMBER_THIS}] [${INCREMENTAL_THIS}]" 1>&2
  else
    echo "  BOOT IMAGE:  [${NAME_BOOT}] [${BUILDNUMBER_BOOT}] [${INCREMENTAL_BOOT}]" 1>&2
    echo "  THIS DEVICE: [${NAME_THIS}] [${BUILDNUMBER_THIS}] [${INCREMENTAL_THIS}]" 1>&2
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



check_os_api_level || finalize $?
check_storage_permission || finalize $?
check_magiskpatchedimg || finalize $?
initialize_tempdir || finalize $?
extract_magiskboot || finalize $?

INPUT="/sdcard/Download/magisk_patched.img"
OUTPUT="/sdcard/Download/magisk_patched_diag.img"

echomsg "- Dropping diag.rc" "                                (printf >)"
printf "%s" "$DIAG_RC_CONTENTS" > diag.rc || finalize $?

echomsg "- Unpacking magisk_patched.img" "                    (magiskboot unpack)"
./magiskboot unpack $INPUT 2>/dev/null || finalize $?

echomsg "- Inserting diag.rc into ramdisk.cpio" "             (magiskboot cpio)"
./magiskboot cpio ramdisk.cpio \
  "mkdir 750 overlay.d" \
  "add 644 overlay.d/diag.rc diag.rc" 2>/dev/null || finalize $?

echomsg "- Repacking boot image" "                            (magiskboot repack)"
./magiskboot repack $INPUT 2>/dev/null || finalize $?

echomsg "- Copying new boot image into /sdcard/Download" "    (cp)"
cp new-boot.img $OUTPUT 2>/dev/null || finalize $?

echo "* New patched boot image:    [${OUTPUT}]" 1>&2
SHA1_ORIG=$( ./magiskboot cpio ramdisk.cpio sha1 2>/dev/null )
echo "* Stock boot image SHA-1:    [${SHA1_ORIG}]" 1>&2

test_bootimg
sha1sum /sdcard/Download/boot.img $INPUT 1>&2
sha1sum $OUTPUT

finalize   # no args == do not exit (finalize only)
exit 0
dex
035 Ç16£íÆÍõ¥ÃÌáÅYı≠_{∞D†‘g  p   xV4        g  ›  p   S   ‰  N   0	  7   ÿ  ∏   ê     P  ‰Q    û@  †@  £@  ß@  ÷@  Í@  #A  >A  BA  SA  cA  sA  wA  õA  ”A  ÏA  ;B  }B  ¶B  ∆B  ÊB  ÈB  ÔB  ÛB   C  C  C  &C  5C  UC  uC  ïC  µC  ÀC  ÎC  D  +D  =D  ND  `D  iD  wD  ÅD  ÑD  ïD  úD  ∆D  …D  ÃD  ﬁD  ÓD  ÒD  ıD  ˙D  ˝D  E  E  E  E  E  jE  £E  ≠E  „E  ÁE  ÏE  ˛E  F  1F  4F  DF  RF  YF  kF  rF  ÜF  óF  ¶F  ºF  …F  “F  ÌF  ˇF  G  <G  ?G  DG  HG  MG  RG  mG  qG  wG  zG  ~G  èG  †G  £G  √G  ﬁG  ‚G  ÒG  ıG  ˙G  H  H  H  H  %H  ,H  1H  EH  RH  _H  pH  ÅH  íH  °H  øH  –H  ‘H  ˙H  %I  KI  aI  I  úI  ∂I  œI  ÛI  J  8J  [J  zJ  ñJ  ∞J   J  ⁄J  J  K  ,K  CK  ZK  wK  èK  ≠K  ƒK  ÷K  ËK  L  L  *L  <L  _L  sL  àL  ùL  ±L  ÀL  ÊL  ˙L  M  0M  ZM  xM  èM  æM  ◊M  ÓM  N  N  -N  CN  UN  {N  ãN  úN  ¥N  ≈N  ﬂN  ¯N  O  )O  GO  `O  lO  }O  ÇO  ôO  ™O  ∞O  πO  …O  ŸO  ÈO  ¯O  
P  P  0P  8P  LP  `P  gP  pP  yP  ÇP  ãP  ñP  õP  °P  ØP  ∆P  ÌP  P  ˘P  ˝P  Q  Q  Q  Q  Q  Q  Q  !Q  %Q  )Q  :Q  OQ  dQ  gQ  mQ  tQ  yQ  ÄQ  ûQ  √Q  R  	R  R  "R  'R  ,R  7R  <R  AR  JR  RR  XR  _R  oR  tR  ÅR  åR  ñR  §R  ∞R  ªR  ∆R  ”R  ﬁR  ·R  ÂR  ÏR  ÙR  ˚R  S  S  "S  )S  .S  3S  <S  HS  TS  jS  ÑS  ìS  §S  ≠S  ∏S  √S  œS  ‹S  „S  ÒS  ¯S  T  T  (T  .T  =T  ET  UT  `T  eT  mT  zT  T  ÇT  ëT  ûT  •T  ¨T  ¥T  πT  øT  ≈T  ÃT  “T  ‹T  ÊT  T  ˜T  ˛T  U  U  U  *U  ;U  EU  OU  _U  lU  ÅU  ïU  ®U  ±U  ¬U  “U  €U  ËU  ÙU   V  V  V  "V  2V  BV  JV  VV  ^V  aV  jV  pV  {V  ÖV  èV  ìV  ñV  öV  ûV  ¶V  ¨V  æV  «V  ‘V  ‹V  ÍV  ˛V  W  W  W  W  )W  1W  SW  [W  bW  lW  vW  ÅW  ÖW  ãW  ôW  ßW  µW  ªW  ≈W  ÀW  ’W  ﬁW  „W  ÏW  ˆW  ˚W   X  
X  X  X  X  (X  0X  8X  AX  GX  MX  SX  ^X  kX  oX  sX  xX  }X  ãX  îX  †X  ≤X  øX  ¬X  ÀX  ÿX  ‚X  ËX  ÚX  ˘X  ˝X  Y  Y  Y  &Y  /Y  4Y  ?Y  DY  JY  TY  \Y  cY  oY  }Y  åY  ëY  îY  òY  †Y  •Y  ´Y  ≥Y  ªY  √Y  ÀY  ”Y  ŸY  ﬂY  ÁY  ÓY  ˛Y  Z  Z  Z  Z  #Z  .Z  3Z  9Z  ?Z  EZ  QZ  YZ  aZ  nZ  xZ  ~Z  ÑZ  åZ  ìZ  úZ  ©Z  ºZ  …Z  –Z  ÿZ  ›Z  ËZ  [  [  [  D   T   \   a   b   d   g   n   o   p   q   r   s   t   u   v   x   y   z   {   |   }   ~      Ä   Å   Ç   É   Ñ   Ö   Ü   á   à   â   ä   ã   å   ç   é   è   ê   ë   í   ì   î   ï   ñ   ó   ò   ô   ö   õ   ú   ù   û   ü   †   °   ¢   £   §   ¶   ®   ©   ™   ´   ¨   Ø   ∞   ±   ≤   ≥   ¥   µ   ∂   ∑   ‘   ‹   ﬂ   ‡   ·   ‚   „   T          U      ú?  X      §?  X      ¨?  V      ¥?  Z      º?  V      ƒ?  W      Ã?  V      ‘?  \          ]      ‹?  i      ¥?  k      ‰?  i      ?  i      ¥?  `   %       i   %   ¯?  `   '       m   )    @  i   +   @  `   -       e   .   @  `   1       e   1   @  i   1   @  m   1   ¨?  i   2   ‘?  `   3       `   4       e   4   @  f   4   ú?  i   4   ‹?  m   4    @  i   4   ¥?  m   4   (@  m   4    @  i   4   0@  i   4   ƒ?  j   4   Ã?  l   4   8@  i   5   ¥?  c   6   D@  e   6   @  h   6   L@  i   6   @  i   6   ¥?  w   6   º?  i   9   ¥?  `   A       `   E       `   I       i   I   ¥?  `   K       ‘   L       ÷   L   @  ◊   L   T@  ÿ   L   ‹?  ÿ   L   \@  ÿ   L   d@  ÿ   L   l@  ÿ   L   t@  ÿ   L   @  ÿ   L   ¥?  ⁄   L   |@  ⁄   L   Ñ@  €   L   º?  ÿ   L   ƒ?  Ÿ   L   å@  ÿ   L   ò@  ÿ   L   ‘?  ‹   M       ﬁ   M   ‹?  ﬁ   M   @  ﬁ   M   ¥?  `   N       i   N   ‹?  m   N    @  i   P   å?   4 ô    “   4 ‘   K ⁄   4 t    u   4 v   K w   4 x    J     N     O     Œ    4 ô   4 ª    “   4 ‘   4 P    4 Q     º    4 –    4 t    u   4 v   K w   4 x  	 4 Q   	 4 R   	 4 ^   	 4 _   	  º   	 4 –   	  u  	 4 v  	 K w  	 4 x   4 A    4 M    4 «    4 »    4 œ     K     L     ª        M "    n   C E    C F    M I    4 Ω    4 œ    M ’   7 ) /  7 ) ë   5 8    > 8     
   2 C     D    G    M     O    P   4 Q    R   F f    ï    Ã   5 8    E y   2 C     D    G    M     O    P   4 Q    R   F f    ï   5 8    '    &    % !    `   > §   7 •   > 8     
   2 C     D    M   F f  	 > 8   	  
  	 2 C  	   D  	  M  	 F f  
 5 8   
 G Ï    5 8    G Ï    5 8            5 7    5 8    5 #   5 $   5 ,   6 1   E y   E í   5 8    A 8     Ã   5 7    5 8     Ì    %                 K    
    L '     V   L W   E y    |   ? ì    î   5 ñ   E ñ    ≥    µ    =    ˙     <    K   	      Å   ; 8    5     ®   < 8     ı    5    5 8   5 à    > 8      E     H    F b    F c    M q  " 8 8   %     % 5   %  ß  & 9 8   ( : 8   )  °  ) = ¢  ) > ¢  ) C ’  -  L  .  ö  .  À  .  —  /    1 5 8   1  >  2  @  2  F  3  0  3  J  4 B 8   4 D 8   4    4 H .  4 # 9  4   X  4  j  4   k  4 I {  4 " ´  4 " ¨  4  √  4  √  5 5 8   5 ( ı   6 5 8   6 ) ı   6 * ı   6 + ı   6 , ı   6 - ı   6 . ı   6  Ã  7 6 1  7 ! S  8  B  8 5 †  9 J &  9 / A  9 C œ  ; > 8   ; $ 9  < 5 8   < H Ô   <  ;  < 0 g  <   π  = @ ∫  ? 5 8   @ 5 8   A F U  A  â  B H Ô   B 0 g  B   π  C H   C  ;  C 1 i  C  ¶  D 5 8   D ! I  D 9 s  E 0 g  G > 8   H 5 8   H 	 N  H C œ  K > 8   K 3 ?  K  @         1       C   l>  e           1       Y       +e  ›d       1   Ñ?  C   |>  Ye            1       H       çe             1       ø   ú>  õe  ·d               ø   ¨>  Àe  Ód  	             ¿   Ã>  Òe  ˘d  
      1   å?  ƒ   Ï>  f            1   å?  ƒ   Ï>  )f            1   î?  ƒ   ¸>  7f            1       ƒ       Jf  e        1       ≈   ?  }f  e        1       ≈   ?  ùf         Pd  Wd     bd     kd     td  {d     Üd     èd  ñd     èd  ñd  †d     ±d  ∏d     √d     Ãd       [     pv   ÒÿY        [     pv  [# n  2  T [! T  [! T [! R Y!        3[     T          8[     R          =[     T          B[     T          G[     T        L[  h  n  
9  b5 "	6 pã 	 
 n ê © 	n
  
n ê © 	ní 	 	n o ò 9® "6 pã  	æ n ê ò n  	n ê ò 	
 n ê ò ní  "6 pã  	æ n ê ò n  	n ê ò 		 n ê ò ní  n  
n  
	4òd b5 	  *#™Q "6 pã  n  n ê ‹ 2 n ê ‹ ní  M
n
  M
n0m ò
b5 	 *#™Q M
n  M
n0m ò
b5 	 :#™Q M
n  
qt  M
+n  
qt  M
n0m ò
"6 pã  	S n ê ò 8W n ê ¯ ní  " 	p = ò Uà- 8J b5 	+ *#™Q M
b( M
n0m ò
n	  n  	n ∑ ò   #ÄN n j  
¯2Å- ∞b6 	n@p (Úb( q M 8 8 ni  =8 () ˜˛n  (ßb5 	, #™Q M
n0m ò
(Ω8·˛ni  ) ‹˛	) Ÿ˛b( q M 8 8◊ˇni  (“(–8 ni  ') ¡˛(ƒ	(˘ˇ         &    D   
 M    T    ]    ~Jû$Ã⁄$…$ÿ ⁄$‰$Ê        ˆ[  Ü   ' " 6 pã   nw  nq  n ê   ‹n ê   n  
n ë   ) n ê   n  n ê   n å    % n ê   R1 n ç   & n ê   T1 n ê   n å    $ n ê   T1 n ê   n å    ' n ê   T1 n è   ( n ê   T1 n ê   n å    } n å   ní          \     pv         \  2    !A5/ b6 "6 pã  ˜ n ê 2 n ç  4 n ê 2 F n ê 2 ‰ n ê 2 ní  n o ! ÿ  (—      \     pv   ÒÿY   [       $\     ; ⁄∞Ap0 2
ê p0 2 (Ú     ;\  '   ÿH‡ ˇ  µCH’Dˇ ñ# N 5! ÿ⁄∞CHO ÿ(Û"4 p |          [\  $   ÿ H  ’ ˇ ‡  ÿH’ˇ ‡∂ÿH’ˇ ‡∂ÿ H’ˇ ‡ ∂       d\             k\  (   " 6 pã    ⁄ nÉ  
q u C 
n0à !n ê   n ê p  ní    q    !     x\  ¸  "6 pã        p0 
$ ⁄ê      p0 
    !   ÿ¸  5     p0 
    3  ˛ˇ   !      5d     p0 
ÿ     p0 
ÿ     p0 
ÿ     p0 
    3ßÿ     p0 
ÿ     p0 
ÿ$       pT 2 "5 vâ    5     p0 
ÿ     p0 
ÿ     p0 
ÿ     p0 
ÿ     p0 
	ÿ      pX 2ˇˇnÅ  
,ÿ  +„  ˇˇ  2ô       p[ 2
"6 vã   tê    n ê ` 9 tê    n ê †  tê  tí     n ä  ÿ) fˇÿ) Õ˛ò  n   
8≠ˇ  (©‘  n   
8†ˇ (ú“  n   
8ìˇ (è      p[ 2   [ ) ˇ      p[ 2   [ ) kˇ  Y	 ) eˇ"6 vã  ≠tê  qs 	 tê  tí  
) ^ˇ"6 vã  5 tê     n ê     n è  : tê  tí    n ê  "6 vã  5 tê     n ê     n è  : tê  tí     p0  ‡ÿ9(˛zzt  
8˛      3v ÿˇÿ       pT 2"6 vã  6 tê     n ê  : tê  tí    n ê  "6 vã  6 tê     n ê  = tê     n ç  * tê    n ç   tê  tí     p0  ‡) û˝    3 ní  ) uˇ"6 vã   tê  ws  tê   tê     n ç  tí  w  (“  F4ÂœÂ)Éﬂ)N   h   [         r   Ü   ö        Ÿ]     p        ·]  Z   " p   "G p ± ß [G TG B n ∂ á F 9 (˛TG n ∑ ' nh  
#vN n j c 
 " p  n  e TW [G  TW [G RW YG 8ÿˇni  (”(—8œˇni  ( (»8 ni  '(˛        $  B     K     T     J$FJHQ$O$X        7^  	   T  ln ∂            <^      öS         A^      @         F^  &   T  8 " T  8   T! n   
 8  T  8  R  öS4
 n#   8    (˛     K^     p        S^  f   " p   "K p µ ¶ [6 T6 n ∂ v 9  (˛T6 n ∑  "D p≠  n Ø $ ∏ n Æ d Ë   n0Ö v[6 π n Æ d 8 qr  
Y6 8–ˇni  (À(… ÚÿY6 (Û 8¡ˇni  (º(∫8 ni  '(˛        #  @     H     Q     W     `     J$L~0NJT]JT]$[$d      Ø^  	   T " ¯ n ∂            ¥^      »K         π^      ›         æ^     T # 8  T " 8  T ! 8  R   »K4
 n)   8    (˛     √^     pv         »^     ne  
 8  nb   Í n Ñ  
 8    (˛     –^     pv         ÷^     ne  
 8  nb   Î n Ñ  
 8    (˛     ﬁ^     pv         ‰^  X   r  
	r  

ë 	
8   r  r  È n Ñ s 
	8	6 n Ñ t 
	8	0 	 n0Ü s		
 n0Ü t

n  © 
8 8 	 n0Ü s		qr 	 
	 n0Ü t		qr 	 
ëÄ(º(“n ~ C 
(¯     G_  	     n02 !
          O_  	     nq    i (         T_     pv         Y_  Å  b5  to  "  0   p a  "
 v-    n f  	" v/    n f  
"< pú  !ê       5$ F	" nc    p !  n&  
8 n ù % ÿ(‚b(   q M p (ı!†       5( F
"	 nc     p '  t,  
8   n ù  ÿ(ﬁb(   q M p (ı" v1    q °  nü  x§  
8k x•   r  "    p a – wQ  /   n Ç  
ÿ  n á  b5     # Q           n0à M r  M r  
wt  M Mtm  (ù- b(   q M p (Æ    # Q     n†  
wt  MwÄ  b5   n o 0 n†  
=N n†  
ÿˇ:( n†  
ÿˇ  n û       r   
9
   w9  ÿˇ(ﬂ   2˘ˇ   # R     > M < M ; Mw;   b5  to  (€  8     e     ®   
  $O$Ä$˚     `    	öSòqV  qT  9
 b5  n o e  q X   
r@U Sv 8 · " nS   p ! Q r  
4Ös b5 "6 pã  " n ê v r  n ê v ‰ n ê v ní  n o e b5 "6 pã  ! n ê v r  
n ç v Ê n ê v n ç Ü ní  n o e r  
8u Û r  Q 
9f q9 	 (äb5  n o e b( q M % ) |ˇb( q M % ) tˇb5 "6 pã   n ê v r  n ê v ‰ n ê v ní  n o e b5 "6 pã   n ê v r  
n ç v Â n ê v n ç Ü ní  n o e (è2§)ˇq9 
 ) $ˇr  9ˇb5  n o e ) ˇb5  n o e ) ˇ     
  %   	  é$ù         x`  _   c4 8\ " ? p¢   q W   "; Ÿp ö A b5 "6 pã   n ê e n õ  n ê e ‰ n ê e ní  n o T b5 "6 pã   n ê e n0é %‰ n ê e ní  n o T b5 " p<  n n T         ó`  X   c4 8R q W   " ? p¢   b5 "6 pã   n ê e n0é %‰ n ê e ní  n o T "; Ÿp ö A b5 "6 pã   n ê e n õ  n ê e ‰ n ê e ní  n o T qì       æ`     q 8   q 7   q 6   q9    nñ   q9  (¯q9  '            8       ÿ`  2   !s9  F. * n0Ö CnÉ  
q C   
q u C 
n0à bb5 n o #  !s50ﬁˇb5 F n o C ÿ  (Ù     ˝`      p =         a  v  pv  q {   #ôR 
1 M	
n z ò 93 P Y»,  Y». Õb	2 n  ò 
9 2b	2 n  ò 
9 R», 	F 4ò \»-  q A   q M ( (–(Û" "& nx  	p k ò p Y Ü " "( ny  	p l ò p \ á  P  *n ] á n`  n_  n[  +n ] á n`  n_  n[  8 nZ  8 n^  qr  
 qr  
Y¿, Y√. Õb	2 n  ò 
9 2b	2 n  ò 
9 R», 	F 4ò \»- 8Åˇc4 8}ˇb5 n n » ) vˇ(q A   q M ( 8 nZ  8 n^  qr  
 qr  
Y¿, Y√. Õb	2 n  ò 
9 2b	2 n  ò 
9 R», 	F 4ò \»- 87ˇc4 83ˇb5 n n » ) ,ˇ(â8 nZ  8 n^  qr  
 qr  
Y¿, Y√. Õb
2 n  ® 
9 2b
2 n  ® 
9 R», 
F 4® \»- 8 c4 8 b5 n n » '	(Ò) 5ˇ) 7ˇ) 8ˇ) 9ˇ) sˇ) uˇ) vˇ) wˇ(´(Æ(∞(≤     i     â     é     ë     ï          
 ”     ÿ    ! €    % ﬂ    )    -    1    5 #   9 $<$…ì ì$÷$Ÿ0‹0ﬂ$‚$Â0Ë0Î$Ó$0Ú0Ù        õa  4   " 6 pã   # n ê   R!, n ç   Á n ê   R!. n ç   Á n ê   U!- n ë   ‰ n ê   ní           °a  Ø    nq  i3 Õ¡ qî  n  ! 
j1 Õ√ qî  n  ! 
j4 ¬ qî  i2 "@ p£  i0 "@ p£  i/ b0 G r0¨ !b0 |∫ r0¨ !b0 ≥… r0¨ !b0 ¥  r0¨ !b0 µÀ r0¨ !b0 ∂Ã r0¨ !b0 ∑Õ r0¨ !b0 r´  r∞  r§  
8' r•    4 b/ "6 pã  n ê  n ê C ní  b0 r ™  r0¨ 2(÷        ƒa     pv           …a     b 3         Œa  @   
 !t⁄#@O !t5B1 H›· H’D ·⁄ÿ 5a ÿ0éDP ⁄ÿ5c ÿ0éDP ÿ(Ÿÿˆÿa(Îÿˆÿa(Ò"4 p }        ˘a      qD   
       ˇa     "  p =  R ,       b      G q I      
     b  0   ˇ qG 	 A#N  §¿dÑAçO  §¿dÑDçDO ! §¿dÑDçDO 1§¿dÑDçDO  
    'b  P   "H p≤    #`N "" p g ï n j  
ˆ2a n@¥ (ıTnd 	 
8 n≥  8 ni  8 ni  n≥  T(ı'8 ni  ''(Ô(Á(¯T(T(Ù(Œ
             	  )     /    	 8     <     A     ~#$KH 9$B$D$F~#N$@9
   	 ∑b  Y   qò 	   #`N "" p g Ö n j  
ˆ2a" n@ô (ıTnd  
8 nó  8 ni  b3 q M 6 #vN (˜8 ni  nó  (Ì'8 ni  ''((ﬂ(¯T(T(Ù(∆                    	 
 *     9     A    
 E     J    
 ~#$TQ:. B$K$M$O~#W$IB      ]c  	   q J !  qB            gc      G n    
 8  qF    q H !  (˚     sc  /   !0=  b 0 Fr ©  
 8  qN  
 qì   q O   qì    b / Fr ©  
 8 ˇqN  
 qì   (Á       Éc      ∫ q I           ãc  S   nw  nq  nï   b5 "6 pã   n ê C n ê c 3 n ê C 8  "6 pã  n ê   n ê T n ê  ní  n ê  ní  n o 2 c4 9 c1 8 nñ         ßc  ü   
!Î=( b0 F
r © À 
8 b0 F
r ™ À   4 "< pú  !Î5µ' Fr ¶ ∏ ÿ(ˆ!Î= b/ F
r © À 
8 b/ F
r ™ À   4 (◊q O   	r®  
9 qP  (ˆ	G n  	 
rß  r§  
	8	= r•  4 "  p a s q I  b6 8 n o L (‰b	3 q M ) (›"	6 pã 	 n ê I 8 	 n ê ù 	n ê y 	ní 	 (‹	 (Ò©(©  m     Ä     $y      %d     b 5 ” n o        +d  9   !A=4 F b0 r ©  
9
 b/ r ©  
8! b5 "6 pã  “ n ê 2 n ê   n ê 2 ní  n o !  q O   (¸       @d      … q I           Hd      À q I                    ¸                                                  !     "                    '     (                    ,              <              H     	       /   P  0   P  E     F     G     H     I     J     L     Q     R              !      >                1 1    4      M      N      N     R             4              I      4 Q    ,            1        4    4 4    ?      N                     4    %      '      *      +      4 8    B >    N        O        -                                                %s %-8s %5d  %s
 7  MAGISK FALLBACK FILES (APK or ZIP in Download folder)   Unrecognized tag code '  :  FILE [FILE...]  version code:  version name: !  "! Can't connect to package manager 6! Can't get application info of 'com.topjohnwu.magisk' ! Invalid Magisk file:  M! Magisk APK (21402+) or Magisk ZIP (19400+) is not found in /sdcard/Download @! Magisk app does not contain 'lib/armeabi-v7a/libmagiskboot.so' '! Magisk app is not installed or hidden ! Magisk app version code:   [ ! Magisk app version name:   [ " $1$3 $2 %8d FILE(S) ' at offset  ) * %-26s [%d] >= %d
 * %-26s [%s]
 * DEX finish:                [ * DEX start:                 [ * DEX thread time on finish: [ * DEX thread time on start:  [ * Magisk %-19s [%s]
 * Magisk app version code:   [ * Magisk app version name:   [ * Terminal size:             [ , mPackageName=' , mVersionCode= , mVersionName=' , mZip= , mZipPath=' , type=' - - %-47s (%s >)
 - %s
 (---------------------------------------- . / /sdcard/Download /system/bin/sh : :  : [ < </ <clinit> <init> =" > N> (Canary) https://github.com/topjohnwu/magisk-files/blob/canary/app-debug.apk 7> (Public) https://github.com/topjohnwu/Magisk/releases > (line  4> Download Magisk APK in Chrome Mobile and try again >; APK APP_PACKAGE_NAME AndroidManifest.xml BaseMagiskBootContainer.java C CMD_ALGS_B_MAP CMD_ALGS_MAP CRC32 CmdLineArgs.java DEBUG DEFALT_VERSIONCODE DEFAULT_COLUMNS DEFAULT_LINES DOWNLOAD_FOLDER_PATH END_DOC_TAG END_TAG ENTRY_ANDROIDMANIFEST_XML ENTRY_MAGISKBOOT ENTRY_UTIL_FUNCTIONS_SH "Extracting magiskboot from Magisk  I III IL ILI ILL IMagiskBootContainer.java IZ Info J JL KEY_VERSIONCODE KEY_VERSIONNAME L LBaseMagiskBootContainer$Info; LBaseMagiskBootContainer; LC LCmdLineArgs; LI LII LIMagiskBootContainer; LJ LL LLI LLII LLIII LLL LMagiskApk$Parser; LMagiskApk; LMagiskZip; LParasiteEmb$1; LParasiteEmb$2; LParasiteEmb$3; LParasiteEmb; LParasiteUtils$TerminalSize; LParasiteUtils; LZ $Landroid/content/pm/ApplicationInfo; )Landroid/content/pm/IPackageManager$Stub; $Landroid/content/pm/IPackageManager; Landroid/os/IBinder; Landroid/os/RemoteException; Landroid/os/ServiceManager; Landroid/os/SystemClock; Landroid/os/UserHandle; "Ldalvik/annotation/EnclosingClass; #Ldalvik/annotation/EnclosingMethod; Ldalvik/annotation/InnerClass; !Ldalvik/annotation/MemberClasses; Ldalvik/annotation/Signature; Ldalvik/annotation/Throws; Ljava/io/BufferedReader; Ljava/io/BufferedWriter; Ljava/io/File; Ljava/io/FileFilter; Ljava/io/FileInputStream; Ljava/io/FileNotFoundException; Ljava/io/IOException; Ljava/io/InputStream; Ljava/io/InputStreamReader; Ljava/io/OutputStream; Ljava/io/OutputStreamWriter; Ljava/io/PrintStream; Ljava/io/Reader; Ljava/io/Writer; Ljava/lang/CharSequence; Ljava/lang/Class; Ljava/lang/Integer; Ljava/lang/Math; !Ljava/lang/NumberFormatException; Ljava/lang/Object; Ljava/lang/Process; Ljava/lang/Runtime; Ljava/lang/String; Ljava/lang/StringBuffer; Ljava/lang/StringBuilder; Ljava/lang/System; Ljava/lang/Throwable; Ljava/security/MessageDigest; (Ljava/security/NoSuchAlgorithmException; Ljava/text/SimpleDateFormat; Ljava/util/ArrayList; -Ljava/util/ArrayList<LIMagiskBootContainer;>; Ljava/util/Collections; Ljava/util/Comparator Ljava/util/Comparator; Ljava/util/Date; Ljava/util/HashMap; Ljava/util/Iterator; Ljava/util/List; $Ljava/util/List<Ljava/lang/String;>; Ljava/util/Map Ljava/util/Map; Ljava/util/Properties; Ljava/util/Set; Ljava/util/jar/JarEntry; Ljava/util/jar/JarFile; Ljava/util/zip/CRC32; Ljava/util/zip/ZipEntry; Ljava/util/zip/ZipException; Ljava/util/zip/ZipFile; 
MAGISK_VER MAGISK_VER_CODE MD5 MIN_COLUMNS_OF_DETAIL MIN_VERSIONCODE MORE Magisk  MagiskApk.java MagiskZip.java PARASITE_DEBUG PARASITE_MORE PARASITE_VERBOSE ParasiteEmb.java ParasiteUtils.java Parser REGEX_APK_FILENAME REGEX_ZIP_FILENAME SHA-1 SHA-224 SHA-256 SHA-384 SHA-512 	START_TAG TAG TYPE TerminalSize Usage: ParasiteUtils  %Usage: ParasiteUtils COMMAND [ARG...] V VERBOSE VI VIL VL VLII VLL VZ Z ZIP ZL [B [C [Ljava/io/File; [Ljava/lang/Object; [Ljava/lang/String; ] ] <  ] >=  ] [ ^"|"$ ^(.*) \(([0-9]+)\)(.[^.]+)?$ #^(Magisk-.*\.apk|app-debug.*\.apk)$ <^(Magisk-.*\.zip|magisk-debug.*\.zip|magisk-release.*\.zip)$ accept 
access$000 accessFlags add alg 	algorithm apk app appInfo append args args  arm/magiskboot arr asInterface 	attrFlags attrName attrNameNsSi 
attrNameSi 	attrResId 	attrValue attrValueSi 	available b br brief buffer bytes bytesToHexString chars checkZipPath close cmd cnt columns 
columnsInt 
columnsStr com.topjohnwu.magisk common/util_functions.sh compXmlString compXmlStringAt compare 	compareTo 	container 
containers containsKey count countWritten crc32 
crc32Bytes 	crc32Long currentThreadTimeMillis date decompressXML detail detectApkOrZip 	detectApp dig digest digestBytes dir e echo $COLUMNS echo $LINES enter entry equals err exec exit false file filesApk filesZip finalXML first flush format 	formatter get getApplicationInfo getBaseCodePath getClass getEntry getInputStream getInstance getLocalizedMessage getMagiskBootEntry getMinVersionCode getName getOutputStream getPackageName getPath getProperty 
getRuntime 
getService getSimpleName getType getValue getVersionCode getVersionName getZip 
getZipPath getenv h hasNext hash 	hashBytes hashCode hexChars hi i ii in indent info intFromByteArray isCrc32 isDirectory isFile isNnumSuffix isSameExceptSuffix isValid iterator k keySet lastIndexOf length  lib/armeabi-v7a/libmagiskboot.so lineNo lines linesInt linesStr 	listFiles lo load mPackageName mVersionCode mVersionName mZip mZipPath main manifest matches md5 message messages min msg myUserId name name1 name2 nameNsSi nameSi newLen newLine next num1 num2 	numbAttrs numbStrings o1 o2 off out outputAdvice outputE 
outputHash outputMagiskBoot outputUsage p package packageName parseInt path pathname paths pm print printStackTrace printf println process prt 	prtIndent put read readLine reader regex 
replaceAll replaceFirst resourceID 0x ret s sb second sep sha1 sha224 sha256 sha384 sha512 sitOff size sort spaces stOff startTagLineNo status str strInd strLen strOff 	substring tag tag0 tag6 this 
threadTime title1 title2 toHexString toString true type update value valueOf versionCode versionCodeString versionName write writer xml 	xmlTagOff yyyy-MM-dd HH:mm:ss.SSS zip zipPath 	{isValid=  ? ‹<-K ‡KKKK %  +  (    "  2œi*Y- 5À5•+#áÅ5•ﬁ&ú√L áOõ<z ™K].?cY]‡ #.{Ü ™%[.f==7™K c ,·^   ˜ ‹<*> J B£J ÓÿπΩ¡-ñ √ ˛˙√ˇ¬- äO›-î> X˙ë U¿ ˜ﬂ¿' `ÿ\∑7√é-πMΩƒŸ›¥&,-ëﬂ-æ¥¶∆ƒÓ√Üƒáñ√«≈ç-‚É5/Z±6Z¶˛ƒˇ≈Ç√¸≈	Ä.ƒ˝5¬
Å5_.AJ	
œ J	'lµ‰	*,/√,mñ--·"@üzhU) ‹< ‹[‡Ä•ÆG,_"™K%ﬁ&iiÿOL ÖZò<KKRyÜ $i <  B  ?  F  ‹< ‹[‡ÄáÆJ,Z" ™K% ﬁ&iZòE=ˇi‘5.htÜ ™1] $ ™K i E  L  I  P    Çù Ö  àù ®  ¨èê• ∏, r KÑ5KÖ5-´5“ÂNááÊN≤K•ã•å!u5 ®       | yñ©!π	µQ∫
∂QZô=¶”¥!¥Û	i7A™%â”“€
iUAê§ˇòKú5¥5πˇÉ5√á›zJ-Üé5wi‹-‚áØ-{YAhw > J•ü-8wNº ı0ûòi"“CiiØ-^J ™xw ™%w"“R-^iö ( KZ °@K…xª<"¶ 3øKK…Z °@xª<" < ˜=<?={ ™9= K ïˇ;w•≥5√àLZ ‹<v { K ~†<§3-KK$V™%ã0·™·◊ ë5Ò5- ê.Z<<KZ<<NZ\KK--itu,yZ\KK--itx,x\KK--i[{x,<><{;<><{;-/- ∞   á··àxyñññññññ
 È5
 -      àà,Z ⁄P‹<iÛi€¥Ø>Z[ ∂  ∫† ó¥ Ù¥;K—> àOñ••á ›¥ZùIL áOﬁ&Zﬁ&õ<[-™$iP[[z!i™%™${ ø¥Ú¶:PL áOﬁ&Zﬁ&õ<[-™$iP[ i™;Z; [zY™$!i™%™${ ì¥Ú Ä¥ÚáL (˜<•|<Kz• õ¥ i≈™á∞5K ˛50¥á= E˜,“• Ò5&ÑNZûCÆ‹<Xw; “•  ;o iNk‚Nˇú5[¥!K’5K™%f" ? x 4˜<< ç5ˇ  ü¥ £¥ –ÓÇ[––$–ÓÇ∆––6ÓÇ–ôß5g?–Ó	Ç—––Æ5úú?$ÒÿDDDB7l$öS@¯7π∏$»K›70ÍÎPF        ÄÄÿ,  
	Å Å Å Å Å Å Å Å Å Å  ÅÄ¯,Ñ º-‘-Ï-Ñ.ú.¥.Ï4   ÅÄà7	†7
ÄÄî8º88–9®:º:ú; !ÅÄ§G"ºGºI‡I¯IêJ 'ÅÄÏJ(ÑK∞M‘MÏMÑN  -ÄÄÃN.‰N  /ÄÄ†O0∏O  1ÄÄÙO2åP¡ ÃQ  $4àÄQÅÄîR
¨R
‰X	¨]	¸^	º`âúa),<ÄÄêbÅÄ¨b>‡i  /?àÄÿjÅÄ»mà ‡m	¯m	ào	§o	ƒo
‰o
‘p
‹r	Ñu	®u	‹u	Ãv	Ïv
§x
à{
®{	¨|	Ã|                   ›  p      S   ‰     N   0	     7   ÿ     ∏   ê        P    
        D   X     	   l>    "   Ñ?     ›  û@     D   [        Pd        ›d         e        g  