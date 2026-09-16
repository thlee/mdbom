[CmdletBinding()]
param([Parameter(Mandatory)][string]$Installer)
$ErrorActionPreference = 'Stop'
$Installer = (Resolve-Path -LiteralPath $Installer).Path
$install = Join-Path $env:LOCALAPPDATA 'Programs\MarkdownViewer'
$preferences = Join-Path $env:LOCALAPPDATA 'MarkdownViewer'
# This destructive lifecycle test is intended only for a disposable CI account.
if ((Test-Path $install) -or (Test-Path $preferences)) { throw 'Use a clean, disposable account for installer lifecycle testing.' }
function Run-Setup([string]$Path) {
    $p = Start-Process -FilePath $Path -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -PassThru -WindowStyle Hidden
    if (-not $p.WaitForExit(120000)) { throw 'Setup timed out.' }
    if ($p.ExitCode -ne 0) { throw "Setup failed: $($p.ExitCode)" }
}
function Assert-Installed {
    if (-not (Test-Path "$install\HELP.md")) { throw 'Bundled Markdown help missing.' }
    if (-not (Test-Path "$install\MarkdownViewer.exe")) { throw 'App missing.' }
    $registered = Get-ItemProperty 'HKCU:\Software\Classes\Applications\MarkdownViewer.exe'
    if ($registered.FriendlyAppName -ne '엠디봄') { throw 'Open With registration missing.' }
    foreach ($ext in @('.md','.markdown')) {
        $key = Get-Item "HKCU:\Software\Classes\$ext\OpenWithProgids"
        if ('MarkdownViewer.Document' -notin $key.GetValueNames()) { throw "Missing association: $ext" }
    }
    if (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) '엠디봄.lnk'))) { Get-ChildItem (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs') -Force | Select-Object Name,FullName | Format-List | Out-Host
        & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "[Environment]::GetFolderPath('Programs')"
        Write-Output ([Environment]::GetFolderPath('Programs'))
        throw 'Shortcut missing.' }
    $entry = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{5BD21D30-930D-42C2-AC90-784E20CBB98A}_is1'
    $productVersion = (Get-Item "$install\MarkdownViewer.exe").VersionInfo.ProductVersion
    if ($entry.DisplayVersion -ne $productVersion) { throw 'Installer display version differs from app product version.' }
    if ($entry.DisplayName -notlike '엠디봄*') { throw 'Installed Apps entry missing.' }
}
Run-Setup $Installer
Assert-Installed
New-Item -ItemType Directory -Path $preferences -Force | Out-Null
$sentinel = Join-Path $preferences 'installer-preservation-test.txt'
Set-Content $sentinel 'preserve settings and profile'
$hash = (Get-FileHash $sentinel).Hash
Run-Setup $Installer
Assert-Installed
if ((Get-FileHash $sentinel).Hash -ne $hash) { throw 'Reinstall changed preferences.' }
Run-Setup (Join-Path $install 'unins000.exe')
if (Test-Path "$install\MarkdownViewer.exe") { throw 'Uninstall left executable.' }
if (Test-Path 'HKCU:\Software\Classes\Applications\MarkdownViewer.exe') { throw 'Uninstall left Open With entry.' }
if (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{5BD21D30-930D-42C2-AC90-784E20CBB98A}_is1') { throw 'Uninstall entry remains.' }
if ((Get-FileHash $sentinel).Hash -ne $hash) { throw 'Uninstall removed preferences.' }
if (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) '엠디봄.lnk')) { throw 'Uninstall left shortcut.' }
if (Test-Path 'HKCU:\Software\MarkdownViewer') { throw 'Uninstall left capabilities.' }
$apps = Get-Item 'HKCU:\Software\RegisteredApplications'
if ('엠디봄' -in $apps.GetValueNames()) { throw 'Uninstall left registered application.' }
Write-Output 'Installer lifecycle passed: install, re-install, associations, uninstall, preference preservation.'
