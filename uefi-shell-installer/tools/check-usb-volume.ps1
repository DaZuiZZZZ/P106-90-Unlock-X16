param(
    [Parameter(Mandatory = $true)]
    [string]$DriveLetter,
    [switch]$AllowFixed
)

$ErrorActionPreference = 'Stop'
$d = $DriveLetter.Trim().TrimEnd(':', '\')
if ($d -notmatch '^[A-Za-z]$') {
    Write-Host '[ERROR] Enter one drive letter only, for example H.'
    exit 2
}

try {
    $v = Get-Volume -DriveLetter $d -ErrorAction Stop
}
catch {
    Write-Host ('[ERROR] Cannot read volume ' + $d + ':')
    Write-Host $_.Exception.Message
    exit 3
}

Write-Host ('Drive: ' + $d + ':')
Write-Host ('Filesystem: ' + $v.FileSystem)
Write-Host ('Type: ' + $v.DriveType)

if ($v.FileSystem -ne 'FAT32') {
    Write-Host ('[ERROR] Filesystem must be FAT32, not ' + $v.FileSystem + '.')
    exit 4
}

if ($v.DriveType -ne 'Removable' -and -not $AllowFixed) {
    Write-Host '[ERROR] Windows does not report this device as Removable.'
    Write-Host 'Use --allow-fixed only after confirming the drive letter.'
    exit 6
}

Write-Host '[OK] Target volume is valid.'
exit 0
