[CmdletBinding(SupportsShouldProcess)]
param([switch]$RegisterOnly)
$ErrorActionPreference = 'Stop'
$sourceExe = Join-Path $PSScriptRoot 'MarkdownViewer.exe'
if (-not $RegisterOnly -and -not (Test-Path -LiteralPath $sourceExe)) { throw 'Run Install.ps1 from the extracted release folder, beside MarkdownViewer.exe.' }
$installPath = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs\MarkdownViewer'))
$sourcePath = [IO.Path]::GetFullPath($PSScriptRoot)
$exePath = Join-Path $installPath 'MarkdownViewer.exe'
if ($RegisterOnly -and -not (Test-Path -LiteralPath $exePath)) { throw '엠디봄 is not installed.' }
if (-not $PSCmdlet.ShouldProcess($installPath, 'Install 엠디봄 for the current user and register Open With entries')) { return }
New-Item -ItemType Directory -Path $installPath -Force | Out-Null
if (-not $RegisterOnly -and $sourcePath.TrimEnd('\') -ine $installPath.TrimEnd('\')) {
    foreach ($entry in @('MarkdownViewer.exe','README.md','LICENSE','THIRD-PARTY-NOTICES.md','Install.cmd','Install.ps1','Uninstall.ps1','samples','licenses','WebView2Runtime')) {
        $sourceEntry = Join-Path $sourcePath $entry
        if (Test-Path -LiteralPath $sourceEntry) { Copy-Item -LiteralPath $sourceEntry -Destination $installPath -Recurse -Force }
    }
}

$classes = 'HKCU:\Software\Classes'
function Set-RegistryString([string]$Path, [string]$Name, [string]$Value) {
    # Registry provider New-Item -Force can recreate an existing key and erase
    # earlier values/subkeys. CreateSubKey opens it without destroying content.
    if (-not $Path.StartsWith('HKCU:\')) { throw 'Expected a current-user registry path.' }
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($Path.Substring(6))
    try {
        $valueName = if ($Name -eq '(default)') { '' } else { $Name }
        $key.SetValue($valueName, $Value, [Microsoft.Win32.RegistryValueKind]::String)
    } finally { $key.Dispose() }
}
$progid = Join-Path $classes 'MarkdownViewer.Document'
Set-RegistryString $progid '(default)' 'Markdown document'
Set-RegistryString $progid 'FriendlyTypeName' 'Markdown document'
Set-RegistryString "$progid\DefaultIcon" '(default)' ('"' + $exePath + '",0')
$command = '"' + $exePath + '" "%1"'
Set-RegistryString "$progid\shell\open\command" '(default)' $command
Set-RegistryString "$classes\Applications\MarkdownViewer.exe" 'FriendlyAppName' '엠디봄'
Set-RegistryString "$classes\Applications\MarkdownViewer.exe\shell\open\command" '(default)' $command
foreach ($extension in @('.md','.markdown')) {
    Set-RegistryString "$classes\$extension\OpenWithProgids" 'MarkdownViewer.Document' ''
    Set-RegistryString "$classes\Applications\MarkdownViewer.exe\SupportedTypes" $extension ''
    Set-RegistryString 'HKCU:\Software\MarkdownViewer\Capabilities\FileAssociations' $extension 'MarkdownViewer.Document'
}
Set-RegistryString 'HKCU:\Software\MarkdownViewer\Capabilities' 'ApplicationName' '엠디봄'
Set-RegistryString 'HKCU:\Software\MarkdownViewer\Capabilities' 'ApplicationDescription' 'A local, read-only Markdown reader.'
Set-RegistryString 'HKCU:\Software\RegisteredApplications' '엠디봄' 'Software\MarkdownViewer\Capabilities'
$registeredKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\RegisteredApplications', $true)
try {
    foreach ($legacy in @('MarkdownViewer','Markdown Viewer')) {
        if ($registeredKey.GetValue($legacy) -eq 'Software\MarkdownViewer\Capabilities') { $registeredKey.DeleteValue($legacy, $false) }
    }
} finally { $registeredKey.Dispose() }

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Programs')) '엠디봄.lnk'))
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = $installPath
$shortcut.IconLocation = $exePath + ',0'
$shortcut.Description = 'Read Markdown documents locally'
$shortcut.Save()
$legacyShortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'Markdown Viewer.lnk'
if (Test-Path -LiteralPath $legacyShortcut) {
    if ($shell.CreateShortcut($legacyShortcut).TargetPath -ieq $exePath) { Remove-Item -LiteralPath $legacyShortcut -Force }
}
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class MarkdownViewerShellNotify { [DllImport("shell32.dll")] public static extern void SHChangeNotify(uint e, uint f, IntPtr a, IntPtr b); }'
[MarkdownViewerShellNotify]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
Write-Output ('Installed: ' + $exePath)
Write-Output 'To enable double-click: right-click a .md file > Open with > Choose another app > 엠디봄 > Always. Repeat for .markdown. Existing defaults were preserved.'
Write-Output ('To uninstall, run: powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $installPath 'Uninstall.ps1') + '"')
