#Requires -RunAsAdministrator
param(
    [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Template = Join-Path $PSScriptRoot "usb-template"
$ShellSrc = Join-Path $Template "EFI\BOOT\BOOTX64.EFI"
$EfiSrc = Join-Path $Template "NVPermissiveEFI.efi"
$StartupSrc = Join-Path $Template "startup.nsh"
$TargetDir = "EFI\NVPermissive"
$Description = "NVPermissive P106-090 x16"
$GuidFile = "entry-guid.txt"
$ExpectedShell = "4922D9885AC92D8AB58E5DA4EB8AD6CBFBE651EA9CDC03A1BA67355E5EDE83B1"
$ExpectedEfi = "18BC4A2DA2C03F4E86139CF6B62C4C37EB28D6697FB16114724FF238E592EF5A"

function Write-Step {
    param([string]$Message)
    Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message)
}

function Test-Administrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run this script as Administrator."
    }
}

function Get-FreeDriveLetter {
    $used = @([System.IO.DriveInfo]::GetDrives() | ForEach-Object {
        $_.Name.Substring(0, 1).ToUpperInvariant()
    })
    for ($i = 90; $i -ge 67; $i--) {
        $letter = [char]$i
        if ($used -notcontains $letter.ToString()) {
            return $letter.ToString()
        }
    }
    throw "No free drive letter is available for mounting the ESP."
}

function Mount-Esp {
    param([string]$Letter)
    $mountPoint = "${Letter}:"
    & mountvol $mountPoint /S | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "mountvol failed. Ensure this is a UEFI Windows installation."
    }
    return "$mountPoint\"
}

function Dismount-Esp {
    param([string]$Letter)
    $mountPoint = "${Letter}:"
    & mountvol $mountPoint /D | Out-Null
}

function Assert-Sha256 {
    param(
        [string]$Path,
        [string]$Expected
    )
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
    if ($actual -ne $Expected) {
        throw ("Hash mismatch for {0}: expected {1}, got {2}" -f $Path, $Expected, $actual)
    }
}

function Remove-ExistingEntry {
    param([string]$GuidFilePath)
    if (-not (Test-Path -LiteralPath $GuidFilePath)) { return }
    $old = (Get-Content -LiteralPath $GuidFilePath -Raw).Trim()
    if ($old -match "^\{[0-9a-fA-F-]{36}\}$") {
        Write-Step "Removing previous BCD entry $old"
        & bcdedit /delete $old /f | Out-Null
    }
}

function Install-NvPermissive {
    Test-Administrator

    if (-not (Test-Path -LiteralPath $ShellSrc)) { throw "Missing $ShellSrc" }
    if (-not (Test-Path -LiteralPath $EfiSrc)) { throw "Missing $EfiSrc" }
    if (-not (Test-Path -LiteralPath $StartupSrc)) { throw "Missing $StartupSrc" }

    Write-Step "Verifying template files"
    Assert-Sha256 -Path $ShellSrc -Expected $ExpectedShell
    Assert-Sha256 -Path $EfiSrc -Expected $ExpectedEfi

    $letter = Get-FreeDriveLetter
    $espRoot = Mount-Esp -Letter $letter
    Write-Step "ESP mounted at $letter"

    if (-not (Test-Path -LiteralPath (Join-Path $espRoot "EFI\Microsoft\Boot\bootmgfw.efi"))) {
        Dismount-Esp -Letter $letter
        throw "Mounted volume does not look like a Windows EFI System Partition."
    }

    $backup = Join-Path $env:TEMP ("BCD-backup-" + [DateTime]::UtcNow.ToString("yyyyMMddHHmmss") + ".bak")
    Write-Step "Backing up BCD to $backup"
    & bcdedit /export $backup | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Dismount-Esp -Letter $letter
        throw "bcdedit /export failed."
    }

    $targetDir = Join-Path $espRoot $TargetDir
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

    Write-Step "Copying UEFI files to $TargetDir"
    Copy-Item -LiteralPath $ShellSrc -Destination (Join-Path $targetDir "BOOTX64.EFI") -Force
    Copy-Item -LiteralPath $EfiSrc -Destination (Join-Path $targetDir "NVPermissiveEFI.efi") -Force
    Copy-Item -LiteralPath $StartupSrc -Destination (Join-Path $targetDir "startup.nsh") -Force

    $destShell = Join-Path $targetDir "BOOTX64.EFI"
    $destEfi = Join-Path $targetDir "NVPermissiveEFI.efi"
    Assert-Sha256 -Path $destShell -Expected $ExpectedShell
    Assert-Sha256 -Path $destEfi -Expected $ExpectedEfi

    $guidFilePath = Join-Path $targetDir $GuidFile
    Remove-ExistingEntry -GuidFilePath $guidFilePath

    Write-Step "Creating firmware boot entry"
    $bootmgr = "{bootmgr}"
    $copyOut = & bcdedit /copy $bootmgr /d $Description 2>&1
    if ($LASTEXITCODE -ne 0) {
        Dismount-Esp -Letter $letter
        throw "bcdedit /copy failed: $($copyOut -join ' ')"
    }

    $joined = $copyOut -join "`n"
    $guid = [regex]::Match($joined, "\{[0-9a-fA-F-]{8}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{12}\}").Value
    if (-not $guid) {
        Dismount-Esp -Letter $letter
        throw "Could not parse the new BCD entry GUID from: $joined"
    }

    & bcdedit /set $guid path "\$TargetDir\BOOTX64.EFI" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        & bcdedit /delete $guid /f | Out-Null
        Dismount-Esp -Letter $letter
        throw "bcdedit /set path failed."
    }

    & bcdedit /set $guid description $Description | Out-Null
    $fwbootmgr = "{fwbootmgr}"
    & bcdedit /set $fwbootmgr displayorder $guid /addfirst | Out-Null
    if ($LASTEXITCODE -ne 0) {
        & bcdedit /delete $guid /f | Out-Null
        Dismount-Esp -Letter $letter
        throw "bcdedit displayorder failed."
    }

    Set-Content -LiteralPath $guidFilePath -Value $guid -Encoding ASCII
    Dismount-Esp -Letter $letter

    Write-Step "Installed successfully."
    Write-Host ""
    Write-Host "New boot entry : $Description"
    Write-Host "GUID           : $guid"
    Write-Host "ESP files      : \$TargetDir"
    Write-Host "BCD backup     : $backup"
    Write-Host ""
    Write-Host "Reboot with Secure Boot disabled. The shell will run"
    Write-Host "NVPermissiveEFI.efi pcie-gen2-x16 and then boot Windows."
}

function Uninstall-NvPermissive {
    Test-Administrator
    $letter = Get-FreeDriveLetter
    $espRoot = Mount-Esp -Letter $letter
    $targetDir = Join-Path $espRoot $TargetDir
    $guidFilePath = Join-Path $targetDir $GuidFile

    if (Test-Path -LiteralPath $guidFilePath) {
        $guid = (Get-Content -LiteralPath $guidFilePath -Raw).Trim()
        if ($guid -match "^\{[0-9a-fA-F-]{36}\}$") {
            Write-Step "Removing boot entry $guid"
            & bcdedit /delete $guid /f | Out-Null
        }
    }

    if (Test-Path -LiteralPath $targetDir) {
        Write-Step "Removing $TargetDir"
        Remove-Item -LiteralPath $targetDir -Recurse -Force
    }

    Dismount-Esp -Letter $letter
    Write-Step "Uninstall complete. Reboot when ready."
}

try {
    if ($Uninstall) {
        Uninstall-NvPermissive
    }
    else {
        Install-NvPermissive
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
