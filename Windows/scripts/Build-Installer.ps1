[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PublishDirectory,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\artifacts\installer'),
    [string]$CompilerPath = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
)
$ErrorActionPreference = 'Stop'
$publish = (Resolve-Path -LiteralPath $PublishDirectory).Path
$exe = Join-Path $publish 'MarkdownViewer.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Publish the self-contained win-x64 app first.' }
if (-not (Test-Path -LiteralPath $CompilerPath)) { throw 'Install Inno Setup 6.3+ or specify -CompilerPath.' }
$output = [IO.Path]::GetFullPath($OutputDirectory)
$version = [version](Get-Item -LiteralPath $exe).VersionInfo.FileVersion
$releaseVersion = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion
if ($releaseVersion -notmatch '^\d+\.\d+\.\d+(-beta\.\d+)?$') { throw 'Unexpected product version.' }
New-Item -ItemType Directory -Path $output -Force | Out-Null
& $CompilerPath "/DPublishDir=$publish" "/DOutputDir=$output" "/DReleaseVersion=$releaseVersion" (Join-Path $PSScriptRoot '..\Packaging\MDBom.iss')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
$installer = Join-Path $output "MDBom-$releaseVersion-Setup-x64.exe"
$hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($installer))" | Set-Content -LiteralPath "$installer.sha256" -Encoding ascii
Write-Output $installer
