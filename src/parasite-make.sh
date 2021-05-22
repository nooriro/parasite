#!/usr/bin/bash
SRC="parasite-src.sh"
DEX="parasite-classes.dex"
OUT="../parasite.sh"

cd "$( dirname "$0" )"
if [ -f "$SRC" ]; then
  # Add a newline at the end of $SRC ONLY IF NOT EXISTS
  [ $( tail -c 1 "$SRC" | wc -l ) -gt 0 ] || echo >> "$SRC"
  # Count the number of lines in $SRC
  LINES_SRC="$( wc -l parasite-src.sh | cut -d " " -f 1 )"
  # $DEX starts from ( LINES_SRC + 1 )-th line
  STARTLINE="$((LINES_SRC+1))"
  # Replace plus argument of tail command in $SRC
  sed -i 's/tail -n +[0-9]* "$SCRIPT"/tail -n +'$STARTLINE' "$SCRIPT"/g' "$SRC"
else
  echo "$SRC is missing in '$PWD'" 1>&2
  exit 1
fi

# Replace hash values of $DEX in $SRC
# using extended regular expressions instead of basic regular expressions
if [ -f "$DEX" -a -f "$SRC" ]; then
  # How to calculate crc32 checksum from a string on linux bash
  # https://stackoverflow.com/questions/44804668/how-to-calculate-crc32-checksum-from-a-string-on-linux-bash/49446525#49446525
  DEX_CRC32="$(gzip < "$DEX" | tail -c8 | od -t x4 -N 4 -A n | cut -d " " -f 2)"
  DEX_MD5="$(md5sum "$DEX" | cut -d " " -f 1)"
  DEX_SHA1="$(sha1sum "$DEX" | cut -d " " -f 1)"
  DEX_SHA256="$(sha256sum "$DEX" | cut -d " " -f 1)"

  sed -ri 's/DEX_EXPECTED_CRC32="[0-9a-z]{8}"/DEX_EXPECTED_CRC32="'$DEX_CRC32'"/g' "$SRC"
  sed -ri 's/DEX_EXPECTED_MD5="[0-9a-z]{32}"/DEX_EXPECTED_MD5="'$DEX_MD5'"/g' "$SRC"
  sed -ri 's/DEX_EXPECTED_SHA1="[0-9a-z]{40}"/DEX_EXPECTED_SHA1="'$DEX_SHA1'"/g' "$SRC"
  sed -ri 's/DEX_EXPECTED_SHA256="[0-9a-z]{64}"/DEX_EXPECTED_SHA256="'$DEX_SHA256'"/g' "$SRC"
else
  echo "$DEX is missing in '$PWD'" 1>&2
  exit 2
fi

if [ -f "$SRC" -a -f "$DEX" ]; then
  cat "$SRC" "$DEX" > "$OUT"
fi
