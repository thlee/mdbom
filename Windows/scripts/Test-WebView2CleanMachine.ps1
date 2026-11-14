[CmdletBinding()]
param([Parameter(Mandatory)][string]$Installer)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or $env:RUNNER_OS -ne 'Windows') {
    throw 'This test may only run in a disposable GitHub-hosted Windows runner.'
}
$Installer = (Resolve-Path -LiteralPath $Installer).Path
$report = Join-Path $env:GITHUB_WORKSPACE 'dist\webview2-clean-machine'
New-Item -ItemType Directory -Path $report -Force | Out-Null
. (Join-Path $PSScriptRoot '..\Packaging\Ensure-WebView2.ps1')
$roots = @("${env:ProgramFiles(x86)}\Microsoft\EdgeWebView\Application", "$env:ProgramFiles\Microsoft\EdgeWebView\Application", "$env:LOCALAPPDATA\Microsoft\EdgeWebView\Application")
Get-Process msedgewebview2 -ErrorAction SilentlyContinue | Stop-Process -Force
foreach ($root in $roots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    foreach ($setup in Get-ChildItem -LiteralPath $root -Filter setup.exe -Recurse) {
        # Only Microsoft EdgeWebView's own uninstaller is permitted here.
        if (-not $setup.FullName.StartsWith([IO.Path]::GetFullPath($root) + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected uninstaller path' }
        $args = '--uninstall --msedgewebview --verbose-logging --force-uninstall'
        if (-not $root.StartsWith($env:LOCALAPPDATA)) { $args += ' --system-level' }
        $p = Start-Process -FilePath $setup.FullName -ArgumentList $args -WindowStyle Hidden -PassThru -Wait
        Write-Output "WebView2 uninstaller exit: $($p.ExitCode)"
    }
}
function Assert-NoRuntime {
    if (Test-WebView2Runtime) { throw 'Runtime remains registered; refusing to simulate a missing runtime.' }
    foreach ($root in $roots) {
        if ((Test-Path -LiteralPath $root) -and @(Get-ChildItem -LiteralPath $root -Recurse -Filter msedgewebview2.exe).Count -gt 0) {
            throw "Runtime binary remains in $root"
        }
    }
}
Assert-NoRuntime
Write-Output 'Confirmed absent: registry and actual Evergreen runtime executables.'
@{runtimeRegistered=$false;runtimeExecutables=0} | ConvertTo-Json | Set-Content (Join-Path $report 'before.json')
# Fail the real bootstrapper download without changing the installer or removing runner networking.
$rules = @()
try {
    foreach ($shell in @("$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe", "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe")) {
        $name = 'MDBom-WebView2-offline-' + [guid]::NewGuid().ToString('N')
        New-NetFirewallRule -Name $name -DisplayName $name -Direction Outbound -Action Block -Program $shell -Profile Any | Out-Null
        $rules += $name
    }
    $log = Join-Path $report 'offline.log'
    $p = Start-Process -FilePath $Installer -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG=`"$log`"" -WindowStyle Hidden -PassThru
    if (-not $p.WaitForExit(240000)) { throw 'Offline setup did not finish' }
    if ($p.ExitCode -eq 0) { throw 'Offline setup unexpectedly succeeded' }
    Assert-NoRuntime
    if (Test-Path "$env:LOCALAPPDATA\Programs\MarkdownViewer\MarkdownViewer.exe") { throw 'App was installed despite prerequisite failure' }
    if ((Get-Content -LiteralPath $log -Raw) -notmatch 'WebView2 setup') { throw 'Prerequisite failure was not logged' }
    Write-Output "Offline failure handled, exit $($p.ExitCode)."
} finally { foreach ($name in $rules) { Remove-NetFirewallRule -Name $name } }
# Allow the filtering platform to observe rule removal before retrying.
Start-Sleep -Seconds 10
Assert-NoRuntime
# Real network, real Microsoft bootstrapper, actual installation and lifecycle checks.
& (Join-Path $PSScriptRoot 'Test-Installer.ps1') -Installer $Installer -VerifyRuntimeInstall -ReportDirectory $report
if (-not (Test-WebView2Runtime)) { throw 'Runtime disappeared during app lifecycle' }
@{passed=$true;initialRuntimeAbsent=$true;offlineFailure=$true;onlineRetry=$true;runtimeInstalled=$true;appLifecycle=$true} |
    ConvertTo-Json | Set-Content (Join-Path $report 'results.json')
