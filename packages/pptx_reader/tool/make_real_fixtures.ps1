# Builds REAL .pptx fixtures with Microsoft PowerPoint (COM) into test/fixtures/real/.
# Usage: powershell -ExecutionPolicy Bypass -File tool/make_real_fixtures.ps1
# Needs desktop PowerPoint installed. Stops (non-zero exit) if COM is not usable.
# This file is ASCII only on purpose: non-ASCII text is built from \uXXXX escapes.

param(
  [string]$OutDir = (Join-Path $PSScriptRoot '..\test\fixtures\real')
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

# Text escape: "~1ebf" (tilde + 4 hex digits) becomes that UTF-16 code unit.
function U([string]$s) {
  return [regex]::Replace($s, '~([0-9a-fA-F]{4})', { param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
}
function Rgb([int]$r, [int]$g, [int]$b) { return $r + ($g * 256) + ($b * 65536) }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('pptx_fix_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

# --- self-drawn PNG (gradient + diagonal + text) ----------------------------
$pngPath = Join-Path $tmp 'sample.png'
$bmp = New-Object System.Drawing.Bitmap 400, 300
$g = [System.Drawing.Graphics]::FromImage($bmp)
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
  (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point 400, 300),
  [System.Drawing.Color]::FromArgb(255, 220, 60, 60), [System.Drawing.Color]::FromArgb(255, 40, 90, 220))
$g.FillRectangle($brush, 0, 0, 400, 300)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 6
$g.DrawLine($pen, 0, 0, 400, 300)
$g.DrawEllipse($pen, 120, 70, 160, 160)
$font = New-Object System.Drawing.Font 'Arial', 28
$g.DrawString('PNG 400x300', $font, [System.Drawing.Brushes]::White, 90, 120)
$g.Dispose(); $bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

# PowerPoint constants
$ppLayoutTitle = 1; $ppLayoutText = 2; $ppLayoutTwoColumnText = 3; $ppLayoutTitleOnly = 11
$ppSaveAsOpenXMLPresentation = 24
$msoTrue = -1; $msoFalse = 0

function Release($o) {
  if ($null -ne $o) { try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($o) } catch {} }
}

# Finds a custom layout of the master by index fallback (language independent).
function Get-Layout($pres, [int]$idx) { return $pres.SlideMaster.CustomLayouts.Item($idx) }

$app = $null
try {
  try {
    $app = New-Object -ComObject PowerPoint.Application
  } catch {
    Write-Error "COM PowerPoint.Application is not available: $_"
    exit 2
  }
  Write-Host ("PowerPoint version " + $app.Version)

  # ========================================================================
  # Deck 1: 16:9, default Office theme
  # ========================================================================
  $pres = $app.Presentations.Add($msoFalse)
  try {
    $pres.PageSetup.SlideWidth = 960
    $pres.PageSetup.SlideHeight = 540

    # 1 Title slide
    $s = $pres.Slides.AddSlide(1, (Get-Layout $pres 1))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Real Deck Title'
    $s.Shapes.Item(2).TextFrame.TextRange.Text = 'Subtitle line made by PowerPoint'

    # 2 Title and Content, multi level bullets
    $s = $pres.Slides.AddSlide(2, (Get-Layout $pres 2))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Bullets'
    $tr = $s.Shapes.Item(2).TextFrame.TextRange
    $tr.Text = "Level one A`rLevel two A1`rLevel three A11`rLevel two A2`rLevel one B"
    $lv = 1, 2, 3, 2, 1
    for ($i = 1; $i -le 5; $i++) { $tr.Paragraphs($i).IndentLevel = $lv[$i - 1] }

    # 3 Two Content
    $s = $pres.Slides.AddSlide(3, (Get-Layout $pres 4))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Two columns'
    $s.Shapes.Item(2).TextFrame.TextRange.Text = "Left one`rLeft two"
    $s.Shapes.Item(3).TextFrame.TextRange.Text = "Right one`rRight two"

    # 4 Picture with crop
    $s = $pres.Slides.AddSlide(4, (Get-Layout $pres 6))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Picture'
    $pic = $s.Shapes.AddPicture($pngPath, $msoFalse, $msoTrue, 100, 140, 360, 270)
    $pic.Name = 'PlainPicture'
    $pic2 = $s.Shapes.AddPicture($pngPath, $msoFalse, $msoTrue, 520, 140, 360, 270)
    $pic2.Name = 'CroppedPicture'
    $pic2.PictureFormat.CropLeft = 60
    $pic2.PictureFormat.CropTop = 30

    # 5 Table 3 rows x 4 cols, with merges
    $s = $pres.Slides.AddSlide(5, (Get-Layout $pres 6))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Table'
    $ts = $s.Shapes.AddTable(3, 4, 60, 150, 840, 240)
    $ts.Name = 'MergedTable'
    $t = $ts.Table
    for ($r = 1; $r -le 3; $r++) {
      for ($c = 1; $c -le 4; $c++) {
        $t.Cell($r, $c).Shape.TextFrame.TextRange.Text = "r${r}c${c}"
      }
    }
    $t.Cell(1, 1).Merge($t.Cell(1, 2))      # horizontal merge
    $t.Cell(2, 4).Merge($t.Cell(3, 4))      # vertical merge

    # 6 Filled shapes
    $s = $pres.Slides.AddSlide(6, (Get-Layout $pres 6))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Shapes'
    $sh = $s.Shapes.AddShape(1, 60, 160, 240, 140)       # rectangle
    $sh.Name = 'RectShape'
    $sh.Fill.ForeColor.RGB = (Rgb 255 192 0)
    $sh.Line.ForeColor.RGB = (Rgb 0 0 128); $sh.Line.Weight = 3
    $sh.TextFrame.TextRange.Text = 'Rect text'
    $sh.TextFrame.TextRange.Font.Color.RGB = (Rgb 0 0 0)
    $sh = $s.Shapes.AddShape(9, 340, 160, 240, 140)      # ellipse
    $sh.Name = 'EllipseShape'
    $sh.Fill.ForeColor.RGB = (Rgb 0 176 80)
    $sh.Line.ForeColor.RGB = (Rgb 255 0 0); $sh.Line.Weight = 2
    $sh.TextFrame.TextRange.Text = 'Ellipse text'
    $sh = $s.Shapes.AddShape(5, 620, 160, 240, 140)      # rounded rectangle
    $sh.Name = 'RoundShape'
    $sh.Fill.ForeColor.RGB = (Rgb 112 48 160)
    $sh.Line.Visible = $msoFalse
    $sh.TextFrame.TextRange.Text = 'Round text'
    $sh.TextFrame.TextRange.Font.Size = 24
    $sh.TextFrame.TextRange.Font.Bold = $msoTrue

    # 7 Group of 2 shapes
    $s = $pres.Slides.AddSlide(7, (Get-Layout $pres 6))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Group'
    $a = $s.Shapes.AddShape(1, 200, 200, 160, 100); $a.Name = 'GA'
    $a.Fill.ForeColor.RGB = (Rgb 255 0 0); $a.TextFrame.TextRange.Text = 'In group A'
    $b = $s.Shapes.AddShape(9, 420, 260, 160, 100); $b.Name = 'GB'
    $b.Fill.ForeColor.RGB = (Rgb 0 0 255); $b.TextFrame.TextRange.Text = 'In group B'
    $grp = $s.Shapes.Range([string[]]@('GA', 'GB')).Group()
    $grp.Name = 'TwoShapeGroup'

    # 8 Own background colour
    $s = $pres.Slides.AddSlide(8, (Get-Layout $pres 6))
    $s.FollowMasterBackground = $msoFalse
    $s.Background.Fill.Solid()
    $s.Background.Fill.ForeColor.RGB = (Rgb 0 32 96)
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Navy background'
    $s.Shapes.Item(1).TextFrame.TextRange.Font.Color.RGB = (Rgb 255 255 255)

    # 9 Notes
    $s = $pres.Slides.AddSlide(9, (Get-Layout $pres 2))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Has notes'
    $s.Shapes.Item(2).TextFrame.TextRange.Text = 'Body of the notes slide'
    $s.NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "First note line`rSecond note line"

    # 10 Hidden slide
    $s = $pres.Slides.AddSlide(10, (Get-Layout $pres 6))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Hidden slide'
    $s.SlideShowTransition.Hidden = $msoTrue

    # 11 Vietnamese (stacked diacritics) + Chinese
    $s = $pres.Slides.AddSlide(11, (Get-Layout $pres 2))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = (U 'Ti~1ebfng Vi~1ec7t ~4e2d~6587')
    $vi = (U 'C~1ed9ng h~00f2a x~00e3 h~1ed9i ch~1ee7 ngh~0129a Vi~1ec7t Nam')
    $vi2 = (U 'Nh~1eefng ~0111~01b0~1eddng ~1ed1ng d~1ea7u, ng~1eb7t ngh~00e8o, r~1ef1c r~1ee1')
    $zh = (U '~4f60~597d~ff0c~4e16~754c~3002~8fd9~662f~4e2d~6587~6d4b~8bd5')
    $s.Shapes.Item(2).TextFrame.TextRange.Text = "$vi`r$vi2`r$zh"

    # 12 Chart (opens Excel in the background to build the chart data)
    $s = $pres.Slides.AddSlide(12, (Get-Layout $pres 6))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Chart'
    # (the chart itself is added below: AddChart2 fails with E_FAIL on a window-less
    #  presentation, so the saved file is re-opened WITH a window just for that step)

    $out1 = Join-Path $OutDir 'deck_16x9.pptx'
    $pres.SaveAs($out1, $ppSaveAsOpenXMLPresentation)
    Write-Host "Saved $out1"
  } finally {
    try { $pres.Close() } catch {}
    Release $pres
  }

  $pres = $app.Presentations.Open($out1, $msoFalse, $msoFalse, $msoTrue)   # ReadOnly=false, Untitled=false, WithWindow=true
  try {
    $s = $pres.Slides.Item(12)
    $cs = $s.Shapes.AddChart2(201, 51, 100, 140, 760, 360)   # xlColumnClustered
    $cs.Name = 'SalesChart'
    try { $cs.Chart.ChartData.Workbook.Close() } catch {}
    $pres.Save()
    Write-Host 'Chart added to slide 12'
  } finally {
    try { $pres.Close() } catch {}
    Release $pres
  }

  # ========================================================================
  # Deck 2: 4:3 with a design theme (if one is installed)
  # ========================================================================
  $themeDir = $null
  foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if ($root) {
      $cand = Join-Path $root 'Microsoft Office\root\Document Themes 16'
      if (Test-Path $cand) { $themeDir = $cand; break }
    }
  }
  $theme = $null
  if ($themeDir) {
    foreach ($n in @('Facet.thmx', 'Ion Boardroom.thmx', 'Retrospect.thmx')) {
      $p = Join-Path $themeDir $n
      if (Test-Path $p) { $theme = $p; break }
    }
  }
  if ($theme) {
    $pres = $app.Presentations.Add($msoFalse)
    try {
      $pres.PageSetup.SlideWidth = 720
      $pres.PageSetup.SlideHeight = 540
      $pres.ApplyTheme($theme)
      $s = $pres.Slides.AddSlide(1, (Get-Layout $pres 1))
      $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Themed 4:3 title'
      $s.Shapes.Item(2).TextFrame.TextRange.Text = 'Applied theme: ' + [IO.Path]::GetFileNameWithoutExtension($theme)
      $s = $pres.Slides.AddSlide(2, (Get-Layout $pres 2))
      $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Themed content'
      $tr = $s.Shapes.Item(2).TextFrame.TextRange
      $tr.Text = "Point one`rSub point`rPoint two"
      $tr.Paragraphs(2).IndentLevel = 2
      $out2 = Join-Path $OutDir 'deck_4x3_theme.pptx'
      $pres.SaveAs($out2, $ppSaveAsOpenXMLPresentation)
      Write-Host "Saved $out2 (theme: $theme)"
    } finally {
      try { $pres.Close() } catch {}
      Release $pres
    }
  } else {
    Write-Warning 'No design theme (.thmx) found; 4:3 deck skipped.'
  }

  # ========================================================================
  # Deck 3: 16:9 extras - text box, hyperlink, numbering, rotation, flip,
  # arrow, line, gradient, picture fill, footer + slide number, autofit
  # ========================================================================
  $pres = $app.Presentations.Add($msoFalse)
  try {
    $pres.PageSetup.SlideWidth = 960
    $pres.PageSetup.SlideHeight = 540

    # 1 Text box with formatting, hyperlink, numbered list
    $s = $pres.Slides.AddSlide(1, (Get-Layout $pres 6))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Text formatting'
    $tb = $s.Shapes.AddTextbox(1, 60, 140, 420, 300)
    $tb.Name = 'FormatBox'
    $tr = $tb.TextFrame.TextRange
    $tr.Text = "Bold italic underline`rVisit the site`rFirst item`rSecond item`rRight aligned"
    $tr.Font.Size = 20
    $tr.Paragraphs(1).Font.Bold = $msoTrue
    $tr.Paragraphs(1).Font.Italic = $msoTrue
    $tr.Paragraphs(1).Font.Underline = $msoTrue
    $tr.Paragraphs(1).Font.Color.ObjectThemeColor = 6       # msoThemeColorAccent2
    $tr.Paragraphs(2).Characters(11, 4).ActionSettings(1).Hyperlink.Address = 'https://example.com/'
    foreach ($i in 3, 4) {
      $pf = $tr.Paragraphs($i).ParagraphFormat
      $pf.Bullet.Visible = $msoTrue
      $pf.Bullet.Type = 2          # ppBulletNumbered
      $pf.Bullet.Style = 3         # ppBulletArabicPeriod
    }
    $tr.Paragraphs(5).ParagraphFormat.Alignment = 3          # right
    $tb2 = $s.Shapes.AddTextbox(1, 520, 140, 380, 100)
    $tb2.Name = 'ScriptBox'
    $tb2.TextFrame.TextRange.Text = 'H2O and x2'
    $tb2.TextFrame.TextRange.Font.Size = 24
    $tb2.TextFrame.TextRange.Characters(2, 1).Font.Subscript = $msoTrue
    $tb2.TextFrame.TextRange.Characters(10, 1).Font.Superscript = $msoTrue

    # 2 Rotation, flip, arrow, line, gradient, picture fill
    $s = $pres.Slides.AddSlide(2, (Get-Layout $pres 6))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Transforms'
    $sh = $s.Shapes.AddShape(1, 80, 160, 200, 100); $sh.Name = 'Rotated'
    $sh.Rotation = 30; $sh.Fill.ForeColor.RGB = (Rgb 255 192 0); $sh.TextFrame.TextRange.Text = 'rot 30'
    $sh = $s.Shapes.AddShape(7, 340, 160, 160, 120); $sh.Name = 'FlippedTriangle'
    $sh.Flip(0)                                        # msoFlipHorizontal
    $sh.Fill.ForeColor.RGB = (Rgb 0 176 240)
    $sh = $s.Shapes.AddShape(33, 560, 160, 200, 100); $sh.Name = 'RightArrow'
    $sh.Fill.ForeColor.RGB = (Rgb 146 208 80)
    $ln = $s.Shapes.AddLine(80, 360, 400, 440); $ln.Name = 'DiagLine'
    $ln.Line.ForeColor.RGB = (Rgb 192 0 0); $ln.Line.Weight = 4
    $sh = $s.Shapes.AddShape(1, 460, 330, 200, 130); $sh.Name = 'GradientRect'
    $sh.Fill.TwoColorGradient(1, 1)
    $sh.Fill.ForeColor.RGB = (Rgb 255 0 0); $sh.Fill.BackColor.RGB = (Rgb 0 0 255)
    $sh = $s.Shapes.AddShape(1, 700, 330, 200, 130); $sh.Name = 'PictureFillRect'
    $sh.Fill.UserPicture($pngPath)

    # 3 Footer + slide number
    $s = $pres.Slides.AddSlide(3, (Get-Layout $pres 2))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Footer slide'
    $s.Shapes.Item(2).TextFrame.TextRange.Text = 'Body'
    $s.HeadersFooters.Footer.Visible = $msoTrue
    $s.HeadersFooters.Footer.Text = 'My footer text'
    $s.HeadersFooters.SlideNumber.Visible = $msoTrue

    # 4 Autofit: long text in a placeholder
    $s = $pres.Slides.AddSlide(4, (Get-Layout $pres 2))
    $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Autofit'
    $long = (1..30 | ForEach-Object { "Line number $_ of a very long list that must shrink" }) -join "`r"
    $s.Shapes.Item(2).TextFrame.TextRange.Text = $long
    $s.Shapes.Item(2).TextFrame2.AutoSize = 2                # msoAutoSizeTextToFitShape

    $out3 = Join-Path $OutDir 'deck_extras.pptx'
    $pres.SaveAs($out3, $ppSaveAsOpenXMLPresentation)
    Write-Host "Saved $out3"
  } finally {
    try { $pres.Close() } catch {}
    Release $pres
  }

  # ========================================================================
  # Deck 4: Organic theme (texture background and decorations)
  # ========================================================================
  $organic = $null
  if ($themeDir) {
    $p = Join-Path $themeDir 'Organic.thmx'
    if (Test-Path $p) { $organic = $p }
  }
  if ($organic) {
    $pres = $app.Presentations.Add($msoFalse)
    try {
      $pres.PageSetup.SlideWidth = 960
      $pres.PageSetup.SlideHeight = 540
      $pres.ApplyTheme($organic)
      $s = $pres.Slides.AddSlide(1, (Get-Layout $pres 1))
      $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Organic title'
      $s.Shapes.Item(2).TextFrame.TextRange.Text = 'Organic subtitle'
      $s = $pres.Slides.AddSlide(2, (Get-Layout $pres 2))
      $s.Shapes.Item(1).TextFrame.TextRange.Text = 'Organic content'
      $s.Shapes.Item(2).TextFrame.TextRange.Text = "Alpha`rBeta"
      $out4 = Join-Path $OutDir 'deck_organic.pptx'
      $pres.SaveAs($out4, $ppSaveAsOpenXMLPresentation)
      Write-Host "Saved $out4"
    } finally {
      try { $pres.Close() } catch {}
      Release $pres
    }
  }
} catch {
  Write-Host ("ERROR at line " + $_.InvocationInfo.ScriptLineNumber + ": " + $_)
  $script:failed = $true
} finally {
  if ($null -ne $app) {
    try { $app.Quit() } catch {}
    Release $app
  }
  [GC]::Collect(); [GC]::WaitForPendingFinalizers()
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmp
}

if ($script:failed) { exit 1 }
