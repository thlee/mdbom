# A quiet place to read

Welcome to **엠디봄** — a small, native home for your Markdown documents.

안녕하세요. 한글 문서도 편하게 읽을 수 있습니다.

> Open a file, settle in, and read. Your original document stays exactly as it is.

## Everything you need

| Feature | Included |
| :--- | :---: |
| Tables & task lists | ✓ |
| Syntax highlighting | ✓ |
| Light & dark appearance | ✓ |
| Offline reading | ✓ |
| Source and split views | ✓ |
| Math, Mermaid, and local SVG | ✓ |
| Print / PDF | ✓ |

## A few things to try

- [x] Open this document from Finder or File Explorer
- [x] Read tables and highlighted code
- [ ] Drop another Markdown file into this window
- [ ] Press **⌘F / Ctrl+F** to find a word

These checkboxes show the document’s state and are read only.

## Code, with a little color

```swift
import SwiftUI

struct ReadingView: View {
    let message = "Hello, Markdown."

    var body: some View {
        Text(message)
            .font(.title)
    }
}
```

```python
from pathlib import Path

for document in Path("notes").glob("*.md"):
    print(document.name)
```

## Comfortable reading

Use `⌘+` / `⌘−` on Mac or `Ctrl++` / `Ctrl+−` on Windows to zoom, or click the percentage to return to 100%.
Changes saved by another editor appear automatically. To reload manually, press **⌘R / Ctrl+R**.

Use the width and font panels to adjust the document and source separately. **⌘U / Ctrl+U** switches between document and source, keeping the same content near the top where possible. Split views show both at once.

## Share a rendered copy

Use **Print / PDF** to print the formatted document or save a PDF. Version 1.0 also provides **Export HTML**, immediately left of Print. It saves a single file containing styles and local images, with the current document theme, width, and font. The original Markdown stays unchanged. HTML export is included in macOS 1.0. The published Windows Beta 4 installer does not include it.

Read **bold text**, *emphasis*, ~~strikethrough~~, and `inline code`.

<details>
<summary>A note about privacy</summary>

All rendering libraries are inside the app. Remote images are blocked automatically.
Web links open in your default browser only when you click them.

</details>

## Local images

![Bundled app icon](assets/icon.png)

Images in this document’s folder or its subfolders can be displayed. Both platforms support PNG, JPEG, GIF, WebP, and SVG; Mac also supports AVIF and Windows supports BMP/ICO.

[Read the next page](More.markdown) · [Back to the top](#a-quiet-place-to-read)
