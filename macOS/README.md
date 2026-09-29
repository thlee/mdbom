# 엠디봄 · MDBom — macOS 1.0

[정식 설치 파일](https://github.com/thlee/mdbom/releases/tag/v1.0.0) · [사용설명서](../HELP.md)

SwiftUI / AppKit + WKWebView로 만든 Apple Silicon용 읽기 전용 Markdown 앱입니다. Windows와 같은 렌더러·도구 패널을 사용합니다. [공통 사용법](../README.md), [개발 절차](../CONTRIBUTING.md), [검증 기록](../VERIFICATION.md)을 참고하세요.

## 바로 실행하기

1. `MDBom-<버전>-macOS-arm64.dmg`를 엽니다.
2. **엠디봄.app**을 DMG 안의 **Applications** 폴더로 끌어 넣습니다. 업데이트할 때는 실행 중인 앱을 먼저 종료하고 교체합니다. 기존 설정은 유지됩니다.
3. 설치 디스크를 추출한 뒤 응용 프로그램 폴더의 앱을 열고 **Open** 또는 **⌘O**로 `.md` / `.markdown` 파일을 선택합니다. 창이나 Dock 아이콘에 파일을 끌어 놓아도 됩니다.

**요구 환경:** Apple Silicon(M1 이상), macOS 14 Sonoma 이상. Node.js·Homebrew·Xcode는 완성된 앱을 실행할 때 필요 없습니다.

이 앱은 로컬에서 ad-hoc 서명한 빌드이며, Apple Developer ID 서명·공증은 되어 있지 않습니다. 다른 Mac으로 전송한 뒤 macOS가 실행을 차단하면 이 소스로 해당 Mac에서 빌드할 수 있습니다. 소스 빌드 절차는 아래를 참고하세요.

### GitHub Actions 자동 생성

PR·main 업데이트 또는 Actions의 **Run workflow** 실행 시 앱 검증 후 DMG와 ZIP을 함께 생성하도록 구성되어 있습니다. 성공한 실행의 **MDBom-macOS-arm64** 아티팩트를 내려받으면 DMG와 SHA-256 파일이 들어 있습니다. 저장소는 공개이며 일반 사용자는 로그인 없이 [Releases의 설치 파일](https://github.com/thlee/mdbom/releases)을 받을 수 있습니다.

Actions는 비활성화 상태이며 로컬에서 검증한 빌드를 Releases에 게시합니다. 자동 릴리즈 게시·앱 자체 업데이트 다운로드는 구현하지 않았습니다. DMG 포장은 Developer ID 서명·공증을 대신하지 않습니다.

### Finder 더블클릭 연결

한 번만 열려면 파일을 우클릭하여 **다음으로 열기 → 엠디봄**를 선택합니다. 목록에 없으면 **기타…**에서 앱을 선택합니다.

항상 이 앱으로 열려면 Finder에서 `.md` 파일 선택 → **정보 가져오기(⌘I)** → **다음으로 열기: 엠디봄** → **모두 변경…**을 선택합니다. 필요하면 `.markdown` 파일에도 반복합니다. 앱은 사용자의 기존 기본 앱 설정을 자동으로 바꾸지 않습니다.

## 공통 화면과 HTML 내보내기

Windows와 같은 도구바에서 문서·소스·좌우·상하 보기, 스크롤 연결, 폭·글꼴, 검색·테마·전체화면을 조절합니다. 읽기와 소스를 전환할 때 상단의 같은 원문 위치를 최대한 유지합니다. 외부 편집기의 저장은 자동 반영합니다. **⌘P** 또는 **File → Print…**로 본문을 인쇄하거나 PDF로 저장합니다.

1.0에는 **인쇄 아이콘 바로 왼쪽의 HTML로 내보내기**와 **File → Export HTML…**가 추가됩니다. 저장 창에서 `.html` 파일의 이름과 위치를 선택하세요. 어느 보기에서든 현재 테마·문서 폭·글꼴로 본문만 저장하며 원본 Markdown은 변경하지 않습니다.

스타일·수식·Mermaid·로컬 이미지를 한 파일에 포함합니다. 최신 브라우저에서 오프라인으로 열 수 있고 시스템 글꼴에 따라 모양이 달라질 수 있습니다. 로컬 Markdown 링크는 비활성화하며 누락된 이미지는 오류로 안내합니다. 이미지 제한은 개별 20 MiB, 합계 100 MiB입니다. 자세한 설명은 [도움말](../HELP.md#html로-내보내기)을 참고하세요.

## 소스에서 빌드

Swift Package Manager 프로젝트입니다. 웹 자산이 이미 포함되어 있어 **빌드와 실행 모두 오프라인으로 가능**합니다. 처음 개발 도구를 설치할 때만 인터넷이 필요합니다.

### Command Line Tools로 빌드

```bash
# 개발 도구가 없을 때 한 번 실행
xcode-select --install

# 저장소 루트(macOS 폴더의 상위 폴더)에서 실행
./Scripts/build-app.sh
open "dist/엠디봄.app"

# Finder/Open With와 같은 방식으로 예제 열기
open -a "$PWD/dist/엠디봄.app" "$PWD/Examples/Welcome.md"
```

`dist/엠디봄.app`이 생성됩니다. 빌드 스크립트는 ARM64 release 실행 파일, Info.plist, 아이콘, SwiftPM 리소스 번들, 라이선스를 하나의 앱으로 묶고 로컬 서명을 합니다. 프로젝트 경로에 공백이 있어도 작동합니다. 캐시는 프로젝트의 `.build/macOS`에 저장합니다.

출력 위치를 바꾸려면 `./Scripts/build-app.sh /원하는/폴더`를 사용합니다.

### Xcode에서 열기

Xcode 15 이상에서 `macOS/Package.swift`를 열고 **MarkdownViewer** executable scheme과 **My Mac**을 선택하면 코드를 빌드·실행할 수 있습니다. Finder 파일 연결이 필요한 최종 `.app`은 위 빌드 스크립트로 만듭니다. `.xcodeproj` 없이 Xcode가 직접 여는 Swift Package입니다.

Mac 패키지는 `../Shared/Renderer`를 로컬 의존성으로 사용합니다. 저장소 전체를 받아야 하며 `macOS` 폴더만 복사하면 공통 자산이 빠집니다. 기존 루트 `Scripts` 명령과 `macOS/Scripts`의 직접 실행 모두 지원합니다. 앱 빌드 캐시는 `.build/macOS`, 검증 결과는 `.build/verification`, 배포 파일은 `dist`에 저장합니다.


## 검증 및 폴더

저장소 루트에서 `./Scripts/test.sh`를 실행합니다. 파일 처리 검사와 실제 WKWebView 검사를 실행하며, 로그인된 macOS 그래픽 세션이 필요합니다. 결과와 화면은 `.build/verification`에 저장됩니다. DMG는 `./Scripts/package-dmg.sh`로 생성하고 다시 마운트하여 검사합니다.

`macOS/Package.swift`는 `../Shared/Renderer`를 참조합니다. 이 폴더만 복사하지 말고 저장소 전체를 받으세요. `macOS/Scripts` 직접 실행과 루트 `Scripts` 진입 명령을 모두 지원합니다.

문서는 최대 10 MiB, 로컬 이미지는 최대 20 MiB입니다. UTF-8 및 BOM이 있는 UTF-16 LE/BE를 읽습니다. Mac용 실행 파일은 ARM64이며 Intel 빌드는 제공하지 않습니다.
