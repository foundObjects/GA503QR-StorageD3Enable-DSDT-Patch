#!/bin/bash
#
# ASUS G15 2021 DSDT suspend patch
# https://github.com/foundObjects/GA503QR-StorageD3Enable-DSDT-Patch
# https://gitlab.com/smbruce/GA503QR-StorageD3Enable-DSDT-Patch
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
temptoken="ga503q-dsdt-patch"
imagename="GA503Q-ACPI-Override.img"
outimage="${datadir}/${imagename}"

for prog in iasl patch cpio; do
  exists $prog || fatal "$prog not found in path, aborting"
done

# create a working directory and clean it up on script exit
# shellcheck disable=SC2064
tempd="$(mktemp -dp '/tmp' ${temptoken}.XXXX)" &&
  # validate that cleanup dir matches our pattern
  trap '[[ -d "$tempd" ]] && [[ "$tempd" =~ ^/tmp/${temptoken} ]] && msg2 "Removing temporary files..." && rm -rf "$tempd"' EXIT

# extract dsdt as root
msg2 "Extracting DSDT as root"
[[ "$EUID" -eq '0' ]] || sudo -v || fatal "This script requires root permissions to extract the DSDT."
# shellcheck disable=SC2024
sudo cat "/sys/firmware/acpi/tables/DSDT" > "$tempd/DSDT.dat"

# decompile
msg2 "Decompiling"
iasl -d "$tempd"/*.dat

# patch
msg2 "Patching DSDT..."
patch -d "$tempd" -bNp1 -i "${datadir}/GA503Q-BIOS410-DSDT-Enable.patch" ||
  fatal "Patching failed! Your BIOS may be newer than the patch included in the repo or you may already have patched your DSDT."

# compile
msg2 "Compiling DSDT"
iasl -ve -tc "${tempd}/DSDT.dsl"

# construct our initramfs
msg2 "Creating initramfs image"
mkdir -p "$tempd/kernel/firmware/acpi"
cp "${tempd}/DSDT.aml" "${tempd}/kernel/firmware/acpi"
cd "$tempd"
find kernel | cpio -H newc --create > "$outimage"

msg2 "Finished; image: $outimage"

while true; do
  echo -n "Copy image to /boot? [y/N] : "
  read yn
  case "$yn" in
    [Yy]*)
      msg2 "Installing image to /boot"
      sudo install -v -o root -m 0655 --backup --suffix=".backup" "$outimage" "/boot/${imagename}"
      break
      ;;
    [Nn]*|"") break ;;
  esac
done

