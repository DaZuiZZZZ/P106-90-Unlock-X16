@echo -off
echo ============================================================
echo   P106-090 local EFI installer
echo ============================================================
echo Searching for the Windows EFI System Partition...
for %s in fs0 fs1 fs2 fs3 fs4 fs5 fs6 fs7 fs8 fs9
  if exist %s:\P106-USB-MARKER.TXT then
    for %d in fs0 fs1 fs2 fs3 fs4 fs5 fs6 fs7 fs8 fs9
      if exist %d:\EFI\Microsoft\Boot\bootmgfw.efi then
        if not exist %s:\EFI\Microsoft\Boot\bootmgfw.efi then
          echo Source USB : %s
          echo Target ESP : %d
          if not exist %d:\EFI\NVPermissive then
            mkdir %d:\EFI\NVPermissive
          endif
          echo Copying UEFI files...
          cp -q %s:\EFI\BOOT\BOOTX64.EFI %d:\EFI\NVPermissive\BOOTX64.EFI
          cp -q %s:\NVPermissiveEFI.efi %d:\EFI\NVPermissive\NVPermissiveEFI.efi
          cp -q %s:\startup-esp.nsh %d:\EFI\NVPermissive\startup.nsh
          cp -q %s:\startup-esp.nsh %d:\startup.nsh
          if exist %d:\EFI\NVPermissive\BOOTX64.EFI then
            echo BOOTX64.EFI copy OK
          else
            echo ERROR: BOOTX64.EFI was not copied
          endif
          if exist %d:\EFI\NVPermissive\NVPermissiveEFI.efi then
            echo NVPermissiveEFI.efi copy OK
          else
            echo ERROR: NVPermissiveEFI.efi was not copied
          endif
          echo Adding firmware boot entry...
          bcfg boot addp 0 %d:\EFI\NVPermissive\BOOTX64.EFI "NVPermissive P106-090 x16"
          echo Current firmware boot entries:
          bcfg boot dump
        endif
      endif
    endfor
  endif
endfor
echo ============================================================
echo   Installer finished.
echo   Power off, remove this USB, then boot from the new entry.
echo ============================================================
