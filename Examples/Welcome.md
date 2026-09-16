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

## A few things to try

- [x] Open this document from Finder
- [x] Read tables and highlighted code
- [ ] Drop another Markdown file into this window
- [ ] Press **⌘F** to find a word

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

Use `⌘+` and `⌘−` to change the reading size, or click the percentage to return to 100%.
If another app changes the file, press **⌘R** to read it again.

Read **bold text**, *emphasis*, ~~strikethrough~~, and `inline code`.

<details>
<summary>A note about privacy</summary>

All rendering libraries are inside the app. Remote images are blocked automatically.
Web links open in your default browser only when you click them.

</details>

## Local images

![Bundled app icon](assets/icon.png)

Images in this document’s folder or its subfolders can be displayed. PNG, JPEG, GIF, WebP, and AVIF are supported.

[Read the next page](More.markdown) · [Back to the top](#a-quiet-place-to-read)
