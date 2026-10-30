P106-090 persistent PCIe x16 boot
=======================================

This USB boots a UEFI Shell and automatically runs:

  NVPermissiveEFI.efi pcie-gen2-x16

The argument pcie-gen2-x16 is the NVPermissive mode name.
This project targets x16 link width, not a standalone Gen2 speed unlock.

If the width transaction succeeds, the shell then searches
fs0 through fs9 for:

  \EFI\Microsoft\Boot\bootmgfw.efi

and starts Windows Boot Manager from the first matching disk.

Requirements:

  - A 64-bit UEFI system.
  - Secure Boot disabled.
  - USB boot enabled.
  - The Windows system disk/ESP remains connected.

Set this USB as the first UEFI boot device so the sequence runs
on every cold boot. Do not remove the USB before Windows starts.

If the link does not return, power off the machine completely.
Do not use a warm reboot before retrying the experiment.
