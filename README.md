# MDBom · 엠디봄

**English** | [한국어](README.ko.md)

A lightweight way to read Markdown.

**Current beta: 1.0.0-beta.4 (1.0 Beta 4).** MDBom is a read-only Markdown viewer for macOS and Windows. Both apps share a renderer, document styles, and toolbar, with native window and file handling on each platform. Bundled assets enable offline rendering without Electron or a separate server.

This is a personal open-source project, not an official application of the Rural Development Administration of Korea.

## Install and update

[**Download 1.0 Beta 4**](https://github.com/thlee/mdbom/releases/tag/v1.0.0-beta.4) · [**User guide (Korean)**](HELP.md)

| Platform | Installer | Installation |
| --- | --- | --- |
| Windows 10 22H2 / 11 x64 | [Setup EXE](https://github.com/thlee/mdbom/releases/download/v1.0.0-beta.4/MDBom-1.0.0-beta.4-Setup-x64.exe) | Run the downloaded installer |
| macOS 14 or later · Apple Silicon | [DMG](https://github.com/thlee/mdbom/releases/download/v1.0.0-beta.4/MDBom-1.0.0-beta.4-macOS-arm64.dmg) | Drag the app to Applications |

SHA-256 checksum files accompany the installers. The app includes a Markdown user guide, accessible through the **Help (?)** toolbar button. Public release downloads do not require a GitHub login.

Development builds are available from successful [GitHub Actions](https://github.com/thlee/mdbom/actions/workflows/build.yml) runs. Artifacts include `MDBom-Windows-Setup-x64`, `MDBom-macOS-arm64`, and the portable `MDBom-win-x64` folder. Releases are published from selected, verified builds rather than automatically.

- **Windows:** Installs for the current user and includes the .NET runtime. If WebView2 Runtime is missing, setup displays instructions and stops. Run a newer installer to update while preserving the installation location and preferences. Uninstall through Windows **Installed apps**.
- **Mac:** Quit the running app, then replace it in Applications. Preferences are preserved.
- Neither platform overrides your default app choice. See the platform guides for double-click file associations.
- Windows installers are unsigned. The Mac app uses ad-hoc signing and is not Developer ID notarized.

[Windows installation, file associations, and build guide (Korean)](Windows/README.md) · [macOS installation, file associations, and build guide (Korean)](macOS/README.md)

This English README documents the existing app; it does not change the language of the app interface or the bundled Korean help.

## Features

- Open `.md` and `.markdown` files through file dialogs, Open With, and drag and drop; show the filename in the window
- GitHub-style text, tables, read-only task lists, and syntax highlighting for fenced code blocks
- Document and source views, side-by-side and stacked layouts, and scrolling linked by source position
- Separate width settings for each view, zoom, search, and system/light/dark themes
- Pinned or auto-hiding toolbar and fullscreen
- Automatic refresh after external edits, with reading-position restoration
- Print the formatted document or save it as PDF
- Leading YAML metadata shown in a collapsed **Document information** section

MDBom has no editing or saving features, and task-list checkboxes cannot be changed. Source view supports selecting and copying the original text. Switching between source and document views keeps the same paragraph or code line near the top where possible. Hidden syntax and the end of a document map to the nearest available display position.

## Printing and PDF

Open a document and choose **Print / PDF** in the toolbar, or press **⌘P on Mac / Ctrl+P on Windows**. On Mac, **File → Print…** also works. Choose paper size, orientation, and page range in the print dialog. Use **PDF → Save as PDF** on Mac or the **Save as PDF** destination in the Windows preview.

Only the **formatted document** is printed, even in source-only or split views. The toolbar, search controls, and source pane are excluded. Printing uses a light background and fits the paper width independently of the on-screen width setting. Long code lines and table cells wrap; landscape paper can help with very wide tables. The app opens the print dialog, and you choose whether to print or save.

## Automatic refresh

Saving an open Markdown file in another editor updates the view in **about one second**. This is enabled by default and never writes to the original file. The app periodically checks file metadata and reads the contents only when a change is detected.

Reading positions are restored in document, source, and both split layouts. If text is inserted earlier in the file, nearby content is used to keep your place where possible. If the paragraph itself is deleted or substantially changed, the view may move to a nearby position. Layout, width, and zoom settings are preserved.

Editors that save by replacing the file are supported. If the file temporarily disappears or cannot be read, the last displayed content remains until the same path becomes readable again. Saving identical content does not trigger a redraw. Only the open Markdown file is monitored; use **Refresh** if only a linked image changes.

## Width and fonts

The **Width** and **Font** toolbar buttons open separate panels. Click the same button again, click outside, or press Esc to close a panel. Opening one closes the other. Both panels provide separate controls for document and source views.

- **Width:** Narrow, default, wide, a 600–1800 px slider, and fit to window
- **Font:** System default, sans-serif, serif, or monospace; size from 12–28 px
- Settings are saved separately for each view. **Reset to defaults** resets only the settings in that panel.

## Views and toolbar

Both apps use the **same floating toolbar**. It is pinned by default and groups file actions, view buttons, display settings, and the pin control. Selected view and scroll-link states are visible. The filename appears in the window title.

- **Document / Source / Side-by-side / Stacked:** Source remains read-only and supports copying and searching. It appears on the left in side-by-side mode and above the document in stacked mode.
- **Split ratio:** Drag the divider, or focus it and use the arrow keys. Home restores 50:50. The supported range is 20–80%.
- **Linked scrolling:** Split panes follow corresponding source positions in both directions. Turn off the link button to scroll independently. **Search navigation aligns both panes to the matched source position even when linked scrolling is off.** Hidden syntax, HTML, and the document end map to nearby visible content.
- **Width / Font:** Adjust document and source settings in their respective panels.
- **Help (?):** Open the bundled Markdown guide without losing the current document.
- **Auto-hide:** Move the pointer to the top edge or the toolbar reveal control to show the panel. It remains visible while in use and hides when you leave. Showing it does not resize or shift the document.
- **Pin:** Use the pin button to switch between always visible and auto-hide, or press **⇧⌘H / Ctrl+Shift+H**. The former fully hidden mode is migrated to auto-hide.
- **Fullscreen:** Use the toolbar button, **⌃⌘F on Mac**, or **F11 on Windows**; Esc exits. Fullscreen and toolbar visibility are independent.

Layout, split ratio, linked scrolling, and toolbar preferences are stored locally. **⌘U / Ctrl+U** switches between single document and source views. Theme and per-view widths are also saved.

## Offline operation and supported content

markdown-it, DOMPurify, highlight.js, KaTeX, Mermaid, and CSS are bundled with the app. Documents are not uploaded, and rendering does not contact CDNs, remote font services, or analytics. HTML is sanitized before display, removing scripts, event handlers, iframes, forms, and arbitrary styles. Native request restrictions and Content Security Policy block remote assets.

Local images and Markdown links are limited to the document folder and its subfolders. Remote images are not loaded. Web and email links open in the default app only when clicked. Supported image formats, encodings, and file-size limits are documented in the platform guides.

KaTeX math (`$…$` and `$$…$$`), Mermaid fenced code blocks, and local SVG images are supported. Try the [math and diagrams example](Examples/Math-and-diagrams.md). Math support covers the LaTeX syntax supported by KaTeX, not complete LaTeX documents. Mermaid is limited to 20 diagrams per document, with up to 20,000 characters and 200 connections per diagram. Configuration directives, click actions, and external resources are disallowed. Diagrams appear as images on a light background with collapsible source text. If rendering fails, the source is retained.

Inline `<svg>` markup and editing are not supported. Code blocks with 100,000 or more characters are displayed without highlighting. Windows WebView2 Runtime installation and system updates are separate from offline document rendering.

## Build from source

Clone the **entire repository**. Copying only a platform folder omits shared assets and licenses.

| Environment | Run from the repository root |
| --- | --- |
| macOS · Xcode 15 or later, or Command Line Tools | `./Scripts/build-app.sh`, then `./Scripts/package-dmg.sh` |
| Windows · .NET 8 SDK | `./Windows/scripts/Publish.ps1 -OutputDirectory dist/MDBom-win-x64` |
| Windows installer · Inno Setup 6.3 or later | `./Windows/scripts/Build-Installer.ps1 -PublishDirectory dist/MDBom-win-x64 -OutputDirectory dist/installer` |

Web assets are committed, so normal app builds do not require Node.js. The first Windows NuGet restore requires internet access. Run `npm ci --ignore-scripts`, `npm run bundle`, and `node Scripts/check-assets.mjs` only when changing web sources or dependencies.

## Documentation and source layout

| Location | Contents |
| --- | --- |
| [macOS](macOS/) | Swift package, native host, Mac build and DMG tools |
| [Windows](Windows/) | .NET/WPF host, installer, packaging, and verification tools |
| [Shared/Renderer](Shared/Renderer/) | Shared renderer, styles, toolbar, search, and position mapping |
| [Scripts](Scripts/) | Shared web-asset tools and Mac command entry points |
| [Examples](Examples/) | Markdown examples for checking features |

Supporting documents are currently in Korean: [Contributing](CONTRIBUTING.md) · [Architecture and shared UI](ARCHITECTURE.md) · [Changelog](CHANGELOG.md) · [Verification](VERIFICATION.md) · [Roadmap](ROADMAP.md).

The app source is MIT licensed. Bundled libraries retain their own licenses, included in [ThirdPartyLicenses](ThirdPartyLicenses/) and platform distributions.

## Version policy

The first public release was **1.0 Beta 3 (`1.0.0-beta.3`)**. The current version is Beta 4. Subsequent betas increment the beta number, followed by the stable `1.0.0` release. App identifiers and preference locations remain unchanged for compatibility.

## Contributors

- **[Tae-Ho Lee](https://github.com/thlee)** — Planning, feature and design decisions, usability checks, and project management
- **ChatGPT · OpenAI Codex (AI development assistant)** — Design discussions, implementation, fixes, testing, packaging, and documentation support

MDBom is a personal open-source project developed through collaboration between its developer and an AI assistant.
