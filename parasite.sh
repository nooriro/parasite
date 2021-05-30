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
# Thanks: Airpil, daedae, gheron772, íŒŒì´ì–´íŒŒì´ì–´, í”½ì…€2VOLTE, and topjohnwu
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
035 ¼àeÔ—³ˆ¦¿G•j„Ğ¼)…&—¥@e  p   xV4        pd  Ô  p   S   À  N   	  7   ´  ³   l       œO  ¤  Î>  Ğ>  Ó>  ×>  ?  ?  S?  n?  r?  ƒ?  ‡?  «?  ã?  ü?  K@  @  ¶@  Ö@  ö@  ù@  ÿ@  A  A  A  !A  AA  aA  A  ¡A  ·A  ×A  ÷A  B  )B  :B  LB  UB  cB  mB  pB  B  ˆB  ²B  µB  ¸B  ÊB  ÚB  İB  áB  æB  éB  íB  ÷B  ÿB  C  C  VC  C  ™C  ÏC  ÓC  ØC  êC  ÿC  D   D  0D  >D  ED  WD  ^D  rD  ƒD  ’D  ¨D  µD  ¾D  ÙD  ëD  E  (E  +E  0E  4E  9E  >E  YE  ]E  cE  fE  jE  {E  ŒE  E  ¯E  ÊE  ÎE  İE  áE  æE  şE  F  F  F  F  F  F  1F  >F  KF  \F  mF  ~F  F  «F  ¼F  ÀF  æF  G  7G  MG  kG  ˆG  ¢G  »G  ßG  H  $H  GH  fH  ‚H  œH  ¶H  ÆH  ÜH  ÷H  I  /I  FI  cI  {I  ™I  °I  ÂI  ÔI  îI  J  J  (J  KJ  _J  tJ  ‰J  J  ·J  ÒJ  æJ  ıJ  K  FK  dK  {K  ªK  ÃK  ÚK  òK  L  L  /L  AL  gL  wL  ˆL   L  ±L  ËL  äL  ûL  M  3M  LM  XM  iM  nM  …M  –M  œM  ¬M  ¼M  ÌM  ÛM  íM  ÿM  N  N  /N  CN  JN  SN  \N  eN  nN  yN  ~N  „N  ’N  ©N  ĞN  ÓN  ÜN  àN  åN  éN  ïN  ôN  øN  ûN   O  O  O  O  O  2O  GO  JO  PO  WO  \O  cO  O  ¦O  äO  ìO  øO  P  
P  P  P  P  $P  -P  5P  ;P  BP  RP  WP  dP  oP  yP  ‡P  “P  P  ©P  ¶P  ÁP  ÄP  ÈP  ÏP  ×P  ŞP  ğP  ÷P  Q  Q  Q  Q  Q  +Q  7Q  MQ  gQ  vQ  ‡Q  Q  ›Q  ¦Q  ²Q  ¿Q  ÆQ  ÔQ  ÛQ  çQ  òQ  R  R   R  (R  8R  CR  HR  PR  ]R  bR  eR  tR  R  ˆR  R  —R  œR  ¢R  ¨R  ¯R  µR  ¿R  ÉR  ÓR  ÚR  áR  éR  ôR  ùR  S  S  (S  2S  BS  OS  dS  xS  S  ’S  ¢S  «S  ¸S  ÄS  ĞS  ßS  èS  òS  T  T  T  &T  .T  1T  :T  @T  KT  UT  _T  cT  fT  jT  nT  vT  |T  T  —T  ¤T  ¬T  ºT  ÎT  ×T  áT  äT  ìT  ùT  U  #U  +U  2U  <U  FU  QU  UU  [U  iU  wU  …U  ‹U  •U  ›U  ¥U  ®U  ³U  ¼U  ÆU  ËU  ĞU  ÚU  àU  çU  îU  øU   V  V  V  V  V  #V  .V  ;V  ?V  CV  HV  MV  [V  dV  pV  ‚V  V  ’V  ›V  ¨V  ²V  ¸V  ÂV  ÉV  ÍV  ÔV  ÜV  åV  îV  óV  şV  W  	W  W  W  "W  .W  <W  KW  PW  SW  WW  _W  dW  jW  rW  zW  ‚W  ŠW  ’W  ˜W  W  ¦W  ­W  ½W  ÅW  ÊW  ÒW  ÚW  âW  íW  òW  øW  şW  X  X  X  'X  -X  3X  ;X  BX  KX  XX  kX  xX  X  ‡X  ŒX  —X  °X  µX  ¾X  @   P   X   ]   ^   `   c   j   k   l   m   n   o   p   q   r   t   u   v   w   x   y   z   {   |   }   ~      €      ‚   ƒ   „   …   †   ‡   ˆ   ‰   Š   ‹   Œ               ‘   ’   “   ”   •   –   —   ˜   ™   š   ›   œ         Ÿ       ¢   ¤   ¥   ¦   §   ¨   «   ¬   ­   ®   ¯   °   ±   ²   ³   Ï   ×   Ú   Û   Ü   İ   Ş   P          Q      Ì=  T      Ô=  T      Ü=  R      ä=  V      ì=  R      ô=  S      ü=  R      >  X          Y      >  e      ä=  g      >  e       >  e      ä=  \   %       e   %   (>  \   '       i   )   0>  e   +   8>  \   -       a   .   @>  \   1       a   1   @>  e   1   H>  i   1   Ü=  e   2   >  \   3       \   4       a   4   @>  b   4   Ì=  e   4   >  i   4   P>  e   4   ä=  i   4   X>  i   4   0>  e   4   `>  e   4   ô=  f   4   ü=  h   4   h>  e   5   ä=  _   6   t>  a   6   @>  d   6   |>  e   6   H>  e   6   ä=  s   6   ì=  e   9   ä=  \   A       \   E       \   I       e   I   ä=  \   K       Ï   L       Ñ   L   @>  Ò   L   „>  Ó   L   >  Ó   L   Œ>  Ó   L   ”>  Ó   L   œ>  Ó   L   ¤>  Ó   L   H>  Ó   L   ä=  Õ   L   ¬>  Õ   L   ´>  Ö   L   ì=  Ó   L   ô=  Ô   L   ¼>  Ó   L   È>  Ó   L   >  ×   M       Ù   M   >  Ù   M   H>  Ù   M   ä=  \   N       e   N   >  i   N   P>  e   P   ¼=   4 “    É   4 Ë   K Ñ   4 n    o   4 p   K q   4 r    F     J     K     É    4 “   4 ´    É   4 Ë   4 L    4 M     ¸    4 Ë    4 n    o   4 p   K q   4 r  	 4 M   	 4 N   	 4 Z   	 4 [   	  ¸   	 4 Ë   	  o  	 4 p  	 K q  	 4 r   4 =    4 I    4 Â    4 Ã    4 Ê     G     H     ·     	   M     h   C A    C B    M E    4 ¹    4 Ê    M Ğ   7 ) *  7 ) ‹   5 4    > 4        2 >    A    G     I    J   4 K    L   F `        Ã   5 4    E s   2 >    A    G     I    J   4 K    L   F `       5 4    '    &    %     Z   >    7    > 4        2 >    G   F `  	 > 4   	    	 2 >  	  G  	 F `  
 5 4   
 G ç    5 4    G ç    5 4            5 3    5 4    5    5    5 '   6 ,   E s   E Œ   5 4    A 4     Ã   5 3    5 4     è    %      	    	       K    
    L "     P   L Q   E s    v   ?        5    E     ¬    ®    8    õ     7    E   	      {   ; 4    5     ¡   < 4     ğ    5    5 3   5 ‚    > 4      ?     B    F \    F ]    M k  " 8 4   %   ı   % 5   %     & 9 4   ( : 4   )  š  ) = ›  ) > ›  ) C Ì  -  F  .  ”  .  Â  .  È  /  y  1 5 4   1  9  2  ;  2  @  3  +  3  D  4 B 4   4 D 4   4    4 H )  4 # 4  4   R  4  d  4   e  4 I u  4 " ¤  4 " ¥  4  ¼  4  ¼  5 5 4   5 ( ğ   6 5 4   6 ) ğ   6 * ğ   6 + ğ   6 , ğ   6 - ğ   6 . ğ   6  Ã  7 6 ,  7 ! M  8  =  9 J !  9 / <  9 C Æ  ; > 4   ; $ 4  < 5 4   < H ê   <  6  < 0 a  <   ²  = @ ³  ? 5 4   @ 5 4   A F O  A  ƒ  B H ê   B 0 a  B   ²  C H   C  6  C 1 c  C  Ÿ  D 5 4   D ! C  D 9 m  E 0 a  G > 4   H 5 4   H 	 H  H C Æ  K > 4   K 3 :  K  ;         1       ?   œ<  “b           1       U       ¥b  Wb       1   ´=  ?   ¬<  Ïb            1       D       c             1       º   Ì<  c  [b               º   Ü<  Ac  hb  	             »   ü<  cc  sb  
      1   ¼=  ¿   =  ‰c            1   ¼=  ¿   =  —c            1   Ä=  ¿   ,=  ¥c            1       ¿       ¸c  ‚b        1       À   <=  ëc  Œb        1       À   L=  d         Êa  Ña     Üa     åa     îa  õa      b     	b  b     	b  b  b     +b  2b     =b     Fb       ÉX     pr   ñØY       ÏX     pr  [# n  2  T [! T  [! T [! R Y!        âX     T          çX     R          ìX     T          ñX     T          öX     T        ûX  ´   &n
  
	9	 b5 "6 p‡  	 n Œ ˜ TÙ n Œ ˜ n  n k † "	6 p‡ 	 
O n Œ © 	8O n Œ é 	n 	 "	 p 9 ‰ U™- 8	C b	5 
' #kQ Mb( Mn0i ©TÙ n  
n ² © 	  #N n f  
ù2‘* °b	6 
n@l 	(òb( q I 8 8 ne  =1 g(¥n  (¯b	5 
( #{Q Mn0i ©(Ã8 ne  ‡(b( q I 8 8Şÿne  (Ù(×8 ne  'v(Ğ(æ(Ê(øS     q     x     ’     ˜     Ÿ    	 ¨     ~Jp$—¥$£ ¥$®$°$²     ‰Y  †   ' " 6 p‡   ns  nm  n Œ   Ón Œ   n
  
n    % n Œ   n  n Œ   n ˆ    ! n Œ   R1 n ‰   " n Œ   T1 n Œ   n ˆ      n Œ   T1 n Œ   n ˆ    # n Œ   T1 n ‹   $ n Œ   T1 n Œ   n ˆ    } n ˆ   n          •Y     pr         šY  2    !A5/ b6 "6 p‡  ò n Œ 2 n ‰  0 n Œ 2 F n Œ 2 ß n Œ 2 n  n k ! Ø  (Ñ      ­Y     pr   ñØY   [       ·Y     ; Ú°Ap0 2
 p0 2 (ò     ÎY  '   ØHà ÿ  µCHÕDÿ –# N 5! ØÚ°CHO Ø(ó"4 p x          îY  $   Ø H  Õ ÿ à  ØHÕÿ à¶ØHÕÿ à¶Ø HÕÿ à ¶       ÷Y             şY  (   " 6 p‡    Ú n  
q q C 
n0„ !n Œ   n Œ p  n    q    !     Z  ü  "6 p‡        p0 
$ Ú      p0 
    !   Øü  5     p0 
    3  şÿ   !      5d     p0 
Ø     p0 
Ø     p0 
Ø     p0 
    3§Ø     p0 
Ø     p0 
Ø$       pT 2 "5 v…    5     p0 
Ø     p0 
Ø     p0 
Ø     p0 
Ø     p0 
	Ø      pX 2ÿÿn}  
,Ø  +ã  ÿÿ  2™       p[ 2
"6 v‡   tŒ    n Œ ` 5 tŒ    n Œ    tŒ  t     n †  Ø) fÿØ) Íş’  n {  
8­ÿ  (©Ë  n {  
8 ÿ (œÉ  n {  
8“ÿ (      p[ 2   [ ) ÿ      p[ 2   [ ) kÿ  Y	 ) eÿ"6 v‡  ¦tŒ  qo 	 tŒ  t  
) ^ÿ"6 v‡  1 tŒ     n Œ     n ‹  6 tŒ  t    n Œ  "6 v‡  1 tŒ     n Œ     n ‹  6 tŒ  t     p0 àØ9(şttt{  
8ş      3v ØÿØ       pT 2"6 v‡  2 tŒ     n Œ  6 tŒ  t    n Œ  "6 v‡  2 tŒ     n Œ  9 tŒ     n ‰  & tŒ    n ‰ ğ  tŒ  t     p0 à) ı    3 n  ) uÿ"6 v‡   tŒ  wo  tŒ   tŒ     n ‰  t  w  (Ò  F4åÏå)ƒß)N   h   [         r   †   š        l[     p        t[  Z   " p   "G p ¬ § [G TG > n ± ‡ F 9 (şTG n ² ' nd  
#vN n f c 
 " p  n  e TW [G  TW [G RW YG 8Øÿne  (Ó(Ñ8Ïÿne  (Ê(È8 ne  '(ş        $  B     K     T     J$FJHQ$O$X        Ê[  	   T  fn ±            Ï[      <         Ô[  &   T  8 " T  8   T! n {  
 8  T  8  R  šS4
 n!   8    (ş     Ù[     p        á[  f   " p   "K p ° ¦ [6 T6 n ± v 9  (şT6 n ²  "D p¨  n ª $ ´ n © d ã   n0 v[6 µ n © d 8 qn  
Y6 8Ğÿne  (Ë(É òØY6 (ó 8Áÿne  (¼(º8 ne  '(ş        #  @     H     Q     W     `     J$L~0NJT]JT]$[$d      =\  	   T " ó n ±            B\      Ø         G\     T # 8  T " 8  T ! 8  R   ÈK4
 n&   8    (ş     L\     pr         Q\     na  
 8  n^   å n €  
 8    (ş     X\     pr         ^\     na  
 8  n^   æ n €  
 8    (ş     f\     pr         l\  X   r  
	r  

‘ 	
8   r  r  ä n € s 
	8	6 n € t 
	8	0 	 n0‚ s		
 n0‚ t

n { © 
8 8 	 n0‚ s		qn 	 
	 n0‚ t		qn 	 
‘€(¼(Òn z C 
(ø     Ï\  	     n0. !
          ×\  	     nm    i (         Ü\     pr         á\  ³  b5  tk  "  ,   p ]  "
 v)    n b  	" v+    n b  
"< p—  !       5$ F	" n_    p   n#  
8 n ˜ % Ø(âb(   q I p (õ!        5( F
"	 n_     p $  t(  
8   n ˜  Ø(Şb(   q I p (õ" v-    q œ  nš  xŸ  
8k x    r  "    p ] Ğ wM  +   n ~  
Ø  n ƒ  b5     # Q           n0„ M r  M r  
wp  M Mti  () b(   q I p (®    # Q     n›  
wp  Mw|  b5   n k 0 n›  
=€ n›  
Øÿ:Z n›  
Øÿ  n ™   b5     # Q     "6 v‡  r  tŒ  . tŒ  t  M r  Mti      r   
9
   w5  Øÿ(­   2ùÿ   # R     : M 8 M 7 Mw7   b5  tk  (Û  8     e     ¨   
  $O$€$û     ]    	šS’qR  qP  9
 b5 
 n k e  q T   
r@Q Sv 8 á " nO   p  Q r  
4…s b5 "6 p‡   n Œ v r  n Œ v ß n Œ v n  n k e b5 "6 p‡   n Œ v r  
n ‰ v á n Œ v n ‰ † n  n k e r  
8u î r  Q 
9f q5 	 (Šb( q I % b5  n k e ) |ÿb( q I % ) tÿb5 "6 p‡   n Œ v r  n Œ v ß n Œ v n  n k e b5 "6 p‡   n Œ v r  
n ‰ v à n Œ v n ‰ † n  n k e (2¤)ÿq5 
 ) $ÿr  9ÿb5  n k e ) ÿb5  n k e ) ÿ     
  %   	  $         ^  _   c4 8\ " ? p   q S   "; Ğp • A b5 "6 p‡   n Œ e n –  n Œ e ß n Œ e n  n k T b5 "6 p‡   n Œ e n0Š %ß n Œ e n  n k T b5 " p8  n j T         "^  X   c4 8R q S   " ? p   b5 "6 p‡   n Œ e n0Š %ß n Œ e n  n k T "; Ğp • A b5 "6 p‡   n Œ e n –  n Œ e ß n Œ e n  n k T q        I^     q 4   q 3   q 2   q5         T^  2   !s9  F* & n0 Cn  
q ?   
q q C 
n0„ bb5 n k #  !s50Şÿb5 F n k C Ø  (ô     y^      p 9         ^  v  pr  q w   #™R 
- M	
n v ˜ 93 P YÈ,  YÈ. Äb	2 n { ˜ 
9 -b	2 n { ˜ 
9 RÈ, 	F 4˜ \È-  q =   q I ( (Ğ(ó" "& nt  	p g ˜ p U † " "( nu  	p h ˜ p X ‡  P  %n Y ‡ n\  n[  nW  &n Y ‡ n\  n[  nW  8 nV  8 nZ  qn  
 qn  
YÀ, YÃ. Äb	2 n { ˜ 
9 -b	2 n { ˜ 
9 RÈ, 	F 4˜ \È- 8ÿc4 8}ÿb5 n j È ) vÿ(ğq =   q I ( 8 nV  8 nZ  qn  
 qn  
YÀ, YÃ. Äb	2 n { ˜ 
9 -b	2 n { ˜ 
9 RÈ, 	F 4˜ \È- 87ÿc4 83ÿb5 n j È ) ,ÿ(ğ‰8 nV  8 nZ  qn  
 qn  
YÀ, YÃ. Äb
2 n { ¨ 
9 -b
2 n { ¨ 
9 RÈ, 
F 4¨ \È- 8 c4 8 b5 n j È '	(ñ) 5ÿ) 7ÿ) 8ÿ) 9ÿ) sÿ) uÿ) vÿ) wÿ(«(®(°(²     i     ‰          ‘     •     Ê    
 Ó     Ø    ! Û    % ß    )    -    1    5 #   9 $<$É“ “$Ö$Ù0Ü0ß$â$å0è0ë$î$ğ0ò0ô        _  4   " 6 p‡    n Œ   R!, n ‰   â n Œ   R!. n ‰   â n Œ   U!- n    ß n Œ   n           _  ¯    nm  i3 Ä¼ q  n { ! 
j1 Ä¾ q  n { ! 
j4 ½ q  i2 "@ p  i0 "@ p  i/ b0 C r0§ !b0 v¶ r0§ !b0 ¬Ä r0§ !b0 ­Å r0§ !b0 ®Æ r0§ !b0 ¯Ç r0§ !b0 °È r0§ !b0 r¦  r«  rŸ  
8' r     4 b/ "6 p‡  n Œ   n Œ C n  b0 r ¥  r0§ 2(Ö        @_     pr           E_     b 3         J_  @   
 !tÚ#@O !t5B1 Hİá HÕDğ áÚØ 5a Ø0DP ÚØ5c Ø0DP Ø(ÙØöØa(ëØöØa(ñ"4 p y        u_      q@   
       {_     "  p 9  R ,       ƒ_      C q E      
     ‹_  0   ÿ qC 	 A#N  ¤Àd„AO  ¤Àd„DDO ! ¤Àd„DDO 1¤Àd„DDO  
    £_  P   "H p­    #`N "" p c • n f  
ö2a n@¯ (õTn` 	 
8 n®  8 ne  8 ne  n®  T(õ'8 ne  ''(ï(ç(øT(ğT(ô(Î
             	  )     /    	 8     <     A     ~#$KH 9$B$D$F~#N$@9
   	 3`  Y   q“ 	   #`N "" p c … n f  
ö2a" n@” (õTn`  
8 n’  8 ne  b3 q I 6 #vN (÷8 ne  n’  (í'8 ne  ''(ğ(ß(øT(ğT(ô(Æ                    	 
 *     9     A    
 E     J    
 ~#$TQ:. B$K$M$O~#W$IB      Ù`  	   q F !  q>            ã`      C n {   
 8  qB    q D !  (û     ï`  /   !0=  b 0 Fr ¤  
 8  qJ  
 q   q K   q    b / Fr ¤  
 8 ğÿqJ  
 q   (ç       ÿ`      ¶ q E           a  H   ns  nm  n‘   b5 "6 p‡  	 n Œ C n Œ c / n Œ C 8  "6 p‡  n Œ   n Œ T n Œ  n  n Œ  n  n k 2      !a  Ÿ   
!ë=( b0 F
r ¤ Ë 
8 b0 F
r ¥ Ë   4 "< p—  !ë5µ' Fr ¡ ¸ Ø(ö!ë= b/ F
r ¤ Ë 
8 b/ F
r ¥ Ë   4 (×q K   	r£  
9 qL  (ö	C n { 	 
r¢  rŸ  
	8	= r   4 "  p ] s q E  b6 8 n k L (äb	3 q I ) (İ"	6 p‡ 	 n Œ I 8 	 n Œ  	n Œ y 	n 	 (Ü	 (ñ©(©  m     €     $y      Ÿa     b 5 Î n k        ¥a  9   !A=4 F b0 r ¤  
9
 b/ r ¤  
8! b5 "6 p‡  Í n Œ 2 n Œ   n Œ 2 n  n k !  q K   (ü       ºa      Ä q E           Âa      Æ q E      ¤              °                ¸     ¸  À              Ì                ¸      ¸                 $   ¸  %   ¸  Ô              à              ğ              ü     	       /     0     A   ¸  B   ¸  C   ¸  D   ¸  E   ¸  F   ¸  H   ¸  M   ¸  N   ¸           !      >                1 1    4      M      N      N     R             4              I      4 Q    ,            1        4    4 4    ?      N                     4    %      '      *      +      4 8    B >    N        O        -                                                %s %-8s %5d  %s
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
threadTime toHexString toString true type update value valueOf versionCode versionCodeString versionName write writer xml 	xmlTagOff yyyy-MM-dd HH:mm:ss.SSS zip zipPath 	{isValid=  ? Ó<-K ÚKKKK %  +  (    "  2Æ;i!b—‡û5–ôØ&¥L ‚O–<z ¥K].?dJ]Â .xJ  ¥%[.f==.  ¥K Y ,á^   ò Ö<*> I B£J íÏ²¶º-– ¼ ıõ¼ÿ»- …O×-”> Wõ‹ T¹ öÙ¹' _Ï\²7Ãˆ-²M¶ÄĞ×´&,-‹Ù-·´¦¿ÄèÃ€Ä–ÃÀÅ‡-âı5/Zª6Z¦ùÄúÅıÃ÷Å	û.Äø5Â
ü5_.AJ	
Ï J	'lµä	*,/Ã,m–--á"@ŸzhU) Ó< Ó[Ú€¥©G,_"¥K%Ø&iiÏOL €Z’<KKRy† $i =  A  E  Ó< Ó[Ú€‡©J,Z" ¥K% Ø&iZ’E=ÿiË5.ht† ¥1] $ ¥K i E  I  M  z  }— €  ƒ— £  §‰Š¥ ³, r Kş5Kÿ5-¤5ÒßN‡‡àN«K¥…¥†!u5 £       w y–¤!¹	°Qº
±QZ”=¢Ó¯!´î	i7A¥%‰ÓÒÒ
iUA¤ÿ“K–5­5¹ÿı5Ã‡İzJ-†‰5wiÖ-á2‡¨-{YAhw 9 J¥™-8wN¼ ğ0“i"ÒCii¨-^J ¥Z• ¥%w"ÒR-^iš # KZ œ@KÂx¶<"¦ .¸KKÂZ œ@x¶<" < ò<<<K ù;w¥¬5Ã‚LZ Ö<v x K {š<3-KK$V¥%‹0á£áÎ Œ5ë5- ‹.êZ<<KZ<<NZ\KK--itu,yZ\KK--itx,x\KK--i[{x,<><{;<><{;-/- ­   ‡ááˆxy–––––––
 ã5
 -      …ƒ,Z ÔPÖ<iíiÕ´¯>Z[ ³  ·š ”¯ ñ¯;KÈ> ƒO–¥¥‡ Ú¯Z˜IL ‚OØ&ZØ&–<[-¥$iP[[z!i¥%¥${ ¼¯í¡:PL ‚OØ&ZØ&–<[-¥$iP[ i¥;Z; [zY¥$!i¥%¥${ ¯í ı¯í‡L (ò<¥|<Kz¥ ˜¯ i¾¥‡©5K ø50´ Eò,Ò¥ ì5&ÿNZ˜CªÖ<Xw; Ò¥  ;o iNkÜNÿ–5[¯!KÏ5K¥%f" ? x 4ò<< ˆ5ÿ  œ¯  ¯ ÇéüWÇÇ$ÇéüÁÇÇ2éüÇ•£1c;Çé	üÌÇÇª1˜˜;$ñØDDD>7f$šS<ó7µ´$ÈKØ7,åæPF        €€Œ,  		          €¬,„ ğ,ˆ- -¸-Ğ-è-´1   €Ğ3	è3
€€Ü4„5¸5˜6ğ6„7ä7 €ìC „D„F¨FÀF $€œG%´GàI„JœJ  )€€äJ*üJ  +€€¸K,ĞK  -€€ŒL.¤LÁ äM  $0ˆ€ˆN€¬N
ÄN
àU	¨Z	ø[	¸]‰ä]),8€€Ø^€ô^:¨f  /;ˆ€ g€jˆ ¨j	Àj	Ğk	ìk	Œl
¬l
œm
¤o	Ìq	ğq	¤r	”s	´s
Ôt
¸w
Øw	Üx	üx                 Ô  p      S   À     N   	     7   ´     ³   l            
   ¤     B        	   œ<    "   ´=     Ô  Î>     B   ÉX        Êa        Wb         “b        pd  