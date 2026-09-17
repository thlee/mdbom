# 공통 코어와 운영체제별 앱

기준 저장소는 https://github.com/thlee/mdbom 하나입니다.

운영체제별 코드는 `macOS/`와 `Windows/`, 공통 렌더링 코드는 `Shared/Renderer/`에 둡니다. `macOS/Package.swift`는 공통 렌더러 폴더의 로컬 Swift 패키지를 참조하고, Windows 프로젝트는 같은 폴더의 웹 자산을 임베딩합니다. 공통 자산을 플랫폼 폴더에 복제하지 않습니다. 루트 `Scripts`에는 공통 자산 도구와 기존 Mac 명령을 유지하는 진입 스크립트만 둡니다.

```text
Shared/Renderer/renderer.js                 공통 파서·HTML 정리·체크리스트·코드 강조
Shared/Renderer/Resources/Web/core.js       라이브러리를 포함한 생성 번들
Shared/Renderer/Resources/Web/markdown.css  공통 본문·표·코드 스타일
Shared/Renderer/Resources/Web/presentation.css  시작·문서·소스 화면 스타일
Shared/Renderer/Resources/Web/interface.json    호스트 라벨·폭 프리셋/기본값/범위
                   ├── RendererAssets SwiftPM 리소스 → macOS WKWebView
                   └── .NET EmbeddedResource       → Windows WebView2
```

두 앱은 같은 `core.js`, `markdown.css`, `presentation.css`, `interface.json` 파일을 그대로 패키징합니다. 소스 복사본을 따로 관리하지 않습니다. `package-lock.json`과 `ThirdPartyLicenses`도 공통입니다. 앱 빌드에는 Node.js가 필요 없으며, 이미 커밋된 자산으로 오프라인 렌더링합니다.

`npm run bundle`은 공통 원본과 macOS 화면 연결 코드를 각각 번들로 만듭니다. `node Scripts/check-assets.mjs`는 번들·스타일 해시를 검사합니다. GitHub Actions에서는 다시 생성한 결과가 커밋과 같은지도 확인합니다.

## 공통 API

문서 시작의 닫힌 YAML 헤더는 `front_matter` 블록 토큰으로 처리합니다. YAML을 실행하거나 객체로 역직렬화하지 않고, 정리된 `details` 안에 이스케이프한 텍스트로 표시합니다. 접힌 상태가 기본이며 원래 줄 번호는 유지합니다. 원문의 메타데이터 줄에서 읽기로 전환하면 해당 정보 영역을 펼쳐 위치를 맞춥니다.

`MarkdownViewerCore.render(markdown, options)`는 정리된 `DocumentFragment`를 반환합니다. 문서 내용을 DOM에 넣기 전에 markdown-it → highlight.js → DOMPurify → 제한된 이미지·링크·클래스·앵커 처리 순서로 실행합니다. `showSource(element, markdown)`는 원문을 HTML로 해석하지 않고 `textContent`로 넣습니다.

호스트가 전달하는 옵션은 로컬 문서의 기준 URL, 지원하는 이미지 확장자, 제목 ID 접두사입니다. macOS는 `mdviewer://document/`, Windows는 문서마다 토큰이 있는 내부 HTTPS 주소를 사용합니다. 실제 파일 접근 권한과 경로 제한은 각 네이티브 호스트에서 다시 검사합니다.

## 운영체제별 부분

`createPositionSync(reading, source)`는 두 보기의 상단 내용을 연결합니다. 렌더링 후 `load()`, 전환 전에 `capture(view)`, 숨김 상태를 변경한 뒤 `restore(position, view)`를 호출합니다. `position.js`는 markdown-it의 블록 원문 범위와 실제 문자 위치를 연결하므로 화면 높이 비율에 의존하지 않습니다. 원문의 CRLF와 코드 강조 span, 서로 다른 본문 폭을 처리합니다. 문법 기호나 보이지 않는 HTML은 가까운 표시 내용으로 이동하며 문서 끝에서는 가능한 스크롤 범위로 제한됩니다.

