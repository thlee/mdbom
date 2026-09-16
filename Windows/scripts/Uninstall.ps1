[CmdletBinding(SupportsShouldProcess)]
param([switch]$RegistrationOnly)
$ErrorActionPreference = 'Stop'
$programsRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs')).TrimEnd('\')
$installPath = [IO.Path]::GetFullPath((Join-Path $programsRoot 'MarkdownViewer')).TrimEnd('\')
# Verify the absolute deletion target is the exact dedicated app directory.
if ($installPath -ine ($programsRoot + '\MarkdownViewer') -or (Split-Path $installPath -Leaf) -ine 'MarkdownViewer') { throw 'Unexpected installation directory.' }
$exePath = Join-Path $installPath 'MarkdownViewer.exe'
$expectedCommand = '"' + $exePath + '" "%1"'
if (-not $PSCmdlet.ShouldProcess($installPath, 'Remove 엠디봄 program files and its own Open With registrations')) { return }
# Delegate setup-managed installations to their tracked uninstaller.
$setupUninstaller = Join-Path $installPath 'unins000.exe'
if (-not $RegistrationOnly -and (Test-Path -LiteralPath $setupUninstaller)) {
    Start-Process -FilePath $setupUninstaller
    return
}
$classes = 'HKCU:\Software\Classes'
$registered = (Get-ItemProperty -LiteralPath "$classes\MarkdownViewer.Document\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
if ($registered -and $registered -cne $expectedCommand) { throw 'File association belongs to a different installation. Uninstall from that location instead.' }
if (Get-Process MarkdownViewer -ErrorAction SilentlyContinue) { throw 'Close 엠디봄 before uninstalling.' }
foreach ($extension in @('.md','.markdown')) {
    Remove-ItemProperty -LiteralPath "$classes\$extension\OpenWithProgids" -Name 'MarkdownViewer.Document' -ErrorAction SilentlyContinue
}
foreach ($key in @("$classes\MarkdownViewer.Document", "$classes\Applications\MarkdownViewer.exe", 'HKCU:\Software\MarkdownViewer')) {
    if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
}
Remove-ItemProperty -LiteralPath 'HKCU:\Software\RegisteredApplications' -Name 'MarkdownViewer' -ErrorAction SilentlyContinue
Remove-ItemProperty -LiteralPath 'HKCU:\Software\RegisteredApplications' -Name '엠디봄' -ErrorAction SilentlyContinue
Remove-ItemProperty -LiteralPath 'HKCU:\Software\RegisteredApplications' -Name 'Markdown Viewer' -ErrorAction SilentlyContinue
foreach ($shortcutName in @('엠디봄.lnk','Markdown Viewer.lnk')) {
    $shortcutPath = Join-Path ([Environment]::GetFolderPath('Programs')) $shortcutName
    if (Test-Path -LiteralPath $shortcutPath) {
        $shell = New-Object -ComObject WScript.Shell
        if ($shell.CreateShortcut($shortcutPath).TargetPath -ieq $exePath) { Remove-Item -LiteralPath $shortcutPath -Force }
    }
}
if (-not $RegistrationOnly -and (Test-Path -LiteralPath $exePath)) {
    $resolvedTarget = (Resolve-Path -LiteralPath $installPath).Path.TrimEnd('\')
    if ($resolvedTarget -ine $installPath -or ((Get-Item -LiteralPath $installPath).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Unsafe installation directory.' }
    Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
}
Write-Output '엠디봄 removed. Preferences and WebView2 profile are retained under %LOCALAPPDATA%\MarkdownViewer. You may remove that folder separately.'
