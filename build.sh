#!/bin/bash
#
# ASUS G15 2021 DSDT suspend patch
# https://github.com/foundObjects/GA503QR-StorageD3Enable-DSDT-Patch
# TODO: gitlab link here
#
# inspired by https://github.com/r0l1/razer_blade_14_2016_acpi_fix
#

set -euo pipefail

exists() { for f; do type -P "$f" &>/dev/null || return 1; done; }
msg() { echo "==>" "$@"; }
msg2() { echo "-->" "$@"; }
error() { echo "==> $(basename "$0") ln ${BASH_LINENO[0]} [ERROR]:" "$@" >&2; }
fatal() { echo "==> $(basename "$0") ln ${BASH_LINENO[0]} [FATAL]:" "$@" >&2 && exit 1; }

datadir="$(dirname "$(realpath "$0")")"
temptoken="ga503qr-dsdt-patch"
imagename="GA503QR-ACPI-Override.img"
outimage="${datadir}/${imagename}"

for prog in iasl patch cpio; do
  exists $prog || fatal "$prog not found in path, aborting"
done

# cleanup build files
cleanup() {
  # validate that cleanup dir matches our pattern
  if [[ -d "$1" ]] && [[ "$1" =~ ^/tmp/${temptoken} ]]; then
    msg 'Removing temporary files'
    rm -rf "$1"
  fi
}

# create a working directory
# shellcheck disable=SC2064
tempd="$(mktemp -dp '/tmp' ${temptoken}.XXXX)" && trap "cleanup $tempd" EXIT 

msg "Processing DSDT"

# extract dsdt as root
msg2 "Extracting DSDT as root"
[[ "$EUID" -eq '0' ]] || sudo -v || fatal "This script requires root permissions to extract the DSDT."
# shellcheck disable=SC2024/
sudo cat "/sys/firmware/acpi/tables/DSDT" > "$tempd/DSDT.dat"

# decompile
msg2 "Decompiling"
iasl -d "$tempd"/*.dat

# patch
msg2 "Patching DSDT, if this fails your BIOS may have a table newer than the included patch"
patch -d "$tempd" -bNp1 -i "${datadir}/GA503QR-BIOS410-DSDT-Enable.patch"

# compile
msg2 "Compiling DSDT"
iasl -ve -tc "${tempd}/DSDT.dsl"

# construct our initramfs
msg "Constructing initramfs image"
mkdir -p "$tempd/kernel/firmware/acpi"
cp "${tempd}/DSDT.aml" "${tempd}/kernel/firmware/acpi"
cd "$tempd"
find kernel | cpio -H newc --create > "$outimage"

msg2 "Finished; image: $outimage"

while true; do
  echo -n "Copy image to /boot? [N/y] : "
  read yn
  case "$yn" in
    [Yy]*)
      msg "Installing image to /boot"
      sudo install -v -o root -m 0655 --backup --suffix=".backup" "$outimage" "/boot/${imagename}"
      break
      ;;
    [Nn]*|"") break ;;
  esac
done

