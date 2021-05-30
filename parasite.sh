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
DEX_EXPECTED_CRC32="d870f64d"
DEX_EXPECTED_MD5="2b6e695d8a238a2b43b770a89aef9bab"
DEX_EXPECTED_SHA1="3273654126ea44511d02679667f2c492601df368"
DEX_EXPECTED_SHA256="cdb6dde24e45af435d8e9c36cf2dfe9ccabd43f16270f292de6e496bace0658c"

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
035 ���eԗ����G�j�м)�&��@e  p   xV4        pd  �  p   S   �  N   	  7   �  �   l       �O  �  �>  �>  �>  �>  ?  ?  S?  n?  r?  �?  �?  �?  �?  �?  K@  �@  �@  �@  �@  �@  �@  A  A  A  !A  AA  aA  �A  �A  �A  �A  �A  B  )B  :B  LB  UB  cB  mB  pB  �B  �B  �B  �B  �B  �B  �B  �B  �B  �B  �B  �B  �B  �B  C  C  VC  �C  �C  �C  �C  �C  �C  �C  D   D  0D  >D  ED  WD  ^D  rD  �D  �D  �D  �D  �D  �D  �D  E  (E  +E  0E  4E  9E  >E  YE  ]E  cE  fE  jE  {E  �E  �E  �E  �E  �E  �E  �E  �E  �E  F  F  F  F  F  F  1F  >F  KF  \F  mF  ~F  �F  �F  �F  �F  �F  G  7G  MG  kG  �G  �G  �G  �G  H  $H  GH  fH  �H  �H  �H  �H  �H  �H  I  /I  FI  cI  {I  �I  �I  �I  �I  �I  J  J  (J  KJ  _J  tJ  �J  �J  �J  �J  �J  �J  K  FK  dK  {K  �K  �K  �K  �K  L  L  /L  AL  gL  wL  �L  �L  �L  �L  �L  �L  M  3M  LM  XM  iM  nM  �M  �M  �M  �M  �M  �M  �M  �M  �M  N  N  /N  CN  JN  SN  \N  eN  nN  yN  ~N  �N  �N  �N  �N  �N  �N  �N  �N  �N  �N  �N  �N  �N   O  O  O  O  O  2O  GO  JO  PO  WO  \O  cO  �O  �O  �O  �O  �O  P  
P  P  P  P  $P  -P  5P  ;P  BP  RP  WP  dP  oP  yP  �P  �P  �P  �P  �P  �P  �P  �P  �P  �P  �P  �P  �P  Q  Q  Q  Q  Q  +Q  7Q  MQ  gQ  vQ  �Q  �Q  �Q  �Q  �Q  �Q  �Q  �Q  �Q  �Q  �Q  R  R   R  (R  8R  CR  HR  PR  ]R  bR  eR  tR  �R  �R  �R  �R  �R  �R  �R  �R  �R  �R  �R  �R  �R  �R  �R  �R  �R  S  S  (S  2S  BS  OS  dS  xS  �S  �S  �S  �S  �S  �S  �S  �S  �S  �S  T  T  T  &T  .T  1T  :T  @T  KT  UT  _T  cT  fT  jT  nT  vT  |T  �T  �T  �T  �T  �T  �T  �T  �T  �T  �T  �T  U  #U  +U  2U  <U  FU  QU  UU  [U  iU  wU  �U  �U  �U  �U  �U  �U  �U  �U  �U  �U  �U  �U  �U  �U  �U  �U   V  V  V  V  V  #V  .V  ;V  ?V  CV  HV  MV  [V  dV  pV  �V  �V  �V  �V  �V  �V  �V  �V  �V  �V  �V  �V  �V  �V  �V  �V  W  	W  W  W  "W  .W  <W  KW  PW  SW  WW  _W  dW  jW  rW  zW  �W  �W  �W  �W  �W  �W  �W  �W  �W  �W  �W  �W  �W  �W  �W  �W  �W  X  X  X  'X  -X  3X  ;X  BX  KX  XX  kX  xX  X  �X  �X  �X  �X  �X  �X  @   P   X   ]   ^   `   c   j   k   l   m   n   o   p   q   r   t   u   v   w   x   y   z   {   |   }   ~      �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   P          Q      �=  T      �=  T      �=  R      �=  V      �=  R      �=  S      �=  R      >  X          Y      >  e      �=  g      >  e       >  e      �=  \   %       e   %   (>  \   '       i   )   0>  e   +   8>  \   -       a   .   @>  \   1       a   1   @>  e   1   H>  i   1   �=  e   2   >  \   3       \   4       a   4   @>  b   4   �=  e   4   >  i   4   P>  e   4   �=  i   4   X>  i   4   0>  e   4   `>  e   4   �=  f   4   �=  h   4   h>  e   5   �=  _   6   t>  a   6   @>  d   6   |>  e   6   H>  e   6   �=  s   6   �=  e   9   �=  \   A       \   E       \   I       e   I   �=  \   K       �   L       �   L   @>  �   L   �>  �   L   >  �   L   �>  �   L   �>  �   L   �>  �   L   �>  �   L   H>  �   L   �=  �   L   �>  �   L   �>  �   L   �=  �   L   �=  �   L   �>  �   L   �>  �   L   >  �   M       �   M   >  �   M   H>  �   M   �=  \   N       e   N   >  i   N   P>  e   P   �=   4 �    �   4 �   K �   4 n    o   4 p   K q   4 r    F     J     K     �    4 �   4 �    �   4 �   4 L    4 M     �    4 �    4 n    o   4 p   K q   4 r  	 4 M   	 4 N   	 4 Z   	 4 [   	  �   	 4 �   	  o  	 4 p  	 K q  	 4 r   4 =    4 I    4 �    4 �    4 �     G     H     �     	   M     h   C A    C B    M E    4 �    4 �    M �   7 ) *  7 ) �   5 4    > 4        2 >    A    G     I    J   4 K    L   F `    �    �   5 4    E s   2 >    A    G     I    J   4 K    L   F `    �   5 4    '    &    %     Z   > �   7 �   > 4        2 >    G   F `  	 > 4   	    	 2 >  	  G  	 F `  
 5 4   
 G �    5 4    G �    5 4            5 3    5 4    5    5    5 '   6 ,   E s   E �   5 4    A 4     �   5 3    5 4     �    %      	    	       K    
    L "     P   L Q   E s    v   ? �    �   5 �   E �    �    �    8    �     7    E   	      {   ; 4    5     �   < 4     �    5    5 3   5 �    > 4      ?     B    F \    F ]    M k  " 8 4   %   �   % 5   %  �  & 9 4   ( : 4   )  �  ) = �  ) > �  ) C �  -  F  .  �  .  �  .  �  /  y  1 5 4   1  9  2  ;  2  @  3  +  3  D  4 B 4   4 D 4   4    4 H )  4 # 4  4   R  4  d  4   e  4 I u  4 " �  4 " �  4  �  4  �  5 5 4   5 ( �   6 5 4   6 ) �   6 * �   6 + �   6 , �   6 - �   6 . �   6  �  7 6 ,  7 ! M  8  =  9 J !  9 / <  9 C �  ; > 4   ; $ 4  < 5 4   < H �   <  6  < 0 a  <   �  = @ �  ? 5 4   @ 5 4   A F O  A  �  B H �   B 0 a  B   �  C H   C  6  C 1 c  C  �  D 5 4   D ! C  D 9 m  E 0 a  G > 4   H 5 4   H 	 H  H C �  K > 4   K 3 :  K  ;         1       ?   �<  �b           1       U       �b  Wb       1   �=  ?   �<  �b            1       D       c             1       �   �<  c  [b               �   �<  Ac  hb  	             �   �<  cc  sb  
      1   �=  �   =  �c            1   �=  �   =  �c            1   �=  �   ,=  �c            1       �       �c  �b        1       �   <=  �c  �b        1       �   L=  d         �a  �a     �a     �a     �a  �a      b     	b  b     	b  b  b     +b  2b     =b     Fb       �X     pr   ��Y       �X     pr  [# n  2  T [! T  [! T [! R Y!        �X     T          �X     R          �X     T          �X     T          �X     T        �X  �   &n
  
	9	 b5 "6 p�  	 n � � T� n � � n�  n k � "	6 p� 	 
O n � � 	8O n � � 	n� 	 "	 p 9 � U�- 8	C b	5 
' #kQ Mb( Mn0i �T� n  
n � � 	  #�N n f  
�2�* �b	6 
n@l 	(�b( q I 8 8 ne  =1 g(�n  (�b	5 
( #{Q Mn0i �(�8 ne  �(�b( q I 8 8��ne  (�(�8 ne  'v(�(�(�(�S     q     x     �     �     �    	 �     ~Jp$��$� �$�$�$�     �Y  �   ' " 6 p�   ns  nm  n �   �n �   n
  
n �   % n �   n  n �   n �    ! n �   R1 n �   " n �   T1 n �   n �      n �   T1 n �   n �    # n �   T1 n �   $ n �   T1 n �   n �    } n �   n�          �Y     pr         �Y  2    !A5/ b6 "6 p�  � n � 2 n �  0 n � 2 F n � 2 � n � 2 n�  n k ! �  (�      �Y     pr   ��Y   [       �Y     ; ��Ap0 2
� p0 2 (�     �Y  '   �H� �  �CH�D� �# N 5! ���CHO �(�"4 p x          �Y  $   � H  � � �  �H�� ���H�� ��� H�� � �       �Y             �Y  (   " 6 p�    � n  
q q C 
n0� !n �   n � p  n�    q    !     Z  �  "6 p�        p0 
$ ��      p0 
    !   ��  5     p0 
    3  ��   !      5d     p0 
�     p0 
�     p0 
�     p0 
    3��     p0 
�     p0 
�$       pT 2 "5 v�    5     p0 
�     p0 
�     p0 
�     p0 
�     p0 
	�      pX 2��n}  
,�  +�  ��  2�       p[ 2
"6 v�   t�    n � ` 5 t�    n � �  t�  t�     n �  �) f��) ���  n {  
8��  (��  n {  
8�� (��  n {  
8�� (�      p[ 2   [ ) �      p[ 2   [ ) k�  Y	 ) e�"6 v�  �t�  qo 	 t�  t�  
) ^�"6 v�  1 t�     n �     n �  6 t�  t�    n �  "6 v�  1 t�     n �     n �  6 t�  t�     p0 ��9(�ttt{  
8�      3v ���       pT 2"6 v�  2 t�     n �  6 t�  t�    n �  "6 v�  2 t�     n �  9 t�     n �  & t�    n � �  t�  t�     p0 �) ��    3 n�  ) u�"6 v�   t�  wo  t�   t�     n �  t�  w  (�  F4���)��)N   h   [         r   �   �        l[     p        t[  Z   " p   "G p � � [G TG > n � � F 9 (�TG n � ' nd  
#vN n f c 
 " p  n  e TW [G  TW [G RW YG 8��ne  (�(�8��ne  (�(�8 ne  '(�        $  B     K     T     J$FJHQ$O$X        �[  	   T  fn �            �[      <         �[  &   T  8 " T  8   T! n {  
 8  T  8  R  �S4
 n!   8    (�     �[     p        �[  f   " p   "K p � � [6 T6 n � v 9  (�T6 n �  "D p�  n � $ � n � d �   n0� v[6 � n � d 8 qn  
Y6 8��ne  (�(� ��Y6 (� 8��ne  (�(�8 ne  '(�        #  @     H     Q     W     `     J$L~0NJT]JT]$[$d      =\  	   T " � n �            B\      �         G\     T # 8  T " 8  T ! 8  R   �K4
 n&   8    (�     L\     pr         Q\     na  
 8  n^   � n �  
 8    (�     X\     pr         ^\     na  
 8  n^   � n �  
 8    (�     f\     pr         l\  X   r  
	r  

� 	
8   r  r  � n � s 
	8	6 n � t 
	8	0 	 n0� s		
 n0� t

n { � 
8 8 	 n0� s		qn 	 
	 n0� t		qn 	 
��(�(�n z C 
(�     �\  	     n0. !
          �\  	     nm    i (         �\     pr         �\  �  b5  tk  "  ,   p ]  "
 v)    n b  	" v+    n b  
"< p�  !�       5$ F	" n_    p   n#  
8 n � % �(�b(   q I p (�!�       5( F
"	 n_     p $  t(  
8   n �  �(�b(   q I p (�" v-    q �  n�  x�  
8k x�   r  "    p ] � wM  +   n ~  
�  n �  b5     # Q           n0� M r  M r  
wp  M Mti  (�) b(   q I p (�    # Q     n�  
wp  Mw|  b5   n k 0 n�  
=� n�  
��:Z n�  
��  n �   b5     # Q     "6 v�  r  t�  . t�  t�  M r  Mti      r   
9
   w5  ��(�   2��   # R     : M 8 M 7 Mw7   b5  tk  (�  8     e     �   
  $O$�$�     �]    	�S�qR  qP  9
 b5 
 n k e  q T   
r@Q Sv 8 � " nO   p  Q r  
4�s b5 "6 p�   n � v r  n � v � n � v n�  n k e b5 "6 p�   n � v r  
n � v � n � v n � � n�  n k e r  
8u � r  Q 
9f q5 	 (�b( q I % b5  n k e ) |�b( q I % ) t�b5 "6 p�   n � v r  n � v � n � v n�  n k e b5 "6 p�   n � v r  
n � v � n � v n � � n�  n k e (�2�)�q5 
 ) $�r  9�b5  n k e ) �b5  n k e ) �     
  %   	  �$�         ^  _   c4 8\ " ? p�   q S   "; �p � A b5 "6 p�   n � e n �  n � e � n � e n�  n k T b5 "6 p�   n � e n0� %� n � e n�  n k T b5 " p8  n j T         "^  X   c4 8R q S   " ? p�   b5 "6 p�   n � e n0� %� n � e n�  n k T "; �p � A b5 "6 p�   n � e n �  n � e � n � e n�  n k T q�        I^     q 4   q 3   q 2   q5         T^  2   !s9  F* & n0� Cn  
q ?   
q q C 
n0� bb5 n k #  !s50��b5 F n k C �  (�     y^      p 9         ^  v  pr  q w   #�R 
- M	
n v � 93 P Y�,  Y�. �b	2 n { � 
9 -b	2 n { � 
9 R�, 	F 4� \�-  q =   q I ( (�(�" "& nt  	p g � p U � " "( nu  	p h � p X �  P  %n Y � n\  n[  nW  &n Y � n\  n[  nW  8 nV  8 nZ  qn  
 qn  
Y�, Y�. �b	2 n { � 
9 -b	2 n { � 
9 R�, 	F 4� \�- 8��c4 8}�b5 n j � ) v�(�q =   q I ( 8 nV  8 nZ  qn  
 qn  
Y�, Y�. �b	2 n { � 
9 -b	2 n { � 
9 R�, 	F 4� \�- 87�c4 83�b5 n j � ) ,�(��8 nV  8 nZ  qn  
 qn  
Y�, Y�. �b
2 n { � 
9 -b
2 n { � 
9 R�, 
F 4� \�- 8 c4 8 b5 n j � '	(�) 5�) 7�) 8�) 9�) s�) u�) v�) w�(�(�(�(�     i     �     �     �     �     �    
 �     �    ! �    % �    )    -    1    5 #   9 $<$�� �$�$�0�0�$�$�0�0�$�$�0�0�        _  4   " 6 p�    n �   R!, n �   � n �   R!. n �   � n �   U!- n �   � n �   n�           _  �    nm  i3 �� q�  n { ! 
j1 �� q�  n { ! 
j4 � q�  i2 "@ p�  i0 "@ p�  i/ b0 C r0� !b0 v� r0� !b0 �� r0� !b0 �� r0� !b0 �� r0� !b0 �� r0� !b0 �� r0� !b0 r�  r�  r�  
8' r�    4 b/ "6 p�  n �   n � C n�  b0 r �  r0� 2(�        @_     pr           E_     b 3         J_  @   
 !t�#@O !t5B1 H�� H�D� ��� 5a �0�DP ��5c �0�DP �(����a(����a(�"4 p y        u_      q@   
       {_     "  p 9  R ,       �_      C q E      
     �_  0   � qC 	 A#N  ��d�A�O  ��d�D�DO ! ��d�D�DO 1��d�D�DO  
    �_  P   "H p�    #`N "" p c � n f  
�2a n@� (�Tn` 	 
8 n�  8 ne  8 ne  n�  T(�'8 ne  ''(�(�(�T(�T(�(�
             	  )     /    	 8     <     A     ~#$KH 9$B$D$F~#N$@9
   	 3`  Y   q� 	   #`N "" p c � n f  
�2a" n@� (�Tn`  
8 n�  8 ne  b3 q I 6 #vN (�8 ne  n�  (�'8 ne  ''(�(�(�T(�T(�(�                    	 
 *     9     A    
 E     J    
 ~#$TQ:. B$K$M$O~#W$IB      �`  	   q F !  q>            �`      C n {   
 8  qB    q D !  (�     �`  /   !0=  b 0 Fr �  
 8  qJ  
 q�   q K   q�    b / Fr �  
 8 ��qJ  
 q�   (�       �`      � q E           a  H   ns  nm  n�   b5 "6 p�  	 n � C n � c / n � C 8  "6 p�  n �   n � T n �  n�  n �  n�  n k 2      !a  �   
!�=( b0 F
r � � 
8 b0 F
r � �   4 "< p�  !�5�' Fr � � �(�!�= b/ F
r � � 
8 b/ F
r � �   4 (�q K   	r�  
9 qL  (�	C n { 	 
r�  r�  
	8	= r�  4 "  p ] s q E  b6 8 n k L (�b	3 q I ) (�"	6 p� 	 n � I 8 	 n � � 	n � y 	n� 	 (�	 (��(�  m     �     $y      �a     b 5 � n k        �a  9   !A=4 F b0 r �  
9
 b/ r �  
8! b5 "6 p�  � n � 2 n �   n � 2 n�  n k !  q K   (�       �a      � q E           �a      � q E      �              �                �     �  �              �                �      �                 $   �  %   �  �              �              �              �     	       /     0     A   �  B   �  C   �  D   �  E   �  F   �  H   �  M   �  N   �           !      >                1 1    4      M      N      N     R             4              I      4 Q    ,            1        4    4 4    ?      N                     4    %      '      *      +      4 8    B >    N        O        -                                                %s %-8s %5d  %s
 7  MAGISK FALLBACK FILES (APK or ZIP in Download folder)   Unrecognized tag code '  :  FILE [FILE...] !  "! Can't connect to package manager 6! Can't get application info of 'com.topjohnwu.magisk' ! Invalid Magisk file:  M! Magisk APK (21402+) or Magisk ZIP (19400+) is not found in /sdcard/Download @! Magisk app does not contain 'lib/armeabi-v7a/libmagiskboot.so' '! Magisk app is not installed or hidden ! Magisk app version code:   [ ! Magisk app version name:   [ " $1$3 $2 %8d FILE(S) ' at offset  ) * DEX finish:                [ * DEX start:                 [ * DEX thread time on finish: [ * DEX thread time on start:  [ * Magisk %-19s [%s]
 * Magisk app version code:   [ * Magisk app version name:   [ * Terminal size:             [ , mPackageName=' , mVersionCode= , mVersionName=' , mZip= , mZipPath=' , type=' - - %-47s (%s >)
 - %s
 (---------------------------------------- . / /sdcard/Download /system/bin/sh : :  : [ < </ <clinit> <init> =" > N> (Canary) https://github.com/topjohnwu/magisk-files/blob/canary/app-debug.apk 7> (Public) https://github.com/topjohnwu/Magisk/releases > (line  4> Download Magisk APK in Chrome Mobile and try again >; APK APP_PACKAGE_NAME AndroidManifest.xml BaseMagiskBootContainer.java C CMD_ALGS_B_MAP CMD_ALGS_MAP CRC32 CmdLineArgs.java DEBUG DEFALT_VERSIONCODE DEFAULT_COLUMNS DEFAULT_LINES DOWNLOAD_FOLDER_PATH END_DOC_TAG END_TAG ENTRY_ANDROIDMANIFEST_XML ENTRY_MAGISKBOOT ENTRY_UTIL_FUNCTIONS_SH "Extracting magiskboot from Magisk  I III IL ILI ILL IMagiskBootContainer.java IZ Info J JL KEY_VERSIONCODE KEY_VERSIONNAME L LBaseMagiskBootContainer$Info; LBaseMagiskBootContainer; LC LCmdLineArgs; LI LII LIMagiskBootContainer; LJ LL LLI LLII LLIII LLL LMagiskApk$Parser; LMagiskApk; LMagiskZip; LParasiteEmb$1; LParasiteEmb$2; LParasiteEmb$3; LParasiteEmb; LParasiteUtils$TerminalSize; LParasiteUtils; LZ $Landroid/content/pm/ApplicationInfo; )Landroid/content/pm/IPackageManager$Stub; $Landroid/content/pm/IPackageManager; Landroid/os/IBinder; Landroid/os/RemoteException; Landroid/os/ServiceManager; Landroid/os/SystemClock; Landroid/os/UserHandle; "Ldalvik/annotation/EnclosingClass; #Ldalvik/annotation/EnclosingMethod; Ldalvik/annotation/InnerClass; !Ldalvik/annotation/MemberClasses; Ldalvik/annotation/Signature; Ldalvik/annotation/Throws; Ljava/io/BufferedReader; Ljava/io/BufferedWriter; Ljava/io/File; Ljava/io/FileFilter; Ljava/io/FileInputStream; Ljava/io/FileNotFoundException; Ljava/io/IOException; Ljava/io/InputStream; Ljava/io/InputStreamReader; Ljava/io/OutputStream; Ljava/io/OutputStreamWriter; Ljava/io/PrintStream; Ljava/io/Reader; Ljava/io/Writer; Ljava/lang/CharSequence; Ljava/lang/Class; Ljava/lang/Integer; Ljava/lang/Math; !Ljava/lang/NumberFormatException; Ljava/lang/Object; Ljava/lang/Process; Ljava/lang/Runtime; Ljava/lang/String; Ljava/lang/StringBuffer; Ljava/lang/StringBuilder; Ljava/lang/System; Ljava/lang/Throwable; Ljava/security/MessageDigest; (Ljava/security/NoSuchAlgorithmException; Ljava/text/SimpleDateFormat; Ljava/util/ArrayList; -Ljava/util/ArrayList<LIMagiskBootContainer;>; Ljava/util/Collections; Ljava/util/Comparator Ljava/util/Comparator; Ljava/util/Date; Ljava/util/HashMap; Ljava/util/Iterator; Ljava/util/List; $Ljava/util/List<Ljava/lang/String;>; Ljava/util/Map Ljava/util/Map; Ljava/util/Properties; Ljava/util/Set; Ljava/util/jar/JarEntry; Ljava/util/jar/JarFile; Ljava/util/zip/CRC32; Ljava/util/zip/ZipEntry; Ljava/util/zip/ZipException; Ljava/util/zip/ZipFile; 
MAGISK_VER MAGISK_VER_CODE MD5 MIN_COLUMNS_OF_DETAIL MIN_VERSIONCODE MORE MagiskApk.java MagiskZip.java PARASITE_DEBUG PARASITE_MORE PARASITE_VERBOSE ParasiteEmb.java ParasiteUtils.java Parser REGEX_APK_FILENAME REGEX_ZIP_FILENAME SHA-1 SHA-224 SHA-256 SHA-384 SHA-512 	START_TAG TAG TYPE TerminalSize Usage: ParasiteUtils  %Usage: ParasiteUtils COMMAND [ARG...] V VERBOSE VI VIL VL VLII VLL VZ Z ZIP ZL [B [C [Ljava/io/File; [Ljava/lang/Object; [Ljava/lang/String; ] ] <  ] >=  ] [ ^"|"$ ^(.*) \(([0-9]+)\)(.[^.]+)?$ #^(Magisk-.*\.apk|app-debug.*\.apk)$ <^(Magisk-.*\.zip|magisk-debug.*\.zip|magisk-release.*\.zip)$ accept 
access$000 accessFlags add alg 	algorithm apk app appInfo append args args  arm/magiskboot arr asInterface 	attrFlags attrName attrNameNsSi 
attrNameSi 	attrResId 	attrValue attrValueSi 	available b br brief buffer bytes bytesToHexString chars checkZipPath close cmd cnt columns 
columnsInt 
columnsStr com.topjohnwu.magisk common/util_functions.sh compXmlString compXmlStringAt compare 	compareTo 	container 
containers containsKey count countWritten crc32 
crc32Bytes 	crc32Long currentThreadTimeMillis date decompressXML detail detectApkOrZip 	detectApp dig digest digestBytes dir e echo $COLUMNS echo $LINES enter entry equals err exec exit false file filesApk filesZip finalXML first flush format 	formatter get getApplicationInfo getBaseCodePath getClass getEntry getInputStream getInstance getLocalizedMessage getMagiskBootEntry getName getOutputStream getPackageName getPath getProperty 
getRuntime 
getService getSimpleName getType getValue getVersionCode getVersionName getZip 
getZipPath getenv h hasNext hash 	hashBytes hashCode hexChars hi i ii in indent info intFromByteArray isCrc32 isDirectory isFile isNnumSuffix isSameExceptSuffix isValid iterator k keySet lastIndexOf length  lib/armeabi-v7a/libmagiskboot.so lineNo lines linesInt linesStr 	listFiles lo load mPackageName mVersionCode mVersionName mZip mZipPath main manifest matches md5 message messages min msg myUserId name name1 name2 nameNsSi nameSi newLen newLine next num1 num2 	numbAttrs numbStrings o1 o2 off out outputAdvice outputE 
outputHash outputMagiskBoot outputUsage p package packageName parseInt path pathname paths pm print printf println process prt 	prtIndent put read readLine reader regex 
replaceAll replaceFirst resourceID 0x ret s sb second sep sha1 sha224 sha256 sha384 sha512 sitOff size sort spaces stOff startTagLineNo status str strInd strLen strOff 	substring tag tag0 tag6 this 
threadTime toHexString toString true type update value valueOf versionCode versionCodeString versionName write writer xml 	xmlTagOff yyyy-MM-dd HH:mm:ss.SSS zip zipPath 	{isValid=  ? �<-K �KKKK %  +  (    "  2�;i!b���5���&�L �O�<z �K].?dJ]� .xJ  �%[.f==.  �K Y ,�^   � �<*> I B�J �����-� � �����- �O�-�> W�� T� ���' _�\�7��-�M�����&,-��-���������������-��5/Z�6Z���������	�.��5�
�5_.AJ	
� J	'l��	*,/�,m�--�"@�zhU) �< �[����G,_"�K%�&ii�OL �Z�<KKRy� $i =  A  E  �< �[����J,Z" �K% �&iZ�E=�i�5.ht� �1] $ �K i E  I  M  z  }� �  �� �  ���� �, r K�5K�5-�5��N���N�K����!u5 �       w y��!�	�Q�
�QZ�=���!��	i7A�%����
iUA����K�5�5���5Ç�zJ-��5wi�-�2��-{YAhw 9 J��-8wN� �0��i"�Cii�-^J �Z� �%w"�R-^i� # KZ �@K�x�<"� .�KK�Z �@x�<" < �<<<K ��;w��5��LZ �<v x K {�<�3-KK$V�%�0���� �5�5- �.�Z<<KZ<<NZ\KK--itu,yZ\KK--itx,x\KK--i[{x,<><{;<><{;-/- �   ���xy�������
 �5
 -      ��,Z �P�<i�i���>Z[ �  �� �� ��;K�> �O���� ��Z�IL �O�&Z�&�<[-�$iP[[z!i�%�${ ����:PL �O�&Z�&�<[-�$iP[ i�;Z; [zY�$!i�%�${ ��� ����L (�<�|<Kz� �� i����5K �50� E�,ҥ �5&�NZ�C��<Xw; ҥ  ;o iNk�N��5[�!K�5K�%f" ? x 4�<< �5�  �� �� ���W��$������2�����1c;��	�����1��;$��DDD>7f$�S<�7��$�K�7,��PF        ���,  		� � � � � � � � �  ���,� �,�-�-�-�-�-�1   ���3	�3
���4�5�5�6�6�7�7 ���C �D�F�F�F $���G%�G�I�J�J  )���J*�J  +���K,�K  -���L.�L� �M  $0���N���N
�N
�U	�Z	�[	�]��]),8���^���^:�f  /;���g���j� �j	�j	�k	�k	�l
�l
�m
�o	�q	�q	�r	�s	�s
�t
�w
�w	�x	�x                 �  p      S   �     N   	     7   �     �   l            
   �     B        	   �<    "   �=     �  �>     B   �X        �a        Wb         �b        pd  