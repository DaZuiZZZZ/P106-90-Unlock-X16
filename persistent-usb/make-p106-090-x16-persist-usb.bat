@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
title Make P106-090 persistent PCIe Gen2 x16 USB
cd /d "%~dp0"

set "TEMPLATE=%~dp0usb-template"
set "SHELL_SRC=%TEMPLATE%\EFI\BOOT\BOOTX64.EFI"
set "EFI_SRC=%TEMPLATE%\NVPermissiveEFI.efi"
set "SHELL_SHA=4922D9885AC92D8AB58E5DA4EB8AD6CBFBE651EA9CDC03A1BA67355E5EDE83B1"
set "EFI_SHA=18BC4A2DA2C03F4E86139CF6B62C4C37EB28D6697FB16114724FF238E592EF5A"
set "ALLOW_FIXED=0"
if /I "%~1"=="--allow-fixed" set "ALLOW_FIXED=1"
set "FIXED_ARG="
if "%ALLOW_FIXED%"=="1" set "FIXED_ARG=-AllowFixed"

echo ============================================================
echo   P106-090 persistent PCIe Gen2 x16 USB builder
echo ============================================================
echo.
echo This script copies the UEFI Shell, NVPermissive EFI and an
echo auto-start script to an existing FAT32 USB drive.
echo It does NOT format or partition the drive.
echo.

if not exist "%TEMPLATE%\" (
    echo [ERROR] USB template directory not found:
    echo         %TEMPLATE%
    pause
    exit /b 1
)
if not exist "%SHELL_SRC%" goto missing_file
if not exist "%EFI_SRC%" goto missing_file
if not exist "%TEMPLATE%\startup.nsh" goto missing_file

echo [1/4] Verifying template hashes...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$a=@(@('%SHELL_SRC%','%SHELL_SHA%'),@('%EFI_SRC%','%EFI_SHA%')); $bad=$false; foreach($p in $a){$h=(Get-FileHash -Algorithm SHA256 -LiteralPath $p[0]).Hash; if($h -ne $p[1]){Write-Host ('[BAD] '+$p[0]);$bad=$true}else{Write-Host ('[OK]  '+$p[0])}}; if($bad){exit 1}"
if errorlevel 1 (
    echo.
    echo [ERROR] Template integrity check failed.
    pause
    exit /b 2
)

echo.
set "DRIVE="
set /p "DRIVE=Enter FAT32 USB drive letter (for example F): "
if not defined DRIVE goto bad_drive
set "DRIVE=%DRIVE: =%"
set "DRIVE=%DRIVE::=%"
set "DRIVE=%DRIVE:\=%"
if not "%DRIVE:~1%"=="" goto bad_drive

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\check-usb-volume.ps1" -DriveLetter "%DRIVE%" %FIXED_ARG%
if errorlevel 1 (
    echo.
    echo [ERROR] Target volume check failed.
    pause
    exit /b 3
)

set "ROOT=%DRIVE%:"
echo.
echo Target: %ROOT%\
echo Files to create/overwrite:
echo   \EFI\BOOT\BOOTX64.EFI
echo   \NVPermissiveEFI.efi
echo   \startup.nsh
echo   \README-FIRST.txt
echo.
choice /C YN /N /M "Copy the persistent UEFI boot files to this USB? [Y/N] "
if errorlevel 2 (
    echo Cancelled.
    pause
    exit /b 0
)

echo.
echo [2/4] Copying persistent UEFI files...
robocopy "%TEMPLATE%" "%ROOT%\." /E /R:1 /W:1 /NFL /NDL /NJH /NJS
if errorlevel 8 (
    echo.
    echo [ERROR] File copy failed.
    pause
    exit /b 4
)

echo.
echo [3/4] Verifying files on the USB...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$a=@(@('%ROOT%\EFI\BOOT\BOOTX64.EFI','%SHELL_SHA%'),@('%ROOT%\NVPermissiveEFI.efi','%EFI_SHA%')); $bad=$false; foreach($p in $a){$h=(Get-FileHash -Algorithm SHA256 -LiteralPath $p[0]).Hash; if($h -ne $p[1]){Write-Host ('[BAD] '+$p[0]);$bad=$true}else{Write-Host ('[OK]  '+$p[0])}}; if($bad){exit 1}"
if errorlevel 1 (
    echo.
    echo [ERROR] USB verification failed.
    pause
    exit /b 5
)

echo.
echo [4/4] Persistent USB is ready.
echo ============================================================
echo   Set this USB as the first UEFI boot device.
echo   On every boot it will run:
echo.
echo     NVPermissiveEFI.efi pcie-gen2-x16
echo.
echo   then automatically start Windows Boot Manager.
echo   Secure Boot must be disabled.
echo ============================================================
echo.
pause
exit /b 0

:bad_drive
echo.
echo [ERROR] Enter one drive letter only, for example F.
pause
exit /b 6

:missing_file
echo.
echo [ERROR] Required USB template file is missing.
echo         Re-extract the complete project package.
pause
exit /b 7
