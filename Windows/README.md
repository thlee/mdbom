# 엠디봄 · MDBom — Windows 1.0 베타 4

[베타 설치 파일](https://github.com/thlee/mdbom/releases/tag/v1.0.0-beta.4) · [사용설명서](../HELP.md)

마크다운 문서를 가볍게 보다.

기존 Markdown Viewer의 새 이름입니다. 설정과 파일 연결 호환성을 위해 내부 실행 파일명·앱 식별자·설정 폴더는 유지합니다. 개발 폴더와 GitHub 저장소 주소도 그대로 사용합니다.

Windows용 가벼운 **읽기 전용 Markdown 앱**입니다. C# / .NET 8 WPF + Microsoft Edge WebView2로 만들었습니다. Electron은 사용하지 않습니다. macOS 버전과 [같은 저장소](https://github.com/thlee/mdbom)의 `Shared/Renderer` 코어 및 본문 CSS를 사용합니다.

## Windows 설치 프로그램

일반 사용자는 GitHub Actions의 **MDBom-Windows-Setup-x64** 아티팩트를 내려받아 압축을 풀고 `MDBom-<버전>-Setup-x64.exe`를 실행합니다. PR, main push 및 수동 실행 때 생성됩니다. GitHub Releases에 자동 게시하지는 않습니다.

- 현재 사용자에 설치되며 관리자 권한이 필요하지 않습니다.
- 기존 ZIP 설치와 같은 `%LOCALAPPDATA%\Programs\MarkdownViewer` 위치를 사용합니다. 설정과 기본 앱 선택을 보존하며 새 설치 파일을 다시 실행하면 업데이트됩니다.
- 시작 메뉴와 연결 프로그램에 엠디봄이 등록됩니다. 기본 앱으로 지정하려면 Windows의 ‘연결 프로그램 → 다른 앱 선택 → 항상’을 사용하세요.
- 제거: Windows 설정 → 앱 → 설치된 앱 → 엠디봄. 문서와 사용자 설정은 보존됩니다.
- WebView2 Runtime이 없으면 설치 전에 안내하고 중단합니다. [Microsoft 공식 다운로드](https://developer.microsoft.com/microsoft-edge/webview2)에서 Evergreen Runtime을 설치한 뒤 다시 실행하세요. WebView2가 있으면 앱 설치와 실행 모두 오프라인으로 가능합니다.
- 설치 EXE는 현재 코드 서명되지 않았으므로 배포 시 SmartScreen 경고가 표시될 수 있습니다.

개발자는 Inno Setup 6.3 이상을 설치한 뒤 저장소 루트에서 실행합니다. 컴파일러가 다른 위치에 있으면 `-CompilerPath <ISCC.exe 경로>`를 전달하세요.

```powershell
./Windows/scripts/Publish.ps1 -OutputDirectory dist/MDBom-win-x64
./Windows/scripts/Build-Installer.ps1 -PublishDirectory dist/MDBom-win-x64 -OutputDirectory dist/installer
```

설치 EXE와 SHA-256 파일이 `dist/installer`에 생성됩니다. 버전은 빌드한 EXE에서 가져옵니다. 빌드 입력은 자체 포함 win-x64 배포본이어야 합니다.

`Test-Installer.ps1`은 기존 앱/설정이 없는 일회용 CI 계정에서만 실행합니다. 실제 설치·재설치·제거, 바로가기·파일 연결·설정 보존을 검사하며 기존 사용자 설치가 있으면 중단합니다.

## 설치 없이 실행하기 (ZIP)

1. `MDBom-win-x64.zip`을 **폴더 전체로 압축 해제**합니다.
2. `MarkdownViewer.exe`를 실행합니다. x64 배포본에는 .NET 런타임이 포함되어 있어 .NET을 따로 설치하지 않아도 됩니다.
3. **열기…**을 누르거나 `.md` / `.markdown` 파일을 창에 드래그합니다. `samples/Welcome.md`로 먼저 살펴볼 수 있습니다.

**필수 환경:** Windows 10 22H2 또는 Windows 11 x64, Microsoft Edge **WebView2 Runtime**. 현재 Evergreen Runtime을 권장합니다. 이 앱의 파일 드롭 기능은 WebView2 124 이상을 대상으로 합니다.

WebView2 Runtime이 없으면 앱이 설치 안내를 표시합니다. [Microsoft 공식 다운로드](https://developer.microsoft.com/en-us/microsoft-edge/webview2/#download-section)에서 **Evergreen Standalone Installer / x64**를 설치하세요. 일반 Edge 브라우저 설치와 WebView2 Runtime 설치는 구분됩니다. 배포 ZIP에는 WebView2 Runtime 자체를 포함하지 않습니다.

앱 실행 파일은 코드 서명되지 않은 개인용 빌드입니다. 조직의 실행 정책에 따라 서명된 빌드가 필요할 수 있습니다.

## ZIP의 수동 등록과 더블클릭 연결

설치 없이도 실행할 수 있습니다. 시작 메뉴 및 **연결 프로그램 / Open With**에 등록하려면:

1. 압축을 푼 폴더의 `Install.cmd`를 실행합니다. 관리자 권한이 필요하지 않습니다.
2. 프로그램을 `%LOCALAPPDATA%\Programs\MarkdownViewer`에 복사하고 현재 사용자에 대해서만 확장자 및 시작 메뉴 항목을 등록합니다.
3. `.md` 파일 우클릭 → **연결 프로그램 → 다른 앱 선택 → 엠디봄 → 항상**을 선택합니다. `.markdown`도 같은 방법으로 설정합니다.
4. 이제 파일을 더블클릭하면 렌더링된 문서가 열립니다.

기존 기본 앱은 설치 스크립트가 강제로 바꾸지 않습니다. Windows의 기본 앱 선택은 사용자가 완료해야 합니다. 앱이 목록에 안 보이면 **이 PC에서 다른 앱 찾기**로 설치 폴더의 `MarkdownViewer.exe`를 선택하세요.

PowerShell로 실행하거나 변경 계획을 확인할 수도 있습니다:

```powershell
# From the extracted release folder
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -WhatIf
```

제거하려면 앱을 모두 닫고 다음 명령을 실행합니다. 프로그램 폴더와 이 앱의 등록 항목만 제거하며, 다른 앱의 연결 설정은 덮어쓰지 않습니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\Programs\MarkdownViewer\Uninstall.ps1"
```

설정과 WebView2 프로필은 `%LOCALAPPDATA%\MarkdownViewer`에 남습니다. 필요 없으면 앱을 닫은 뒤 해당 폴더를 별도로 삭제할 수 있습니다. 프로그램 설치 폴더에는 개인 문서를 보관하지 마세요.

## 공통 메인 화면

Mac과 Windows 모두 공통 떠 있는 도구 패널을 사용합니다. 파일명은 창 제목에, 상태·확대/축소는 하단에 표시합니다. 문서·소스·좌우·상하 보기, 스크롤 연결, 본문 폭, 테마, 전체화면 및 도구 고정/자동 숨김을 지원합니다. 자세한 동작은 [공통 사용법](../README.md#보기와-도구-패널)을 참고하세요.

## 지원 기능

- `.md` / `.markdown` 열기, 명령줄 경로, Open With, 파일 드래그앤드롭
- GitHub 스타일의 표, 체크리스트, 제목, 인용문, 링크, 취소선, 코드 블록
- highlight.js 공통 언어 코드 강조: C#, JavaScript, TypeScript, Python, JSON, XML/HTML, CSS, SQL 등. 알 수 없는 언어는 일반 코드로 표시
- **시스템 → 라이트 → 다크** 테마 전환 및 선택 저장
- 문서 검색과 결과 강조, 확대/축소, 파일명과 경로 표시
- **본문 폭 ▾**에서 좁게(680px)·기본(920px)·넓게(1200px) 프리셋, 폭 슬라이더(600–1800 px), **창 너비에 맞춤**, **기본 폭으로** 선택. 글자 크기는 유지하며 읽기/소스 화면의 폭을 각각 저장
- **소스 / 문서** 버튼 또는 **Ctrl+U**로 Markdown 원문과 문서 화면 전환. 원문도 읽기 전용이며 텍스트 선택·복사, 검색, 테마, 확대/축소 지원
- UTF-8 및 BOM이 있는 UTF-16/UTF-32, 한글 파일명과 본문
- 현재 문서 폴더 안의 상대 경로 PNG/JPEG/GIF/WebP/BMP/ICO 이미지
- 폴더 내부의 상대 Markdown 링크와 제목 앵커
- 원본 파일에 쓰지 않는 읽기 전용 UI. 체크박스도 읽기 전용

| 단축키 | 동작 |
| --- | --- |
| Ctrl+O | 파일 열기 |
| Ctrl+R / F5 | 디스크에서 다시 읽기 |
| Ctrl+F | 문서 검색 |
| Ctrl+U | 소스 / 문서 단독 보기 전환 |
| Ctrl+P | 문서 본문 인쇄 / PDF 저장 |
| Ctrl+Shift+H | 도구 패널 고정 / 자동 숨김 |
| F11 | 전체화면 전환 |
| Enter / Shift+Enter | 다음 / 이전 검색 결과 |
| Escape | 전체화면 종료 또는 열린 검색창·팝업 닫기 |
| Ctrl++ / Ctrl+− | 확대 / 축소 |
| Ctrl+0 | 100%로 복원 |
| Ctrl+Shift+T | 테마 전환 |

여러 파일을 명령줄로 전달하면 각각 새 창으로 열립니다. 여러 파일을 한 번에 드래그하면 첫 번째 파일을 엽니다. 외부에서 파일을 저장하면 약 1초 안팎으로 자동 반영하며 읽던 위치를 복원합니다. 이미지 파일만 바뀌면 수동으로 새로고침하세요.

소스 보기에서는 `#`, `**`, 코드 울타리, HTML 태그 등 파일의 원문을 그대로 보여 줍니다. 선택한 텍스트는 **Ctrl+C**로 복사할 수 있습니다. **Ctrl+F**는 활성 화면을 검색합니다. 분할 화면의 검색 이동은 스크롤 연결을 꺼도 양쪽을 같은 원문 위치로 맞춥니다. 읽기·소스를 전환하면 화면 상단의 같은 문단이나 코드 줄로 이동합니다. 두 보기의 폭이 달라도 원문 위치를 기준으로 맞추며, 반복 전환으로 위치가 밀리지 않습니다. 새 문서를 열면 맨 위부터 표시합니다. 자동·수동 새로고침은 주변 원문을 기준으로 읽던 위치를 최대한 유지합니다.

## 인쇄와 PDF 저장

도구 패널의 **인쇄 · PDF** 또는 **Ctrl+P**로 WebView2 인쇄 미리보기를 엽니다. 소스·분할 보기에서도 서식이 적용된 본문만 밝은 배경과 종이 폭으로 출력합니다. 미리보기에서 프린터 또는 **PDF로 저장**을 선택합니다.

## 오프라인 동작과 범위

문서 맨 앞의 `---`로 둘러싸인 YAML 메타데이터는 **문서 정보** 한 줄로 접어 표시합니다. 클릭하면 펼칠 수 있고, 소스 보기에는 전체 원문이 그대로 남습니다. 일반 구분선과 닫히지 않은 헤더는 기존대로 표시합니다.

markdown-it, DOMPurify, highlight.js, 공통 CSS는 실행 파일에 포함됩니다. 앱은 문서를 업로드하거나 분석 서비스를 호출하지 않습니다. HTML은 허용 목록으로 정리하며 스크립트, iframe, 폼, 이벤트 핸들러, 임의 스타일 등을 제거합니다. CSP와 네이티브 요청 처리에서 외부 리소스 요청을 차단합니다.

외부 이미지는 로드하지 않습니다. 사용자가 직접 누른 HTTP/HTTPS/메일 링크는 기본 브라우저 또는 메일 앱에서 열립니다. WebView2 Runtime의 시스템 업데이트는 앱의 문서 렌더링과 별개로 Microsoft가 관리합니다.

문서당 16 MiB, 로컬 이미지당 20 MiB 제한이 있습니다. 큰 코드 블록(100,000자 이상)은 강조를 생략합니다. 검색은 최대 5,000개 결과를 표시합니다. UNC/네트워크 드라이브, 심볼릭 링크/정션, 문서 폴더 밖의 이미지와 상대 링크는 지원하지 않습니다. 로컬 SVG 이미지, Mermaid 다이어그램, KaTeX 수식을 지원합니다. 본문의 SVG 태그와 Mermaid 설정·클릭·외부 리소스는 허용하지 않습니다. 자세한 문법과 제한은 [도움말](../HELP.md)을 참고하세요. HTML/CSS 전체를 그대로 실행하는 브라우저는 아닙니다.

완전히 오프라인인 PC에 처음 설치하려면 WebView2 **Standalone Installer**도 별도로 준비하세요. ZIP 배포로 실행할 때는 Microsoft의 **Fixed Version Runtime x64** 배포 파일을 해제해 `MarkdownViewer.exe` 옆 `WebView2Runtime` 폴더에 `msedgewebview2.exe`가 직접 들어가도록 배치할 수 있습니다. 설치 EXE는 Evergreen Runtime 등록을 검사하므로 Fixed Version만 준비한 환경에서는 ZIP 배포를 사용하세요. Fixed Version Runtime의 업데이트와 배포 조건은 배포자가 관리해야 합니다. [Microsoft 배포 문서](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution)를 참고하세요.

## Visual Studio에서 빌드

1. **Visual Studio 2022 17.8 이상**, **.NET 데스크톱 개발** 워크로드, **.NET 8 SDK**를 설치합니다.
2. **저장소 전체**를 받은 뒤 `Windows/MarkdownViewer.sln`을 엽니다. `Windows` 폴더 옆의 `Shared`와 `ThirdPartyLicenses`가 필요합니다.
3. NuGet 패키지 복원을 허용하고 **Release**로 빌드합니다.
4. F5로 실행합니다.

JavaScript 자산이 소스에 포함되어 있으므로 Node.js나 npm은 필요하지 않습니다. 최초 NuGet 복원에는 인터넷이 필요합니다. SDK와 패키지를 준비한 이후에는 앱 실행에 인터넷이 필요하지 않습니다.

## .NET CLI로 빌드 / 실행

저장소의 `Windows` 폴더에서:

```powershell
dotnet restore .\MarkdownViewer.sln --locked-mode
dotnet build .\MarkdownViewer.sln -c Release --no-restore
dotnet run --project .\src\MarkdownViewer\MarkdownViewer.csproj -c Release -- .\samples\Welcome.md
```

경로에 공백이 있으면 따옴표로 감쌉니다:

```powershell
.\src\MarkdownViewer\bin\Release\net8.0-windows\MarkdownViewer.exe "C:\Documents\My Notes.md"
```

일부 손상된 SDK 설치에서 `WorkloadManifest` / `Emscripten` 관련 오류가 발생하면 SDK를 복구하세요. 이 프로젝트에는 추가 워크로드가 필요 없으므로 현재 PowerShell 세션에 한해 다음 설정으로 빌드할 수도 있습니다:

```powershell
$env:MSBuildEnableWorkloadResolver = 'false'
dotnet build .\MarkdownViewer.sln -c Release
```

## x64 배포본 만들기

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Publish.ps1
```

`artifacts/MDBom-win-x64`에 .NET **8.0.31** 런타임을 포함한 단일 `MarkdownViewer.exe`와 안내/설치 파일이 생깁니다. WebView2 네이티브 로더는 단일 실행 파일에 포함되며 .NET이 최초 실행 시 사용자 임시 폴더에 추출합니다. WPF는 trimming을 사용하지 않습니다. 이후 .NET 8 보안 패치를 적용할 때는 `-RuntimeVersion 8.0.XX`로 버전을 지정하여 재배포하세요. 일반 빌드와 배포 빌드는 별도 NuGet lock 파일을 사용합니다.

이미 .NET Desktop Runtime 8이 설치된 PC를 위한 작은 배포본:

```powershell
.\scripts\Publish.ps1 -FrameworkDependent -OutputDirectory .\artifacts\MarkdownViewer-small
```

ARM64 소스 빌드도 지정할 수 있지만 제공한 릴리스와 검증은 **x64** 기준입니다:

```powershell
.\scripts\Publish.ps1 -Runtime win-arm64 -OutputDirectory .\artifacts\MarkdownViewer-win-arm64
```

## 검증

앱에는 실제 WebView2에서 실행하는 통합 검사가 포함되어 있습니다. 문서 렌더링, 한글, 표/체크리스트/코드 강조, HTML 정리, 로컬 이미지, 검색, 테마, 파일 오류, 경로 제한, 읽기 전용 동작 및 파일 드롭 브리지를 확인합니다. 분할·스크롤 연결·자동 새로고침·네 가지 보기의 PDF 출력도 검사합니다. 설치 수명주기는 별도의 `Test-Installer.ps1`로 검증합니다. [현재 검증 기록](VALIDATION.md)을 참고하세요.

```powershell
$exe = Resolve-Path .\artifacts\MDBom-win-x64\MarkdownViewer.exe
$report = Join-Path $PWD 'artifacts\smoke-report'
$process = Start-Process -FilePath $exe -ArgumentList @('--smoke-test', ('"' + $report + '"')) -WindowStyle Hidden -PassThru -Wait
$process.ExitCode
Get-Content (Join-Path $report 'results.json')
```

테스트 출력 폴더에는 결과 JSON, 앱 화면 PNG, 임시 문서, 독립 WebView2 프로필이 만들어집니다. 반환 코드 0은 모두 통과, 1은 실패입니다. 테스트 창은 잠시 표시될 수 있으며 끝나면 종료됩니다. 일반 실행 시 개발자 도구는 비활성화됩니다.

## 소스 구성

- `src/MarkdownViewer/`: WPF 창, 로컬 파일 읽기, WebView2 요청 제한, 내장 자산
- `src/MarkdownViewer/Assets/`: Windows 화면과 WebView2 연결 코드
- `../Shared/Renderer/`: macOS와 공유하는 렌더러·라이브러리·본문 CSS
- `scripts/`: 배포, 사용자별 설치/제거, 아이콘 재생성
- `samples/Welcome.md`: 예제 문서

앱 코드는 MIT 라이선스입니다. 포함 라이브러리는 `THIRD-PARTY-NOTICES.md`와 각 라이선스 파일을 참고하세요.
