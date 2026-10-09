# Иконка игры и обложки из снимков Studio (assets/marketing/raw) — средствами Windows (System.Drawing).
# Запуск: powershell -ExecutionPolicy Bypass -File tools/make_marketing.ps1
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$raw = Join-Path $root "assets\marketing\raw"
$out = Join-Path $root "assets\marketing"

function New-Canvas($w, $h) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "AntiAlias"
    $g.InterpolationMode = "HighQualityBicubic"
    $g.TextRenderingHint = "AntiAliasGridFit"
    $g.PixelOffsetMode = "HighQuality"
    return @($bmp, $g)
}

# Вписать кадр снимка в холст с обрезкой по центру (cover).
function Draw-Cover($g, $img, $w, $h, $shiftY = 0.5) {
    $scale = [Math]::Max($w / $img.Width, $h / $img.Height)
    $sw = $w / $scale; $sh = $h / $scale
    $sx = ($img.Width - $sw) / 2; $sy = ($img.Height - $sh) * $shiftY
    $src = New-Object System.Drawing.RectangleF $sx, $sy, $sw, $sh
    $dst = New-Object System.Drawing.RectangleF 0, 0, $w, $h
    $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
}

# Затемнение снизу, чтобы текст читался.
function Draw-BottomShade($g, $w, $h, $from) {
    $rect = New-Object System.Drawing.Rectangle 0, ([int]($h * $from)), $w, ([int]($h * (1 - $from)) + 1)
    $c1 = [System.Drawing.Color]::FromArgb(0, 8, 10, 20)
    $c2 = [System.Drawing.Color]::FromArgb(215, 8, 10, 20)
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $c1, $c2, 90
    $g.FillRectangle($br, $rect)
}

# Текст с обводкой и градиентной заливкой.
function Draw-Title($g, $text, $size, $cx, $cy, $topColor, $bottomColor, $stroke) {
    $family = New-Object System.Drawing.FontFamily "Segoe UI Black"
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = "Center"; $fmt.LineAlignment = "Center"
    $path.AddString($text, $family, [int][System.Drawing.FontStyle]::Bold, $size, (New-Object System.Drawing.PointF $cx, $cy), $fmt)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 14, 16, 28)), $stroke
    $pen.LineJoin = "Round"
    $g.DrawPath($pen, $path)
    $b = $path.GetBounds()
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush $b, $topColor, $bottomColor, 90
    $g.FillPath($br, $path)
}

$gold1 = [System.Drawing.Color]::FromArgb(255, 255, 240, 170)
$gold2 = [System.Drawing.Color]::FromArgb(255, 255, 176, 60)
$mint1 = [System.Drawing.Color]::FromArgb(255, 220, 255, 230)
$mint2 = [System.Drawing.Color]::FromArgb(255, 110, 220, 160)

# ---------- иконка 512×512
$img = [System.Drawing.Image]::FromFile((Join-Path $raw "hero_close.jpg"))
$c = New-Canvas 512 512; $bmp = $c[0]; $g = $c[1]
Draw-Cover $g $img 512 512 0.45
Draw-BottomShade $g 512 512 0.55
Draw-Title $g "SPROUT" 92 256 392 $gold1 $gold2 14
Draw-Title $g "RNG" 64 256 462 $mint1 $mint2 12
$bmp.Save((Join-Path $out "icon_512.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $img.Dispose()

# ---------- обложки 1920×1080
$jpg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 92L

$thumbs = @(
    @{ src = "hero_close.jpg"; name = "thumb_1_exclusive.jpg"; title = "SPROUT RNG"; sub = "ROLL FOR FREE  ·  35 MAGICAL TREES" },
    @{ src = "hero_island.jpg"; name = "thumb_2_island.jpg"; title = "GROW YOUR ISLAND"; sub = "PLANT  ·  HARVEST  ·  EXPAND" },
    @{ src = "hub.jpg"; name = "thumb_3_rare.jpg"; title = "1 IN 100,000,000"; sub = "CAN YOU FIND THE GENESIS TREE?" }
)
foreach ($t in $thumbs) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $raw $t.src))
    $c = New-Canvas 1920 1080; $bmp = $c[0]; $g = $c[1]
    Draw-Cover $g $img 1920 1080 0.45
    Draw-BottomShade $g 1920 1080 0.58
    Draw-Title $g $t.title 150 960 880 $gold1 $gold2 18
    Draw-Title $g $t.sub 58 960 995 $mint1 $mint2 10
    $bmp.Save((Join-Path $out $t.name), $jpg, $ep)
    $g.Dispose(); $bmp.Dispose(); $img.Dispose()
}
Write-Output "done"
