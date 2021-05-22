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
DEX_EXPECTED_CRC32="b007f47b"
DEX_EXPECTED_MD5="9dd04e7533f6087cfef09fa89685e114"
DEX_EXPECTED_SHA1="00b0cc1ad3ea2b614dd14aac9b02db4570229f6f"
DEX_EXPECTED_SHA256="6d2d59abed2d2d472ead09553c153de97f64dc19be4b450d324897b1cb4e309a"

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
  [ -f classes.dex ] || tail -n +513 "$SCRIPT" > classes.dex
  
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
035 mÆV◊Ü©gH·˝x—·÷o‚kP÷Ì¿d  p   xV4        c  –  p   R   ∞  M   ¯  4   î  ∞   4     ¥  åO  4  v>  x>  {>  >  Æ>  ¬>  ˚>  ?  ?  +?  /?  S?  ã?  §?  Û?  5@  ^@  ~@  û@  °@  ß@  ´@  ∏@  ∆@  …@  È@  	A  )A  IA  _A  A  üA  øA  —A  ‚A  ÙA  ˝A  B  B  B  )B  0B  ZB  ]B  `B  rB  ÇB  ÖB  âB  éB  ëB  ïB  üB  ßB  ´B  ÆB  ˛B  7C  AC  wC  {C  ÄC  íC  ßC  ¿C  √C  ”C  ·C  ËC  ˙C  D  D  &D  5D  KD  XD  aD  |D  éD  ßD  ÀD  ŒD  ”D  ◊D  ‹D  ·D  ˜D  ˚D  ˛D  E  E  $E  'E  +E  :E  >E  CE  GE  KE  PE  VE  ]E  bE  vE  ÉE  êE  °E  ≤E  √E  ÍE  F  F  ;F  LF  PF  vF  °F  «F  ›F  ˚F  G  2G  KG  oG  îG  ¥G  ◊G  ˆG  H  ,H  FH  VH  lH  áH  ®H  øH  ÷H  ÛH  I  )I  @I  RI  dI  ~I  ëI  ¶I  ∏I  €I  ÔI  J  J  -J  GJ  bJ  vJ  çJ  ¨J  ÷J  ÙJ  K  FK  _K  vK  éK  †K  µK  ÀK  ›K  L  L  $L  <L  ML  gL  ÄL  óL  ±L  œL  ËL  ÙL  M  
M  !M  2M  8M  HM  XM  hM  wM  âM  õM  ØM  ∑M  ÀM  ﬂM  ÊM  ÔM  ¯M  N  
N  N  N   N  .N  EN  lN  oN  xN  |N  ÅN  ÖN  ãN  êN  îN  óN  úN  †N  §N  ®N  πN  ŒN  „N  ÊN  ÏN  ÛN  ¯N  ˇN  O  BO  ÄO  àO  îO  °O  ¶O  ´O  ∂O  ªO  ¿O  …O  —O  ◊O  ﬁO  ÓO  ÛO   P  P  P  #P  /P  :P  EP  RP  ]P  `P  dP  kP  sP  zP  åP  ìP  öP  üP  §P  ≠P  πP  ≈P  €P  ıP  Q  Q  Q  )Q  4Q  @Q  MQ  TQ  bQ  iQ  uQ  ÄQ  ôQ  üQ  ÆQ  ∂Q  ∆Q  —Q  ÷Q  ﬁQ  ÎQ  Q  ÛQ  R  R  R  R  %R  *R  0R  6R  =R  CR  MR  WR  aR  hR  oR  wR  ÇR  áR  õR  ¨R  ∂R  ¿R  –R  ›R  ÚR  S  S   S  0S  9S  FS  RS  ^S  mS  vS  ÄS  êS  †S  ®S  ¥S  ºS  øS  »S  ŒS  ŸS  „S  ÌS  ÒS  ÙS  ¯S  ¸S  T  T  T  ,T  4T  BT  VT  _T  iT  lT  tT  ÅT  âT  ´T  ≥T  ∫T  ƒT  ŒT  ŸT  ›T  „T  ÒT  ˇT  U  U  U  #U  -U  6U  ;U  DU  NU  SU  XU  bU  hU  oU  vU  ÄU  àU  êU  ôU  üU  •U  ´U  ∂U  √U  «U  ÀU  –U  ’U  „U  ÏU  ¯U  
V  V  V  #V  0V  :V  @V  JV  QV  UV  \V  dV  mV  vV  {V  ÜV  ãV  ëV  õV  £V  ™V  ∂V  ƒV  ”V  ÿV  €V  ﬂV  ÁV  ÏV  ÚV  ˙V  W  
W  W  W   W  &W  .W  5W  EW  MW  RW  ZW  bW  jW  uW  zW  ÄW  ÜW  åW  òW  •W  ØW  µW  ªW  √W   W  ”W  ‡W  ÛW   X  X  X  X  X  8X  =X  FX  @   P   W   ]   f   g   h   i   j   k   l   m   n   o   p   r   s   t   u   v   w   x   y   z   {   |   }   ~      Ä   Å   Ç   É   Ñ   Ö   Ü   á   à   â   ä   ã   å   ç   é   è   ê   ë   í   ì   î   ï   ñ   ó   ò   ô   ö   õ   ú   ù   û   †   ¢   £   §   •   ¶   ©   ™   ´   ¨   ≠   Æ   Ø   ∞   ±   Õ   ’   ÿ   Ÿ   ⁄   €   ‹   P          Q      t=  T      |=  T      Ñ=  R      å=  V      î=  R      ú=  S      §=  R      ¨=  W          X      ¥=  c      º=  a      »=  a      å=  [   $       a   $   –=  [   &       e   (   ÿ=  a   *   ‡=  [   ,       ^   -   Ë=  [   0       ^   0   Ë=  a   0   =  e   0   Ñ=  a   1   ¨=  [   2       [   3       ^   3   Ë=  _   3   t=  a   3   ¥=  e   3   ¯=  a   3   å=  e   3    >  e   3   ÿ=  a   3   >  a   3   ú=  b   3   §=  d   3   >  a   4   å=  \   5   >  ^   5   Ë=  `   5   $>  a   5   =  a   5   å=  q   5   î=  a   8   å=  [   @       [   D       [   H       a   H   å=  [   J       Õ   K       œ   K   Ë=  –   K   ,>  —   K   ¥=  —   K   4>  —   K   <>  —   K   D>  —   K   L>  —   K   =  —   K   å=  ”   K   T>  ”   K   \>  ‘   K   î=  —   K   ú=  “   K   d>  —   K   p>  —   K   ¨=  ’   L       ◊   L   ¥=  ◊   L   =  ◊   L   å=  [   M       a   M   ¥=  e   M   ¯=  a   O   d=    J     K     «    3 è   3 ∞    ≈   3 «   3 L    3 M     ∂    3 …    3 j    k   3 l   J m   3 n   3 M    3 N    3 Y    3 Z     ∂    3 …    3 j    k   3 l   J m   3 n  
 3 j  
  k  
 3 l  
 J m  
 3 n    F    3 =    3 I    3 ¿    3 ¡    3 »     G     H     µ        L     d   B A    B B    L E    3 ∑    3 »    L Œ   6 ( '  6 ( á   4 4    D o   4 4    &    %    $     V   = ô   6 ö   = 4    1 ;    D   E \   = 4    1 ;    D   E \   4 4    F Â    4 4    F Â   	 4 4   	    	    
 = 4   
 1 ;  
  >  
  D  
   F  
  G  
 3 H  
  I  
 E \  
  ã  
  ø   1 ;    >    D     F    G   3 H    I   E \    ã   4 3    4 4     Ê    4    4    4 $   5 )   D o   D à   4 4    @ 4     ø   4 3    4 4     Ê    $                 J    
    K     M   K N   D o    r   > â    ä   4 å   D å    ®    ™    5    Û     4    B   	      w   : 4    4     ù   ; 4     Ó    4    4 0   4 ~   = 4     <    ?   E X   E Y   L g  ! 7 4   $   ˚   $ 4   $  ú  % 8 4   ' 9 4   (  ñ  ( < ó  ( = ó  ( B »  ,  C  -  ê  -  æ  -  ƒ  .  u  0 4 4   0  6  1  8  1  =  2  (  2  A  3 A 4   3 C 4   3    3 G &  3 " 1  3   O  3  `  3   a  3 H q  3 ! †  3 ! °  3  ∏  3  ∏  4 4 4   4 ' Ó   5 4 4   5 ( Ó   5 ) Ó   5 * Ó   5 + Ó   5 , Ó   5 - Ó   5  ø  6 5 )  6   J  7  :  8 I   8 . 9  8 B ¬  : = 4   : # 1  ; 4 4   ; G Ë   ;  3  ; / ]  ;   Æ  < ? Ø  > 4 4   ? 4 4   @ E L  @    A G Ë   A / ]  A   Æ  B G   B  3  B 0 _  B  õ  C 4 4   C   @  C 8 i  D / ]  F = 4   G 4 4   G 	 E  G B ¬  J = 4   J 2 7  J  8        0       D       *b             0       ∏   T<  8b  Óa       0       Ω   d<  hb  ˚a  
     0   \=  Ω   t<  íb            
       ∏   Ñ<  ¬b  ˇa        
       π   ú<  ‡b  
b        0   d=  Ω   ¥<  c            0   d=  Ω   ¥<  c      	      0   l=  Ω   ƒ<  c            0       Ω   ‘<  1c  b         0       æ   ‰<  ic  #b        0       æ   Ù<  âc         Ra  Ya     da  ka     da  wa     Éa     åa     ïa  úa     ïa  úa  ¶a     ∑a     ¬a  …a     ‘a     ›a       QX     po         VX  2    !A5/ b3 "5 pÑ   n â 2 n Ü  0 n â 2 F n â 2 › n â 2 nã  n h ! ÿ  (—      iX     po    ÄY   [       sX     ; ⁄∞Ap0 2
ê p0 2 (Ú     äX  '   ÿH‡ ˇ  µCH’Dˇ ñ# M 5! ÿ⁄∞CHO ÿ(Û"3 p u          ™X  $   ÿ H  ’ ˇ ‡  ÿH’ˇ ‡∂ÿH’ˇ ‡∂ÿ H’ˇ ‡ ∂       ≥X             ∫X  (   " 5 pÑ    ⁄ n|  
q n C 
n0Å !n â   n â p  nã    q    !     «X  ¸  "5 pÑ        p0 
$ ⁄ê      p0 
    !   ÿ¸  5     p0 
    3  ˛ˇ   !      5d     p0 
ÿ     p0 
ÿ     p0 
ÿ     p0 
    3ßÿ     p0 
ÿ     p0 
ÿ$       pT 2 "4 vÇ    5     p0 
ÿ     p0 
ÿ     p0 
ÿ     p0 
ÿ     p0 
	ÿ      pX 2ˇˇnz  
,ÿ  +„  ˇˇ  2ô       p[ 2
"5 vÑ   tâ    n â ` 5 tâ    n â †  tâ  tã     n É  ÿ) fˇÿ) Õ˛é  n x  
8≠ˇ  (©«  n x  
8†ˇ (ú≈  n x  
8ìˇ (è      p[ 2   [ ) ˇ      p[ 2   [ ) kˇ  Y	 ) eˇ"5 vÑ  ¢tâ  ql 	 tâ  tã  
) ^ˇ"5 vÑ  1 tâ     n â     n à  6 tâ  tã    n â  "5 vÑ  1 tâ     n â     n à  6 tâ  tã     p0 ‡ÿ9(˛pptx  
8˛      3v ÿˇÿ       pT 2"5 vÑ  2 tâ     n â  6 tâ  tã    n â  "5 vÑ  2 tâ     n â  9 tâ     n Ü  & tâ    n Ü   tâ  tã     p0 ‡) û˝    3 nã  ) uˇ"5 vÑ   tâ  wl  tâ   tâ     n Ü  tã  w  (“  F4ÂœÂ)Éﬂ)N   h   [         r   Ü   ö        (Z     po   [        2Z     T          8Z     R          >Z     T          DZ     T          JZ     T        PZ  ∫   &n   
	9	 b2 "5 pÑ  	 n â ò TŸ n â ò nã  n h Ü "	5 pÑ 	 
O n â © 	8S n â È 	nã 	 "	 p 6 â Uô* 8	G b	2 
' #kP Mq .   Mn0f ©TŸ n  
n Ø © 	  #êM n c  
˘2ë, ∞b	3 
n@i 	(Úq .   q F 8 8 nb  =3 g(°n  (´b	2 
( #{P Mn0f ©(¡8 nb  á(âq .   q F 8 8‹ˇnb  (◊(’8 nb  'v(Œ(‰(»(¯U     s     |     ñ     ú     •    	 Æ     ~Ir#õ´#© ´#¥#∂#∏     ·Z  Ü   ' " 5 pÑ   np  nj  n â   œn â   n   
n ä   % n â   n  n â   n Ö    ! n â   R1 n Ü   " n â   T1 n â   n Ö      n â   T1 n â   n Ö    # n â   T1 n à   $ n â   T1 n â   n Ö    } n Ö   nã         ÓZ  s   	Òÿp  ∫ "F p © ∂ [¶ T¶ > n Æ v E 9 [® Y© [®  [® [® Y© [® (ˆT¶ n Ø & na  
#eM n c S 
 " p  n  T TF [¶ RF Y¶ TF [¶ 8–ˇnb  (À(…[¶ ÒÿY¶ [¶ 8Ωˇnb  (∏(∂8 nb  '(˛       +   $  Q     Y   	  d     m     I #UIWj#h j#q      N[  	   T  bn Æ            S[      <         X[  &   T  8 " T  8   	T! n x  
 8  T  8  R  öS4
 n
   8    (˛    ][  z   Òÿp  © [ó "J p ≠ • [ï Tï 
n Æ e 9 [ó Yò   [ó [ó Yò (¯Tï n Ø  "C p•  n ß # ≤ n ¶ S ·   n0~ e[ï ≥ n ¶ S 8 qk  
Yï 8 ˇnb  (≈(√ ÚÿYï (Û [ï ÒÿYï 8¥ˇnb  (Ø(≠8 nb  '(˛     '   #  M     U     ^     c     k     t     I#Y~/[IaqIaq#o q#x        ø[  	   T  Ò n Æ            ƒ[      ÷         …[     T  8  T  8  T  8  R  »K4
 n   8    (˛     Œ[     po         ”[     n^  
 8  n[   „ n }  
 8    (˛     €[     po         ·[     n^  
 8  n[   ‰ n }  
 8    (˛     È[     po         Ô[  X   r&  
	r&  

ë 	
8   r)  r)  ‚ n } s 
	8	6 n } t 
	8	0 	 n0 s		
 n0 t

n x © 
8 8 	 n0 s		qk 	 
	 n0 t		qk 	 
ëÄ(º(“n w C 
(¯     R\  	     n0 !
          Z\  	     nj    i %         _\     po           d\     b %         i\  ≥  b2  th  " ,   p Z  " v    n _  	" v    n _  
"; pî  !ê       5$ F	" n\    p 	  n  
8 n ï % ÿ(‚b%   q F p (ı!†       5( F
" n\     p   t  
8   n ï  ÿ(ﬁb%   q F p (ı"	 v    q ô  nó  xú  
8k xù   r)  "   p Z – wJ  +   n {  
ÿ  n Ä  b2     # P           n0Å M r'  M r&  
wm  M Mtf  (ù) b%   q F p (Æ    # P     nò  
wm  Mwy  b2   n h 0 nò  
=Ä nò  
ÿˇ:Z nò  
ÿˇ  n ñ   b2     # P     "5 vÑ  r%  tâ  . tâ  tã  M r)  Mtf      r +  
9
   w2  ÿˇ(≠   2˘ˇ   # Q     : M 8 M 7 Mw4   b2  th  (€  8     e     ®   
  #O#Ä#˚     %]    	öSéqO  qM  9
 b2 
 n h e  	q Q   
r@N Sv 8 · " nL   p 	 Q r&  
4Ös b2 "5 pÑ   n â v r'  n â v › n â v nã  n h e b2 "5 pÑ   n â v r&  
n Ü v ﬂ n â v n Ü Ü nã  n h e r*  
8u Ï r + Q 
9f q2 	 (äb% q F % b2  n h e ) |ˇb% q F % ) tˇb2 "5 pÑ   n â v r'  n â v › n â v nã  n h e b2 "5 pÑ   n â v r&  
n Ü v ﬁ n â v n Ü Ü nã  n h e (è2§)ˇq2 
 ) $ˇr#  9ˇb2  n h e ) ˇb2  n h e ) ˇ     
  %   	  é#ù         ã]  _   c1 8\ " > pö   q P   ": Ãp í A b2 "5 pÑ   n â e n ì  n â e › n â e nã  n h T b2 "5 pÑ   n â e n0á %› n â e nã  n h T b2 " p5  n g T         ™]  X   c1 8R q P   " > pö   b2 "5 pÑ   n â e n0á %› n â e nã  n h T ": Ãp í A b2 "5 pÑ   n â e n ì  n â e › n â e nã  n h T qå        —]     q 1   q 0   q /   q2         ‹]  2   !s9  F* & n0~ Cn|  
q <   
q n C 
n0Å bb2 n h #  !s50ﬁˇb2 F n h C ÿ  (Ù     ^      p 6         ^  v  po  q t   #ôQ 
- M	
n s ò 93 P Y»)  Y»+ ¿b	/ n x ò 
9 *b	/ n x ò 
9 R») 	F 4ò \»*  q :   q F ( (–(Û" "% nq  	p d ò p R Ü " "' nr  	p e ò p U á  P  "n V á nY  nX  nT  #n V á nY  nX  nT  8 nS  8 nW  qk  
 qk  
Y¿) Y√+ ¿b	/ n x ò 
9 *b	/ n x ò 
9 R») 	F 4ò \»* 8Åˇc1 8}ˇb2 n g » ) vˇ(q :   q F ( 8 nS  8 nW  qk  
 qk  
Y¿) Y√+ ¿b	/ n x ò 
9 *b	/ n x ò 
9 R») 	F 4ò \»* 87ˇc1 83ˇb2 n g » ) ,ˇ(â8 nS  8 nW  qk  
 qk  
Y¿) Y√+ ¿b
/ n x ® 
9 *b
/ n x ® 
9 R») 
F 4® \»* 8 c1 8 b2 n g » '	(Ò) 5ˇ) 7ˇ) 8ˇ) 9ˇ) sˇ) uˇ) vˇ) wˇ(´(Æ(∞(≤     i     â     é     ë     ï          
 ”     ÿ    ! €    % ﬂ    )    -    1    5 #   9 #<#…ì ì#÷#Ÿ/‹/ﬂ#‚#Â/Ë/Î#Ó#/Ú/Ù        ü^  4   " 5 pÑ    n â   R!) n Ü   ‡ n â   R!+ n Ü   ‡ n â   U!* n ä   › n â   nã           •^  Ø    nj  i0 ¿∫ qç  n x ! 
j. ¿º qç  n x ! 
j1 ª qç  i/ "? põ  i- "? põ  i, b- C r0§ !b- r¥ r0§ !b- ®¬ r0§ !b- ©√ r0§ !b- ™ƒ r0§ !b- ´≈ r0§ !b- ¨∆ r0§ !b- r£  r®  rú  
8' rù    3 b, "5 pÑ  n â  ˛ n â C nã  b- r ¢  r0§ 2(÷        »^     po           Õ^     b 0         “^  @   
 !t⁄#@N !t5B1 H›· H’D ·⁄ÿ 5a ÿ0éDP ⁄ÿ5c ÿ0éDP ÿ(Ÿÿˆÿa(Îÿˆÿa(Ò"3 p v        ˝^      q=   
       _     "  p 6  R )       _      C q B      
     _  0   ˇ q@ 	 A#M  §¿dÑAçO  §¿dÑDçDO ! §¿dÑDçDO 1§¿dÑDçDO  
    +_  P   "G p™    #`M "! p ` ï n c  
ˆ2a n@¨ (ıTn] 	 
8 n´  8 nb  8 nb  n´  T(ı'8 nb  ''(Ô(Á(¯T(T(Ù(Œ
             	  )     /    	 8     <     A     ~"#KH 9#B#D#F~"N#@9
   	 ª_  Y   qê 	   #`M "! p ` Ö n c  
ˆ2a" n@ë (ıTn]  
8 nè  8 nb  b0 q F 6 #vM (˜8 nb  nè  (Ì'8 nb  ''((ﬂ(¯T(T(Ù(∆                    	 
 *     9     A    
 E     J    
 ~"#TQ9. B#K#M#O~"W#IB      a`  	   q C !  q;            k`      C n x   
 8  q?    q A !  (˚     w`  /   !0=  b - Fr °  
 8  qG  
 qå   q H   qå    b , Fr °  
 8 ˇqG  
 qå   (Á       á`      ¥ q B           è`  H   np  nj  né   b2 "5 pÑ  	 n â C n â c / n â C 8  "5 pÑ  n â   n â T n â  nã  n â  nã  n h 2      ©`  ü   
!Î=( b- F
r ° À 
8 b- F
r ¢ À   3 "; pî  !Î5µ' Fr û ∏ ÿ(ˆ!Î= b, F
r ° À 
8 b, F
r ¢ À   3 (◊q H   	r†  
9 qI  (ˆ	C n x 	 
rü  rú  
	8	= rù  3 " p Z s q B  b3 8 n h L (‰b	0 q F ) (›"	5 pÑ 	 n â I 8 	 n â ù 	n â y 	nã 	 (‹	 (Ò©(©  m     Ä     #y      'a     b 2 Ã n h        -a  9   !A=4 F b- r °  
9
 b, r °  
8! b2 "5 pÑ  À n â 2 n â   n â 2 nã  n h !  q H   (¸       Ba      ¬ q B           Ja      ƒ q B      4              @              L              X             	   `                    `  h              t              Ñ              å              ò     	       ,   †  -   †  >   `  ?   `  @   `  A   `  B   `  C   `  E   `  J   `  K   `                  =                0 0    3      L      M      M     Q            3              H      3 P    +            0       3    3 3    >      M                     3    $      &      )      *      3 7    A =    M        N        -                                                %s %-8s %5d  %s
 7  MAGISK FALLBACK FILES (APK or ZIP in Download folder)   Unrecognized tag code '  :  FILE [FILE...] !  "! Can't connect to package manager 6! Can't get application info of 'com.topjohnwu.magisk' ! Invalid Magisk file:  M! Magisk APK (21402+) or Magisk ZIP (19400+) is not found in /sdcard/Download @! Magisk app does not contain 'lib/armeabi-v7a/libmagiskboot.so' '! Magisk app is not installed or hidden ! Magisk app version code:   [ ! Magisk app version name:   [ " $1$3 $2 %8d FILE(S) ' at offset  ) * DEX finish:                [ * DEX start:                 [ * DEX thread time on finish: [ * DEX thread time on start:  [ * Magisk %-19s [%s]
 * Magisk app version code:   [ * Magisk app version name:   [ * Terminal size:             [ , mPackageName=' , mVersionCode= , mVersionName=' , mZip= , mZipPath=' , type=' - - %-47s (%s >)
 - %s
 (---------------------------------------- . / /sdcard/Download /system/bin/sh : :  : [ < </ <clinit> <init> =" > N> (Canary) https://github.com/topjohnwu/magisk-files/blob/canary/app-debug.apk 7> (Public) https://github.com/topjohnwu/Magisk/releases > (line  4> Download Magisk APK in Chrome Mobile and try again >; APK APP_PACKAGE_NAME AndroidManifest.xml BaseMagiskBootContainer C CMD_ALGS_B_MAP CMD_ALGS_MAP CRC32 CmdLineArgs.java DEBUG DEFALT_VERSIONCODE DEFAULT_COLUMNS DEFAULT_LINES DOWNLOAD_FOLDER_PATH END_DOC_TAG END_TAG ENTRY_ANDROIDMANIFEST_XML ENTRY_MAGISKBOOT ENTRY_UTIL_FUNCTIONS_SH "Extracting magiskboot from Magisk  I III IL ILI ILL IMagiskBootContainer IZ J JL KEY_VERSIONCODE KEY_VERSIONNAME L LC LCmdLineArgs; LI LII LJ LL LLI LLII LLIII LLL LMagiskApk$Parser; LMagiskApk; LMagiskZip; LParasiteEmb$1; LParasiteEmb$2; LParasiteEmb$3; %LParasiteEmb$BaseMagiskBootContainer; "LParasiteEmb$IMagiskBootContainer; LParasiteEmb; LParasiteUtils$TerminalSize; LParasiteUtils; LZ $Landroid/content/pm/ApplicationInfo; )Landroid/content/pm/IPackageManager$Stub; $Landroid/content/pm/IPackageManager; Landroid/os/IBinder; Landroid/os/RemoteException; Landroid/os/ServiceManager; Landroid/os/SystemClock; Landroid/os/UserHandle; "Ldalvik/annotation/EnclosingClass; #Ldalvik/annotation/EnclosingMethod; Ldalvik/annotation/InnerClass; !Ldalvik/annotation/MemberClasses; Ldalvik/annotation/Signature; Ldalvik/annotation/Throws; Ljava/io/BufferedReader; Ljava/io/BufferedWriter; Ljava/io/File; Ljava/io/FileFilter; Ljava/io/FileInputStream; Ljava/io/FileNotFoundException; Ljava/io/IOException; Ljava/io/InputStream; Ljava/io/InputStreamReader; Ljava/io/OutputStream; Ljava/io/OutputStreamWriter; Ljava/io/PrintStream; Ljava/io/Reader; Ljava/io/Writer; Ljava/lang/CharSequence; Ljava/lang/Class; Ljava/lang/Integer; Ljava/lang/Math; !Ljava/lang/NumberFormatException; Ljava/lang/Object; Ljava/lang/Process; Ljava/lang/Runtime; Ljava/lang/String; Ljava/lang/StringBuffer; Ljava/lang/StringBuilder; Ljava/lang/System; Ljava/lang/Throwable; Ljava/security/MessageDigest; (Ljava/security/NoSuchAlgorithmException; Ljava/text/SimpleDateFormat; Ljava/util/ArrayList; 9Ljava/util/ArrayList<LParasiteEmb$IMagiskBootContainer;>; Ljava/util/Collections; Ljava/util/Comparator Ljava/util/Comparator; Ljava/util/Date; Ljava/util/HashMap; Ljava/util/Iterator; Ljava/util/List; $Ljava/util/List<Ljava/lang/String;>; Ljava/util/Map Ljava/util/Map; Ljava/util/Properties; Ljava/util/Set; Ljava/util/jar/JarEntry; Ljava/util/jar/JarFile; Ljava/util/zip/CRC32; Ljava/util/zip/ZipEntry; Ljava/util/zip/ZipException; Ljava/util/zip/ZipFile; 
MAGISK_VER MAGISK_VER_CODE MD5 MIN_COLUMNS_OF_DETAIL MIN_VERSIONCODE MORE MagiskApk.java MagiskZip.java PARASITE_DEBUG PARASITE_MORE PARASITE_VERBOSE ParasiteEmb.java ParasiteUtils.java Parser REGEX_APK_FILENAME REGEX_ZIP_FILENAME SHA-1 SHA-224 SHA-256 SHA-384 SHA-512 	START_TAG TAG TYPE TerminalSize Usage: ParasiteUtils  %Usage: ParasiteUtils COMMAND [ARG...] V VERBOSE VI VIL VL VLII VLL VZ Z ZIP ZL [B [C [Ljava/io/File; [Ljava/lang/Object; [Ljava/lang/String; ] ] <  ] >=  ] [ ^"|"$ ^(.*) \(([0-9]+)\)(.[^.]+)?$ #^(Magisk-.*\.apk|app-debug.*\.apk)$ <^(Magisk-.*\.zip|magisk-debug.*\.zip|magisk-release.*\.zip)$ accept 
access$000 accessFlags add alg 	algorithm apk app appInfo append args args  arm/magiskboot arr asInterface 	attrFlags attrName attrNameNsSi 
attrNameSi 	attrResId 	attrValue attrValueSi 	available b br brief buffer bytes bytesToHexString chars close cmd cnt columns 
columnsInt 
columnsStr com.topjohnwu.magisk common/util_functions.sh compXmlString compXmlStringAt compare 	compareTo 	container 
containers containsKey count countWritten crc32 
crc32Bytes 	crc32Long currentThreadTimeMillis date decompressXML detail detectApkOrZip 	detectApp dig digest digestBytes dir e echo $COLUMNS echo $LINES enter entry equals err exec exit false file filesApk filesZip finalXML first flush format 	formatter get getApplicationInfo getBaseCodePath getClass getEntry getInputStream getInstance getLocalizedMessage getMagiskBootEntry getName getOutputStream getPackageName getPath getProperty 
getRuntime 
getService getSimpleName getType getValue getVersionCode getVersionName getZip 
getZipPath getenv h hasNext hash 	hashBytes hashCode hexChars hi i ii in indent intFromByteArray isCrc32 isDirectory isFile isNnumSuffix isSameExceptSuffix isValid iterator k keySet lastIndexOf length  lib/armeabi-v7a/libmagiskboot.so lineNo lines linesInt linesStr 	listFiles lo load mPackageName mVersionCode mVersionName mZip mZipPath main manifest matches md5 message messages min msg myUserId name name1 name2 nameNsSi nameSi newLen newLine next num1 num2 	numbAttrs numbStrings o1 o2 off out outputAdvice outputE 
outputHash outputMagiskBoot outputUsage p package packageName parseInt path pathname paths pm print printf println process prt 	prtIndent put read readLine reader regex 
replaceAll replaceFirst resourceID 0x ret s sb second sep sha1 sha224 sha256 sha384 sha512 sitOff size sort spaces stOff startTagLineNo status str strInd strLen strOff 	substring tag tag0 tag6 this 
threadTime toHexString toString true type update value valueOf versionCode versionCodeString versionName write writer xml 	xmlTagOff yyyy-MM-dd HH:mm:ss.SSS zip zipPath 	{isValid=    ”<*> M B£J ÒÀÆ≤∂-ñ ∏ ÅÛ∏ˇ∑- ÉN‘-î> [Ûá Xµ ˙÷µ' cÀ\Ø6√Ñ-ÆM≤ƒÃ‘¥&,-á÷-≥¥¶ªƒ‰√¸ƒ˝ñ√º≈É-‚˘4/Z¶5Z¶˜ƒ¯≈˚√ı≈	˘.ƒˆ4¬
˙4_.AJ	
œ J	'lµ‰	*,/√,mñ--·"@üzhU) ∏œ<- √  …  ∆  Ω  ¿  –¬;i!bîá˜4ñ’%•L ÄNì<z ¢J{.?dJ]¬ .xJ  ¢$y.f==.  ¢J ˜ ,·^ œ;=w•¶F---,U"¢J---;’%iiÀNL ˛Zé<KKJvÜ !<K?i A  E  I  œ;<.wá¶I--,S" ¢J--; ’%iZéD=ˇi«4.hrÜ ¢0] ! ¢J<N i G  K  O  ~  Åì Ñ  áì ß  ´ÖÜ• ∞, r K˙4K˚4-†4“€Máá‹MßK•Å•Ç!u5 ß         { yñ° π	≠P∫
ÆPZë<†”¨ ¥Ïi7A¢$â”“ŒiUAê§ˇêKí4©4πˇ˘4√á›zJ-ÜÜ4wi”-·2á§-{YAhw = J•ï-8wNº Ó0ûêi"“Cii§-^J ¢Zï ¢$w"“R-^iö ' KZ ô?Kæx≥;"¶ 2¥KKæZ ô?x≥;" <  <<<K îı;w•®4√˛LZ ”<v x K {ñ<ô2-KK$V¢$ã0·ü· â4Á4- à.ÊZ<<KZ<<NZ\KK--itu,yZ\KK--itx,x\KK--i[{x,<><{;<><{;-/- ≠   á··àxyñññññññ
 ﬂ4
 -      ÖÅ,Z —O”<iÈi“¥Ø>Z[ ≥  ∑ñ î¨ Ò¨;Kƒ> ÅNñ••á ⁄¨ZïHL ÄN’%Z’%ì<[-¢#iP[[z!i¢$¢#{ º¨Îû9PL ÄN’%Z’%ì<[-¢#iP[ i¢:Z; [zY¢#!i¢$¢#{ ê¨Î ˝¨ÎáL (<•|<Kz• ò¨ i∫¢á•4K Ù40¥ E,“• Í4&˝MZîB®”<Xw; “•  ;o iNkÿMˇí4[¨ KÃ4K¢$f" ? x 4<< Ö4ˇ  ú¨ †¨ √Á¯ø√Á$	¯UÁ$	¯?√√#√/Á¯√ì°1m;√
√Á¯ √√®1ññ;DDD$Òÿ>7b$öS<Ò7
≥≤$»K÷7	,„‰PF    ÅÄ®+	¿+ ÄÄ¥,‹,ê--».‹.º/  	 #Å Å Å Å Å Å Å Å Å  ÅÄƒ;‡;¯;ê<®<¿<ÿ<∞@ 	ÅÄÃB
àE¨EƒE ÅÄ†FÄI§IºI  ÄÄÑJúJ  ÄÄÿJJ  ÄÄ¨KƒK¡ ÑM 	 !,àÄ®MÅÄÃMà ‰M
¸M
òU	‡Y	∞[	\âú]&)5ÄÄê^ÄÄ¨^7‡e  ,8àÄÿfÅÄ»ià ‡i	¯i	àk	§k	ƒk
‰k
‘l
‹n	Ñq	®q	‹q	Ãr	Ïr
åt
v
êw	îx	¥x                   –  p      R   ∞     M   ¯     4   î     ∞   4        ¥       4     @   ®     
   T<    "   \=     –  v>     @   QX        Ra        Óa         *b        c  