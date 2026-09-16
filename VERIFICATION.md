# 검증

공개 저장소의 [빌드 및 검증](https://github.com/thlee/mdbom/actions/workflows/build.yml)에서 각 커밋의 결과와 검증 아티팩트를 확인할 수 있습니다.

- 공통: 자산 재생성 및 해시 확인
- macOS: 파일 처리, 실제 WKWebView 앱, 인쇄·PDF, 빌드 폴더 없이 앱 리소스 로딩, DMG 내용·서명·도움말 확인
- Windows: 실제 WebView2 앱, 인쇄·PDF, 설치·재설치·제거, 설정 보존 및 도움말 동봉 확인

로컬 Mac 검증은 `./Scripts/test.sh`로 실행합니다. 결과는 `.build/verification/`에 저장합니다. 설치 파일은 성공한 빌드의 산출물로 배포합니다.
