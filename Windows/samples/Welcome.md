# A clearer view of Markdown

One small window. Your words, beautifully readable.

**엠디봄** is a read-only desktop app for Windows. Open a document, drop one into this window, or make it your default `.md` reader.

## Built for reading

| Feature | What you get |
| :--- | :--- |
| Local by design | Bundled rendering assets; no document uploads |
| Familiar formatting | Tables, lists, links, quotes, and images |
| Code that reads well | Syntax highlighting for common languages |
| Your preferred theme | System, light, or dark |
| Your preferred layout | Document, source, side-by-side, or stacked |
| Rich content | Math, Mermaid diagrams, and local SVG |
| Share a copy | Print / PDF; HTML export in development builds |

## A little progress

- [x] Open a Markdown document
- [x] Enjoy a comfortable reading layout
- [ ] Try **Ctrl+F** to find a word

## Code, with a little color

```csharp
var reader = new MarkdownViewer();
await reader.OpenAsync("Welcome.md");
Console.WriteLine("A quiet place to read.");
```

> Good tools get out of the way and let the document speak.

## Make yourself at home

Press **Ctrl+O** to open another file, **Ctrl+R** to reload, or **Ctrl++ / Ctrl+−** to change the text size. The theme button cycles through System, Light, and Dark.

Changes saved in another editor appear automatically. Use the width and font panels to adjust document and source settings separately. **Ctrl+U** switches between document and source while keeping the same content near the top where possible.

## Save a rendered copy

**Ctrl+P** opens Print / PDF for the formatted document, even in source or split view. Development builds after Beta 4 add **Export HTML** immediately to the left of Print. Choose a name and location to save one HTML file with styles, local images, math, and diagrams for offline viewing in a modern browser. The original Markdown stays unchanged. The published Beta 4 installers do not yet include HTML export.

### 한글도 편하게 읽으세요

한글, English, 日本語, and emoji ✨ are supported in UTF-8 documents.

<details>
<summary>A note about privacy</summary>

Document content stays on this computer. Remote images are not loaded. Clicking a web link opens your default browser.

</details>