위치 표시는 렌더링마다 임의 식별자로 생성한 뒤 HTML 정리 후 WeakMap으로 옮기고 DOM에서는 제거합니다. 문서가 제공한 속성을 위치 정보로 신뢰하지 않습니다. 원문은 계속 단일 텍스트 노드이며 수정·저장하지 않습니다. 두 엔진의 명시적 자체 검증 모드가 같은 `Resources/Tests/scroll-sync.js`를 실행합니다.

| 영역 | macOS | Windows |
| --- | --- | --- |
| 창·메뉴·파일 열기 | SwiftUI / AppKit | C# / WPF |
| 웹 엔진 | WKWebView | WebView2 |
| 화면 연결 | `macOS/WebSource/renderer.js` | `Windows/src/MarkdownViewer/Assets/viewer.js` |
| 파일·설정·연결 프로그램 | Swift / Info.plist | C# / Inno Setup + 설치 PowerShell |
| 폭 조절 UI | 공통 웹 패널 | 동일 |
| 소스 보기 UI | ⌘U, 읽기 전용 | Ctrl+U, 읽기 전용 |
| 테마 UI | 시스템 → 라이트 → 다크 | 동일 |
| 메인 도구막대 | 공통 웹 패널, 네이티브 명령 연결 | 동일 |
| 하단 | 상태, 읽기 전용, 축소·100%·확대 | 동일 |

공통 코어 변경은 두 앱에 적용됩니다. 네이티브 메뉴·설정 UI의 기능 추가는 해당 운영체제 코드에도 반영해야 합니다. macOS 앱은 Mac에서, Windows 앱은 Windows에서 빌드하며, 두 운영체제의 실행 파일 자체를 공유하지는 않습니다.

## UI 일관성 유지

`Shared/Renderer/workspace.js`가 양쪽 앱의 떠 있는 도구 패널, 폭 팝업, 분할 배치, 구분선, 숨김 동작, 스크롤 이벤트 조정을 소유합니다. 기존 SwiftUI/WPF 상단 도구 패널은 제거했습니다. 네이티브 호스트는 파일·설정·테마·전체화면 명령을 처리하며, 화면은 제한된 문자열 명령만 전달합니다. 사용자 문서는 기존 HTML 정리를 거쳐 별도 문서 요소에만 렌더링합니다.

`createPositionSync`는 기본으로 창 스크롤을 사용하지만 분할 화면에서는 각 패널의 스크롤 컨테이너와 상단 좌표를 사용합니다. 한쪽의 프로그램적 스크롤은 반대쪽에 다시 전파하지 않도록 프레임 단위로 억제합니다. `Resources/Tests/workspace.js`는 두 실제 웹 엔진에서 같은 동작 검사를 실행합니다.

기본 도구 모드는 always이며 auto에서도 DOM 패널은 동일합니다. 표시되는 순간 문서 레이아웃을 변경하지 않도록 fixed overlay를 사용합니다. Windows WebView2의 네이티브 자식 창 위에 WPF 컨트롤을 겹치는 문제도 피합니다. OS 창 장식, 하단 상태/확대, Mac 검색 UI는 네이티브로 남습니다.

공통 UI 값은 `interface.json`에서 관리합니다. 새 작업은 공통 패널에 추가하고 필요한 OS 명령만 각 호스트에 구현합니다. 기본 본문 폭은 920px, 소스 폭은 1200px, 슬라이더 범위는 600–1800px/20px입니다. 기존 폭 설정은 유지합니다.

검색은 `Shared/Renderer/search.js`에서 두 플랫폼이 공유합니다. 결과 캐시는 검색어와 활성 패널을 함께 기준으로 삼습니다. `positionForRange`가 검색 Range의 시작 문자를 원문 위치로 연결하고, `revealMatch`는 양쪽 패널 중앙 부근에 해당 위치를 표시합니다. 명시적 검색 이동은 일반 스크롤 연결 해제 상태에서도 양쪽에 적용하며, 이동 이벤트의 되먹임은 억제합니다. 숨김 설정은 auto로 이전되고 UI에는 always/auto만 노출합니다.

## 외부 파일 변경

