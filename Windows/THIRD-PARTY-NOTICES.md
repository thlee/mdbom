# Third-party components

The Windows and macOS apps embed the same offline renderer built from the root package-lock.json. Runtime JavaScript licenses are in the repository's ThirdPartyLicenses directory and the Windows release's licenses directory.

| Component | Version | License |
| --- | --- | --- |
| markdown-it | 15.0.2 | MIT |
| DOMPurify | 3.4.15 | Apache-2.0 OR MPL-2.0 |
| highlight.js | 11.12.0 | BSD-3-Clause |
| Microsoft.Web.WebView2 SDK | 1.0.4191.47 | Microsoft WebView2 SDK terms |
| .NET Windows Desktop Runtime | 8.0.31 (self-contained release) | MIT and included third-party notices |

The shared manifest at Shared/Renderer/Resources/Web/dependencies.json records all bundled transitive dependencies and hashes. Complete license texts for markdown-it's dependencies, WebView2 SDK and the bundled .NET runtimes ship with the release.

WebView2 Runtime is a separate Microsoft component and is not included in the portable ZIP. The stylesheet is original GitHub-inspired CSS. No CDN or remote fonts are used.
