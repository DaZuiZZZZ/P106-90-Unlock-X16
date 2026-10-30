@echo -off
cls
echo ============================================================
echo   P106-090 persistent PCIe x16 boot
echo ============================================================
echo
echo Running NVPermissiveEFI in x16 width mode.
echo Do not power off while this step is running.
echo
NVPermissiveEFI.efi pcie-gen2-x16
echo
echo ============================================================
echo   Searching for Windows Boot Manager.
echo ============================================================
echo
for %d in fs0 fs1 fs2 fs3 fs4 fs5 fs6 fs7 fs8 fs9
  if exist %d:\EFI\Microsoft\Boot\bootmgfw.efi then
    echo Starting Windows from %d
    %d:\EFI\Microsoft\Boot\bootmgfw.efi
  endif
endfor
echo
echo Windows Boot Manager was not found.
echo Check that the Windows ESP is still connected.
echo
