# MDBom app icon

`AppIcon.png` is the shared, approved artwork for macOS and Windows: navy rounded tile, white folded document, balanced **MD** lettering and two text lines. The exterior is transparent. Keep this single source instead of drawing different platform designs.

The artwork was created with OpenAI's built-in image generation tool and selected by Tae-Ho Lee on 2026-09-30. The final edit preserved the approved design and removed only the exterior background and shadow for transparent app-icon use.

On macOS, regenerate both formats from the repository root:

```sh
swift macOS/Scripts/make-icon.swift /tmp/MDBom.iconset
iconutil -c icns /tmp/MDBom.iconset -o macOS/Packaging/AppIcon.icns
```

The Swift script also writes `Windows/src/MarkdownViewer/Assets/app.ico` with 16, 24, 32, 48, 64, 128 and 256 pixel PNG entries. On Windows, `Windows/scripts/New-Icon.ps1` regenerates the ICO from the same PNG. Platform resampling may differ slightly; the artwork is identical.

Generated ICNS and ICO files are committed so normal application builds require no image tools. Previously published release assets retain their original icons until a new release is made.
