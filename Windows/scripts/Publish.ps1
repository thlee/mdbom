[CmdletBinding()]
param(
    [ValidateSet('win-x64','win-arm64')][string]$Runtime = 'win-x64',
    [ValidatePattern('^8\.0\.\d+$')][string]$RuntimeVersion = '8.0.31',
    [switch]$FrameworkDependent,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\artifacts\MDBom-win-x64')
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
$selfContained = if ($FrameworkDependent) { 'false' } else { 'true' }
dotnet publish (Join-Path $projectRoot 'src\MarkdownViewer\MarkdownViewer.csproj') -c Release -r $Runtime --self-contained $selfContained "-p:RuntimeFrameworkVersion=$RuntimeVersion" "-p:NuGetLockFilePath=packages.publish.$Runtime.lock.json" -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -p:PublishTrimmed=false -o $outputPath
if ($LASTEXITCODE -ne 0) { throw 'Publishing failed.' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md'),(Join-Path $projectRoot 'LICENSE'),(Join-Path $projectRoot 'THIRD-PARTY-NOTICES.md') -Destination $outputPath
Copy-Item -LiteralPath (Join-Path $projectRoot 'samples') -Destination $outputPath -Recurse -Force
foreach ($name in @('Install.ps1','Uninstall.ps1','Install.cmd')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $outputPath -Force }
New-Item -ItemType Directory -Path (Join-Path $outputPath 'licenses') -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $projectRoot '..\ThirdPartyLicenses') -File | Copy-Item -Destination (Join-Path $outputPath 'licenses') -Force
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'licenses') -File | Copy-Item -Destination (Join-Path $outputPath 'licenses') -Force
if (-not $FrameworkDependent) {
    $assetsPath = Join-Path $projectRoot 'src\MarkdownViewer\obj\project.assets.json'
    $assets = Get-Content -LiteralPath $assetsPath -Raw | ConvertFrom-Json
    foreach ($packageFolder in $assets.packageFolders.PSObject.Properties.Name) {
        $runtimePackage = Join-Path $packageFolder "microsoft.netcore.app.runtime.$Runtime\$RuntimeVersion"
        if (Test-Path -LiteralPath $runtimePackage) {
            Copy-Item -LiteralPath (Join-Path $runtimePackage 'LICENSE.TXT') -Destination (Join-Path $outputPath 'licenses\LICENSE-dotnet.txt') -Force
            Copy-Item -LiteralPath (Join-Path $runtimePackage 'THIRD-PARTY-NOTICES.TXT') -Destination (Join-Path $outputPath 'licenses\THIRD-PARTY-NOTICES-dotnet.txt') -Force
        }
        $desktopLicense = Join-Path $packageFolder "microsoft.windowsdesktop.app.runtime.$Runtime\$RuntimeVersion\LICENSE"
        if (Test-Path -LiteralPath $desktopLicense) { Copy-Item -LiteralPath $desktopLicense -Destination (Join-Path $outputPath 'licenses\LICENSE-WindowsDesktop.txt') -Force }
    }
}
Get-ChildItem -LiteralPath $outputPath -Filter 'Microsoft.Web.WebView2.*.xml' | Remove-Item -Force
Copy-Item -LiteralPath (Join-Path $projectRoot '..\HELP.md') -Destination (Join-Path $outputPath 'HELP.md') -Force
Write-Output ('Published to ' + $outputPath)
