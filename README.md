
The 2021 ASUS ROG Zephyrus G15 (GA503Q models) ships with a broken ACPI DSDT table that will prevent s0ix suspend/resume
from completing successfully. This script will extract and patch your DSDT and repack it into an initramfs that you can
include during boot.

## Installing:

Clone this repo and run `build.sh`, then copy the finished ramdisk image to /boot and add it to your kernel command line
as shown on the Arch wiki like so:

```
[arglebargle@arch-zephyrus]$ cat /boot/loader/entries/30-linux-mainline.conf 
title Linux Mainline
linux /vmlinuz-linux-mainline
initrd /amd-ucode.img
initrd /GA503Q-ACPI-Override.img
initrd /initramfs-linux-mainline.img
...
```

See the Arch wiki for instructions for other bootloaders.

### Resources:
* https://wiki.archlinux.org/title/DSDT#Recompiling_it_yourself
* https://wiki.archlinux.org/title/DSDT#Using_a_CPIO_archive
* https://docs.microsoft.com/en-us/windows-hardware/design/component-guidelines/power-management-for-storage-hardware-devices-intro#d3-support

## How to make your own:

Go here: https://wiki.archlinux.org/title/DSDT#Recompiling_it_yourself and follow the steps to dump and decompile your
DSDT.


Patch the NVM2 device as below (copy the stanza setting up StorageD3Enable from the functional NVME device just below
it) and increment the DSDT revision in the header by 1 so the kernel will load it from the ramdisk we'll make later.
The revision is a hexidecimal value so go punch the original into a hex -> decimal calculator, add 1 and then convert
back to hex; this final hex value is your new revision.

Your changes should look something like this:

```diff
diff --git a/DSDT.dsl b/DSDT.dsl
index cdc8a5d..e407904 100644
--- a/DSDT.dsl
+++ b/DSDT.dsl
@@ -18,7 +18,7 @@
  *     Compiler ID      "INTL"
  *     Compiler Version 0x20190509 (538510601)
  */
-DefinitionBlock ("", "DSDT", 2, "ALASKA", "A M I ", 0x01072009)
+DefinitionBlock ("", "DSDT", 2, "ALASKA", "A M I ", 0x0107200A)
 {
     External (_SB_.ALS_, DeviceObj)
     External (_SB_.ALS_.LUXL, UnknownObj)
@@ -12125,6 +12125,19 @@ DefinitionBlock ("", "DSDT", 2, "ALASKA", "A M I ", 0x01072009)
             {
                 TPST (0x7053)
             }
+
+            Name (_DSD, Package (0x02)  // _DSD: Device-Specific Data
+            {
+                ToUUID ("5025030f-842f-4ab4-a561-99a5189762d0") /* Unknown UUID */, 
+                Package (0x01)
+                {
+                    Package (0x02)
+                    {
+                        "StorageD3Enable", 
+                        One
+                    }
+                }
+            })
         }
 
         Scope (GPP6)
```

The version number of the table may change with subsequent BIOS releases, be sure to always increment the hex value by
one or Linux won't load your override table during boot.

Once your modifications are complete compile the AML table and build a CPIO archive (your ramdisk) as seen here:
https://wiki.archlinux.org/title/DSDT#Using_a_CPIO_archive


and finally copy the ramdisk to /boot and add it to your kernel command line as shown on the Arch wiki like so:

```
[arglebargle@arch-zephyrus]$ cat /boot/loader/entries/30-linux-mainline.conf 
title Linux Mainline
linux /vmlinuz-linux-mainline
initrd /amd-ucode.img
initrd /GA503Q-ACPI-Override.img
initrd /initramfs-linux-mainline.img
...
```

Note that the `amd-ucode.img` ramdisk *must be loaded first* before any other ramdisks otherwise boot will fail. If
there are any problems along the way the Arch Wiki DSDT page should have you covered. Good luck!

[//]: # ( vim: set tw=120: )
