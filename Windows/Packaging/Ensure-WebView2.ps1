[CmdletBinding()]
param([string]$WorkingDirectory = $PSScriptRoot)

$ErrorActionPreference = 'Stop'

function Test-WebView2Runtime {
    $subkey = 'Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
    foreach ($hive in @([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryHive]::CurrentUser)) {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, [Microsoft.Win32.RegistryView]::Registry32)
        $key = $null
        try {
            $key = $base.OpenSubKey($subkey)
            $version = $null
            if ($key -and [version]::TryParse([string]$key.GetValue('pv'), [ref]$version) -and $version -gt [version]'0.0.0.0') { return $true }
        } finally { if ($key) { $key.Dispose() }; $base.Dispose() }
    }
    return $false
}

function Receive-WebView2Bootstrapper([string]$Path) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $Path -TimeoutSec 90
}

function Confirm-WebView2Signature([string]$Path) {
    # A PowerShell 7 parent can pass its PSModulePath to Windows PowerShell 5.1.
    # Load this engine's inbox module instead of an incompatible parent module.
    Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or
        $signature.SignerCertificate.Subject -notmatch '(^|,\s*)O=Microsoft Corporation(,|$)') {
        throw 'The WebView2 download does not have a valid Microsoft signature.'
    }
}

function Invoke-WebView2Bootstrapper([string]$Path) {
    $process = Start-Process -FilePath $Path -ArgumentList '/silent /install' -WindowStyle Hidden -PassThru
    try {
        if (-not $process.WaitForExit(240000)) { throw 'WebView2 installation timed out. It may still be finishing; wait before retrying.' }
        return $process.ExitCode
    } finally { $process.Dispose() }
}

function Install-WebView2Runtime([string]$Directory) {
    if (Test-WebView2Runtime) { return 0 }
    $bootstrapper = Join-Path $Directory ('WebView2-' + [guid]::NewGuid().ToString('N') + '.exe')
    try {
        Receive-WebView2Bootstrapper $bootstrapper
        Confirm-WebView2Signature $bootstrapper
        $code = Invoke-WebView2Bootstrapper $bootstrapper
        if ($code -notin @(0, 3010)) { throw "Microsoft WebView2 setup failed (exit $code)." }
        if (-not (Test-WebView2Runtime)) { throw 'WebView2 is not registered after setup. Restart Windows if requested, then retry.' }
        return $code
    } finally {
        # Remove only the unique downloaded file, never shared runtime files.
        if (Test-Path -LiteralPath $bootstrapper) { Remove-Item -LiteralPath $bootstrapper -Force -ErrorAction SilentlyContinue }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { exit (Install-WebView2Runtime $WorkingDirectory) }
    catch {
        [IO.File]::WriteAllText((Join-Path $WorkingDirectory 'webview2-error.txt'), $_.Exception.Message)
        exit 1
    }
}
