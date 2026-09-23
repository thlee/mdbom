# 개발 안내

## 코드 위치

- `macOS/`: Swift Package, 앱 코드, 파일 처리 검사, 패키징 및 Mac 전용 도구
- `Windows/`: WPF 프로젝트, 설치 및 Windows 전용 도구
- `Shared/Renderer/`: 공통 렌더러·스타일·검증 자산과 Swift 리소스 패키지
- `Scripts/`: 공통 웹 자산 생성·검사, 기존 Mac 명령 진입점

Xcode에서는 `macOS/Package.swift`를 엽니다. 두 플랫폼 모두 저장소 전체를 받아서 개발합니다. 루트의 기존 빌드 명령은 계속 사용할 수 있습니다.

## 개발 환경

- macOS 빌드: Apple Silicon Mac, macOS 14 이상
- macOS 빌드: Xcode 15 이상 또는 Apple Command Line Tools
- Windows 빌드: Windows 10/11, .NET 8 SDK, WebView2 Runtime
- Windows 설치 EXE 패키징: Inno Setup 6.3 이상
- 웹 자산 변경 시에만 Node.js와 npm 필요

```bash
./Scripts/build-app.sh
open "dist/엠디봄.app"
./Scripts/test.sh
```

Windows에서는 `Windows/MarkdownViewer.sln`을 빌드하고 `Windows/scripts/Publish.ps1`로 배포본을 만듭니다. 실행 검증은 배포 폴더에서 `MarkdownViewer.exe --smoke-test <절대 결과 폴더>`를 실행합니다. 상세 절차는 [Windows/README.md](Windows/README.md)를 참고하세요.

웹 렌더러를 수정한 경우 먼저 `npm ci --ignore-scripts`와 `npm run bundle`을 실행합니다. 공통 `core.js`·`markdown.css`, macOS 연결용 `viewer.js`, `dependencies.json`, `package-lock.json`, 라이선스도 함께 커밋합니다. `node Scripts/check-assets.mjs`와 두 운영체제의 검증을 실행합니다. GitHub Actions가 재번들의 재현성, 두 플랫폼의 실제 웹 엔진 검사, Mac DMG 및 Windows 설치 EXE의 생성·검증을 실행합니다. 번들 자산만으로 렌더링하며 Windows 최초 NuGet 복원에는 인터넷이 필요합니다.

## 변경 작업

1. `git pull --ff-only`로 최신 내용을 받습니다.
2. `git switch -c feature/작업이름`으로 작업 브랜치를 만듭니다.
3. 관련 코드를 수정하고 해당 플랫폼 검사를 실행합니다. 공통 렌더러 변경은 두 플랫폼 검사가 필요합니다. 문서만 바꿀 때는 코드와 명령·경로·링크 일치를 확인합니다.
4. UI 변경은 예제 문서를 열어 파일 열기, 검색, 확대, 라이트·다크 표시를 확인합니다.
5. `CHANGELOG.md`의 Unreleased에 사용자에게 영향을 주는 변경을 기록합니다.
6. 커밋·push 후 GitHub Pull Request로 변경 내용을 검토합니다.

UI를 바꿀 때는 `ARCHITECTURE.md`의 공통 화면 구성에 따라 두 운영체제에 함께 반영합니다. 도구 패널 구성과 명령은 `workspace.js`, 폭 기본값·프리셋과 호스트용 라벨은 `interface.json`, 문서/소스 화면 스타일은 `presentation.css`에서 관리합니다. 각 운영체제의 메인 창·폭 팝업·소스 화면 캡처를 확인합니다.

## 유지해야 하는 원칙

- 읽기 전용: 원본 Markdown을 변경하거나 저장하지 않습니다.
- 오프라인: 렌더링에 CDN·서버·원격 폰트를 요구하지 않습니다.
- 네이티브: macOS는 SwiftUI/AppKit/WKWebView, Windows는 WPF/WebView2 구조를 유지합니다.
- 공통 렌더러는 `Shared/Renderer`에만 둡니다. 운영체제별 파서·정리 로직을 별도로 만들지 않습니다.
- HTML 정리, 네트워크 차단, 로컬 파일 경로 제한을 유지합니다.
- 실행 파일·빌드 캐시·node_modules는 Git에 넣지 않습니다.

## 배포

기능 버전을 올릴 때는 `macOS/Packaging/Info.plist`와 `Windows/src/MarkdownViewer/MarkdownViewer.csproj`를 함께 확인하고 변경 이력 및 사용자 문서를 갱신합니다. 현재 표시 버전은 `1.0.0-beta.4`입니다. Mac의 `MDBomDisplayVersion`과 Windows의 `Version`을 맞춥니다. OS용 숫자 버전(Mac `CFBundleShortVersionString`, Windows `FileVersion`)은 별도로 관리하고 빌드 번호는 증가시킵니다. 도움말의 버전 표기도 함께 갱신합니다. 버전 번호를 변경하지 않은 패키징·문서 작업은 Unreleased로 기록합니다.

저장소 루트에서 Mac은 `./Scripts/package-dmg.sh`, Windows는 `Publish.ps1` 후 `Build-Installer.ps1`을 실행합니다. 정확한 명령과 선행 도구는 각 플랫폼 README에 있습니다. Windows 설치 검사는 기존 앱·설정이 없는 일회용 계정에서만 `Test-Installer.ps1`로 실행합니다.

GitHub Actions는 PR·main push·수동 실행에서 빌드하고 아래 아티팩트를 제공합니다.

- `MDBom-macOS-arm64`: Mac 앱 ZIP, 버전별 DMG와 SHA-256
- `MDBom-win-x64`: Windows 자체 포함 배포 폴더
- `MDBom-Windows-Setup-x64`: 버전별 설치 EXE와 SHA-256
- `macOS-verification`, `Windows-verification`: 실행 검사 결과

GitHub Releases 자동 게시나 앱 자체 업데이트 다운로드는 구현하지 않았습니다. 새 설치 파일을 실행하거나 Mac 앱을 교체하여 업데이트합니다. Windows 설치 EXE는 미서명이고 Mac은 로컬 ad-hoc 서명입니다. 외부 배포용 코드 서명·Developer ID 공증은 별도로 준비해야 합니다.

## README 언어 관리

README.md는 영어 기본 문서이고 README.ko.md는 한국어 문서입니다. README.en.md는 기존 링크 호환용 안내 문서로 유지합니다. 버전·다운로드 링크·지원 기능·제한·빌드 명령이 바뀌면 두 문서를 함께 갱신합니다. 언어 전환 링크는 두 문서 상단에 유지합니다. 영어 README 추가는 앱 UI나 내장 도움말의 언어 변경을 의미하지 않습니다.
