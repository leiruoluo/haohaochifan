# 生成"好好吃饭"应用图标：暖橙圆角背景 + 白碗（蒸汽 + 笑脸 + 米饭）
# 输出：master_icon.png(1024), android mipmaps, web icons, windows app_icon.ico
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = 'D:\DSH\Have a good diet'
$outDir = "$root\tools\icon_out"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$orange = [System.Drawing.Color]::FromArgb(255, 232, 116, 59)
$orangeDark = [System.Drawing.Color]::FromArgb(255, 201, 90, 38)
$white = [System.Drawing.Color]::White
$cream = [System.Drawing.Color]::FromArgb(255, 255, 248, 240)

function Draw-Icon([int]$size) {
  # 颜色在函数内硬编码，避免作用域问题
  $cOrange = [System.Drawing.Color]::FromArgb(255, 232, 116, 59)
  $cOrangeDark = [System.Drawing.Color]::FromArgb(255, 201, 90, 38)
  $cWhite = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
  $cCream = [System.Drawing.Color]::FromArgb(255, 255, 248, 240)
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)
  $s = $size / 1024.0

  # ---- 圆角背景 ----
  $r = 200.0 * $s
  $bgPath = New-Object System.Drawing.Drawing2D.GraphicsPath
  $bgPath.AddArc(0, 0, $r, $r, 180, 90)
  $bgPath.AddArc($size - $r, 0, $r, $r, 270, 90)
  $bgPath.AddArc($size - $r, $size - $r, $r, $r, 0, 90)
  $bgPath.AddArc(0, $size - $r, $r, $r, 90, 90)
  $bgPath.CloseFigure()
  $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point 0, 0),
    (New-Object System.Drawing.Point $size, $size),
    $orange, $orangeDark)
  $g.FillPath($bgBrush, $bgPath)

  # ---- 碗：主体（下半椭圆）+ 碗口（椭圆唇）+ 碗底足 ----
  $bowlW = 560.0 * $s
  $bowlH = 330.0 * $s
  $bx = ($size - $bowlW) / 2
  $by = 640.0 * $s            # 碗底 y
  $bowlTop = $by - $bowlH     # 碗口 y

  $bowlBrush = [System.Drawing.SolidBrush]::new($cWhite)
  # 主体：白色饼图（下半椭圆 180..360）
  $g.FillPie($bowlBrush, $bx, $bowlTop, $bowlW, $bowlH * 2, 180, 180)
  # 碗口唇：椭圆
  $g.FillEllipse($bowlBrush, $bx - 20 * $s, $bowlTop - 26 * $s, $bowlW + 40 * $s, 52 * $s)
  # 碗底足
  $footBrush = [System.Drawing.SolidBrush]::new($cCream)
  $fbCheck = [System.Drawing.SolidBrush]::new($cCream)
  Write-Host "DBG2 assign-null=$($null -eq $footBrush) direct-null=$($null -eq $fbCheck) varname=[footBrush] scope=$($footBrush.GetType().FullName)"
  $g.FillEllipse($fbCheck, ($size - 190 * $s) / 2, $by + 14 * $s, 190 * $s, 46 * $s)

  # ---- 碗里的米饭（橙色椭圆）----
  $foodBrush = [System.Drawing.SolidBrush]::new($cOrange)
  $g.FillEllipse($foodBrush, $bx + 90 * $s, $bowlTop + 8 * $s, $bowlW - 180 * $s, 86 * $s)

  # ---- 笑脸（碗口上）----
  $smilePen = [System.Drawing.Pen]::new($cOrangeDark, (16.0 * $s))
  $smilePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $smilePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $g.DrawArc($smilePen, $bx + 150 * $s, $bowlTop - 30 * $s, $bowlW - 300 * $s, 120 * $s, 15, 150)

  # ---- 蒸汽（两条曲线）----
  $pen = [System.Drawing.Pen]::new($cWhite, (13.0 * $s))
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  for ($i = 0; $i -lt 2; $i++) {
    $cx = $bx + 170 * $s + $i * 250 * $s
    $p1 = New-Object System.Drawing.PointF ($cx - 8 * $s), (270 * $s)
    $p2 = New-Object System.Drawing.PointF ($cx + 30 * $s), (215 * $s)
    $p3 = New-Object System.Drawing.PointF ($cx - 22 * $s), (160 * $s)
    $p4 = New-Object System.Drawing.PointF ($cx + 18 * $s), (110 * $s)
    $g.DrawBezier($pen, $p1, $p2, $p3, $p4)
  }

  $g.Dispose()
  return $bmp
}

$master = Draw-Icon 1024
$master.Save("$outDir\master_icon.png", [System.Drawing.Imaging.ImageFormat]::Png)

$mipmaps = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($k in $mipmaps.Keys) {
  $b = Draw-Icon $mipmaps[$k]
  $dir = "$root\android\app\src\main\res\mipmap-$k"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $b.Save("$dir\ic_launcher.png", [System.Drawing.Imaging.ImageFormat]::Png)
  $b.Dispose()
}

foreach ($s in @(512, 192, 32, 16)) {
  $b = Draw-Icon $s
  $b.Save("$outDir\icon-$s.png", [System.Drawing.Imaging.ImageFormat]::Png)
  $b.Dispose()
}

$sizes = @(256, 128, 64, 48, 32, 16)
$pngBytes = @{}
foreach ($s in $sizes) {
  $b = Draw-Icon $s
  $ms = New-Object System.IO.MemoryStream
  $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $pngBytes[$s] = $ms.ToArray()
  $b.Dispose(); $ms.Dispose()
}
$count = $sizes.Count
$ico = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter $ico
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$count)
$offset = 6 + 16 * $count
foreach ($s in $sizes) {
  $b = if ($s -eq 256) { 0 } else { $s }
  $bw.Write([byte]$b); $bw.Write([byte]$b); $bw.Write([byte]0); $bw.Write([byte]0)
  $bw.Write([uint16]1); $bw.Write([uint16]32)
  $bw.Write([uint32]$pngBytes[$s].Length); $bw.Write([uint32]$offset)
  $offset += $pngBytes[$s].Length
}
foreach ($s in $sizes) { $bw.Write($pngBytes[$s]) }
$bw.Flush()
[System.IO.File]::WriteAllBytes("$outDir\app_icon.ico", $ico.ToArray())
$bw.Dispose(); $ico.Dispose(); $master.Dispose()

"图标生成完成"
Get-ChildItem $outDir | Select-Object Name, Length