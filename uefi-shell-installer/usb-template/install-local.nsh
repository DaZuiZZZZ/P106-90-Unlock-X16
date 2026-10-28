@echo -off
echo ============================================================
echo   P106-090 local EFI installer
echo ============================================================
echo
echo Searching for the Windows EFI System Partition...
echo
for %s in fs0 fs1 fs2 fs3 fs4 fs5 fs6 fs7 fs8 fs9
  if exist %s:\EFI\BOOT\BOOTX64.EFI then
    for %d in fs0 fs1 fs2 fs3 fs4 fs5 fs6 fs7 fs8 fs9
      if exist %d:\EFI\Microsoft\Boot\bootmgfw.efi then
        echo Source USB : %s
        echo Target ESP : %d
        if not exist %d:\EFI\NVPermissive then
          mkdir %d:\EFI\NVPermissive
        endif
        echo Copying UEFI files...
        cp -q %s:\EFI\BOOT\BOOTX64.EFI %d:\EFI\NVPermissive\BOOTX64.EFI > NUL
        cp -q %s:\NVPermissiveEFI.efi %d:\EFI\NVPermissive\NVPermissiveEFI.efi > NUL
        cp -q %s:\startup-esp.nsh %d:\EFI\NVPermissive\startup.nsh > NUL
        cp -q %s:\startup-esp.nsh %d:\startup.nsh > NUL
        echo Adding firmware boot entry...
        bcfg boot add 0 %d:\EFI\NVPermissive\BOOTX64.EFI "NVPermissive P106-090 x16" > NUL
      endif
    endfor
  endif
endfor
echo
echo ============================================================
echo   Installer finished.
echo   Power off, remove this USB, then boot from the new entry.
echo ============================================================
echo