파일 감시는 네이티브 호스트가 담당합니다. Mac의 `DocumentRefresh`는 utility 큐에서, Windows는 창 수명에 연결된 타이머와 비동기 파일 읽기로 처리합니다. 500ms 간격으로 경로의 수정 시각·크기·파일 식별 정보를 확인하고 두 번 연속 같은 변경 정보일 때 제한된 읽기를 실행합니다. 변경 없는 파일은 내용을 반복해서 읽지 않습니다. 읽기 전후 변경 정보를 비교하고 실패한 읽기는 다음 주기에 재시도합니다. 파일을 바꾸거나 창을 닫으면 이전 결과를 무시합니다.

공통 `workspace.captureViewport/restoreViewport`는 각 창의 원문 위치와 주변 문맥을 저장합니다. 갱신 후 문맥이 유일하게 남아 있으면 이동된 원문 위치를 따라가고, 그렇지 않으면 기존 위치를 범위 안으로 제한합니다. 복원 중 스크롤 연결 이벤트는 억제합니다. 자동 갱신과 수동 새로고침 모두 같은 복원 경로를 사용합니다.

## 인쇄

공통 도구바의 `print` 명령을 Mac은 WKWebView의 `printOperation(with:)`, Windows는 WebView2의 `ShowPrintUI(Browser)`에 연결합니다. 화면과 동일한 정리된 DOM을 공통 `@media print` 스타일로 출력하며, 소스·도구 패널은 포함하지 않습니다. Mac은 인쇄 창이 열린 동안 화면 갱신을 보류하고 끝나면 위치를 복원한 뒤 보류된 문서 변경을 반영합니다. 테스트는 실제 출력 엔진의 PDF 저장 경로를 사용하며 물리 프린터에 전송하지 않습니다.

## 설치와 업데이트

Windows의 `Packaging/MDBom.iss`는 사용자별 고정 설치 위치 `%LOCALAPPDATA%\Programs\MarkdownViewer`와 안정적인 AppId로 업그레이드합니다. Inno Setup이 설치 파일·시작 메뉴 바로가기·제거 항목을 추적하고, 기존 `Install.ps1 -RegisterOnly`가 파일 연결과 이름 이전을 담당합니다. 제거 시 `Uninstall.ps1 -RegistrationOnly`로 등록만 해제한 뒤 설치 엔진이 추적한 파일을 제거합니다. 사용자 설정과 기본 앱 선택은 설치가 덮어쓰지 않습니다.

`Build-Installer.ps1`는 빌드한 EXE의 버전으로 설치 파일명과 SHA-256을 생성합니다. WebView2 Evergreen Runtime 등록을 설치 전에 확인하며, 누락 시 안내 후 중단합니다. ZIP 배포의 선택적 Fixed Version Runtime과 별개로 설치 EXE는 Evergreen 등록을 요구합니다. CI의 설치 수명주기 검사는 일회용 사용자 환경에서 수행합니다.

Mac은 `macOS/Scripts/package-dmg.sh`가 앱과 Applications 링크를 묶어 DMG를 만들고 다시 마운트하여 검증합니다. 패키징은 앱 자체 버전을 변경하지 않습니다.

## 수식과 다이어그램

`rich-content.js`는 Markdown 토큰 단계에서 수식을 인식합니다. KaTeX는 외부 리소스를 허용하지 않는 MathML 출력으로 동기 변환하고, 별도 DOMPurify 인스턴스로 정리합니다. Mermaid는 strict 모드에서 직렬 비동기 렌더링하며 생성된 SVG를 정리해 이미지로 넣습니다. 일반 본문의 SVG 태그는 여전히 허용하지 않습니다. 로컬 SVG 파일은 네이티브 이미지 요청 경로로만 엽니다.

어댑터는 다이어그램 이미지 준비 후 원문 위치와 스크롤을 복원합니다. 원래 코드 블록의 위치 표시는 유지하고 코드 자체는 접을 수 있는 details에 남깁니다. Windows 인쇄는 현재 렌더링 완료를 기다리며 Mac은 렌더링 중 인쇄를 시작하지 않습니다. 의존성 라이선스 목록은 esbuild의 실제 포함 모듈에서 생성합니다.
