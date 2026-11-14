$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Packaging\Ensure-WebView2.ps1')
$installFunction = ${function:Install-WebView2Runtime}
$signatureFunction = ${function:Confirm-WebView2Signature}
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ('mdbom-webview2-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDirectory | Out-Null
$count = 0
try {
    # Dependencies are replaced only in this test process. No real runtime is removed or installed.
    function Test-WebView2Runtime { $script:probes++; return ($script:case.Existing -or ($script:probes -gt 1 -and $script:case.Registered)) }
    function Receive-WebView2Bootstrapper($Path) { $script:downloads++; if ($script:case.DownloadFailure) { throw 'offline' }; Set-Content -LiteralPath $Path 'fixture' }
    function Confirm-WebView2Signature($Path) { if ($script:case.BadSignature) { throw 'invalid signature' } }
    function Invoke-WebView2Bootstrapper($Path) { $script:launches++; if ($script:case.Timeout) { throw 'timeout' }; return $script:case.Code }
    foreach ($case in @(
        @{Name='already installed';Existing=$true;Expected=0},
        @{Name='missing runtime installed';Registered=$true;Code=0;Expected=0},
        @{Name='restart requested';Registered=$true;Code=3010;Expected=3010},
        @{Name='offline';DownloadFailure=$true;Fails=$true},
        @{Name='signature rejected';BadSignature=$true;Fails=$true},
        @{Name='installer failure';Code=1603;Fails=$true},
        @{Name='success without registration';Code=0;Fails=$true},
        @{Name='restart without registration';Code=3010;Fails=$true},
        @{Name='timeout';Timeout=$true;Fails=$true}
    )) {
        $script:case=$case; $script:probes=0; $script:downloads=0; $script:launches=0
        $failed=$false; $code=$null
        try { $code=& $installFunction $testDirectory } catch { $failed=$true }
        if ($failed -ne [bool]$case.Fails -or (-not $failed -and $code -ne $case.Expected)) { throw "Failed: $($case.Name)" }
        if (($case.Existing -and $downloads -ne 0) -or (($case.BadSignature -or $case.DownloadFailure) -and $launches -ne 0)) { throw 'Unexpected download or execution' }
        if (@(Get-ChildItem -LiteralPath $testDirectory).Count -ne 0) { throw 'Temporary bootstrapper was not removed' }
        $count++
    }
    function Get-AuthenticodeSignature { return $script:signature }
    foreach ($test in @(
        @{Status='Valid';Subject='CN=Microsoft Corporation, O=Microsoft Corporation, C=US';Accepted=$true},
        @{Status='NotSigned';Subject='O=Microsoft Corporation';Accepted=$false},
        @{Status='HashMismatch';Subject='O=Microsoft Corporation';Accepted=$false},
        @{Status='Valid';Subject='O=Other Publisher';Accepted=$false},
        @{Status='Valid';Subject='O=Microsoft Corporation Fake';Accepted=$false}
    )) {
        $script:signature=[pscustomobject]@{Status=$test.Status;SignerCertificate=[pscustomobject]@{Subject=$test.Subject}}
        $accepted=$true
        try { & $signatureFunction 'fixture.exe' } catch { $accepted=$false }
        if ($accepted -ne $test.Accepted) { throw 'Signature policy test failed' }
        $count++
    }
    Write-Output "WebView2 setup checks passed: $count"
} finally { Remove-Item -LiteralPath $testDirectory -ErrorAction SilentlyContinue }
