# 검증

## HTML 하단 스크롤 수정 — 2026-09-28

Windows 실제 WebView2 통합 검사 **237/237 통과**. 내보낸 HTML의 루트에 단일 문서 레이아웃을 지정해 분할 UI의 `overflow:hidden` 규칙이 적용되지 않도록 수정했습니다. 네 가지 보기의 HTML을 앱 화면과 분리된 WebView2에 로드하고 800px·390px 창에서 긴 문서의 스크롤 허용과 마지막 문단 도달을 확인했습니다. 이전처럼 레이아웃 속성을 제거하면 스크롤이 막히는 음성 대조군도 검사했습니다. 이는 별도 WebView2에서의 검증이며 Safari·Chrome 등의 독립 브라우저 수동 확인 및 Mac 실행 검증을 대신하지 않습니다.

공개 저장소의 [빌드 및 검증](https://github.com/thlee/mdbom/actions/workflows/build.yml)에서 각 커밋의 결과와 검증 아티팩트를 확인할 수 있습니다.

- 공통: 자산 재생성 및 해시 확인
- macOS 검사 구성: 파일 처리, 실제 WKWebView 앱, 인쇄·PDF, HTML 내보내기, 빌드 폴더 없이 앱 리소스 로딩, DMG 내용·서명·도움말 확인
- Windows 검사 구성: 실제 WebView2 앱, 인쇄·PDF, HTML 내보내기, 설치·재설치·제거, 설정 보존 및 도움말 동봉 확인

로컬 Mac 검증은 `./Scripts/test.sh`로 실행합니다. 결과는 `.build/verification/`에 저장합니다. 설치 파일은 성공한 빌드의 산출물로 배포합니다.

수식·다이어그램 검증은 `Shared/Renderer/Resources/Tests/rich-content.js`를 두 실제 웹 엔진에서 실행합니다. 인라인/블록 MathML, 코드·달러 기호 보존, 잘못된 수식, 로컬 SVG 로딩과 스크립트 비실행, 흐름도·시퀀스 그림, 잘못되거나 제한된 Mermaid 원문 유지, 네 가지 화면 모드의 PDF 출력을 확인합니다. 검증 아티팩트에 `rich-light.png`, `rich-dark-split.png`, `print-*.pdf`를 포함합니다.

## HTML 내보내기 개발 빌드 — 2026-09-27

[PR #4](https://github.com/thlee/mdbom/pull/4)의 Windows 자체 포함 x64 빌드는 실제 WebView2 통합 검사 **217/217**을 통과했습니다. 네 가지 보기에서 네이티브 이미지 읽기와 공통 HTML 생성 경로를 실행해 본문만 포함되는지, 스타일·이미지가 내장되는지, MathML·다이어그램 원문·테마가 유지되는지, 앱 내부 링크와 외부 스타일·스크립트가 없는지 검사했습니다. 결과에 `export-reading.html`, `export-source.html`, `export-horizontal.html`, `export-vertical.html`을 생성합니다.

이후 HTML 아이콘을 인쇄 왼쪽으로 옮긴 변경은 공통 자산 해시 검사와 Windows 빌드를 확인했습니다. 전체 217개 검사를 다시 실행한 결과로 표현하지 않습니다.

Mac 내보내기 검사는 구현했으나 이 기록 시점에 실행 성공을 확인하지 못했습니다. [해당 CI 실행](https://github.com/thlee/mdbom/actions/runs/36292032685)은 마지막 확인 당시 대기 중이었습니다. 별도 브라우저에서 내보낸 파일의 시각적 확인과 실제 저장 대화상자의 취소·덮어쓰기·오류 동작도 확인이 남아 있습니다. 자동 검사 통과는 이 수동 검증을 대신하지 않으며 정식 1.0 배포 완료를 뜻하지 않습니다.
