$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$destination = Join-Path $PSScriptRoot '..\src\MarkdownViewer\Assets\app.ico'
$images = @()
foreach ($size in @(16, 24, 32, 48, 64, 128, 256)) {
    $bitmap = [Drawing.Bitmap]::new($size, $size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([Drawing.Color]::FromArgb(22, 27, 34))
    $graphics.ScaleTransform($size / 64.0, $size / 64.0)
    $pen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(230, 237, 243), 5)
    $graphics.DrawLines($pen, [Drawing.PointF[]]@([Drawing.PointF]::new(11, 45),[Drawing.PointF]::new(11, 20),[Drawing.PointF]::new(23, 33),[Drawing.PointF]::new(35, 20),[Drawing.PointF]::new(35, 45)))
    $pen.Color = [Drawing.Color]::FromArgb(88, 166, 255)
    $graphics.DrawLine($pen, 49, 20, 49, 43)
    $graphics.DrawLines($pen, [Drawing.PointF[]]@([Drawing.PointF]::new(41, 35),[Drawing.PointF]::new(49, 44),[Drawing.PointF]::new(57, 35)))
    $stream = [IO.MemoryStream]::new()
    $bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
    $images += ,@{ Size = $size; Bytes = $stream.ToArray() }
    $stream.Dispose(); $pen.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
$output = [IO.File]::Create($destination)
$writer = [IO.BinaryWriter]::new($output)
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$images.Count)
$offset = 6 + 16 * $images.Count
foreach ($image in $images) {
    $dimension = if ($image.Size -eq 256) { 0 } else { $image.Size }
    $writer.Write([byte]$dimension); $writer.Write([byte]$dimension); $writer.Write([byte]0); $writer.Write([byte]0)
    $writer.Write([uint16]1); $writer.Write([uint16]32); $writer.Write([uint32]$image.Bytes.Length); $writer.Write([uint32]$offset)
    $offset += $image.Bytes.Length
}
foreach ($image in $images) { $writer.Write([byte[]]$image.Bytes) }
$writer.Dispose()
