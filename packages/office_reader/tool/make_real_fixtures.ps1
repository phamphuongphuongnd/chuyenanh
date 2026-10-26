<#
  Tao file DOCX/XLSX THAT bang Microsoft Word / Excel (COM) vao test/fixtures/real/.
  Chay:  powershell -NoProfile -ExecutionPolicy Bypass -File tool\make_real_fixtures.ps1
  Yeu cau: Word + Excel cai san. Script chi ASCII; ky tu Unicode dung escape \uXXXX.
  Khong sua hay mo tai lieu cua nguoi dung; chi tao file moi.
#>
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'test\fixtures\real'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
[string]$outDir = (Resolve-Path $outDir).Path

function U([string]$s) { [regex]::Unescape($s) }
function Rgb([int]$r, [int]$g, [int]$b) { $r + ($g * 256) + ($b * 65536) }   # Office dung BGR
function Release($o) { if ($null -ne $o) { try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($o) } catch {} } }

# ---------------------------------------------------------------- DOCX
function Make-Docx {
  Add-Type -AssemblyName System.Drawing
  [string]$docxPath = Join-Path $outDir 'word_full.docx'
  $pngPath = Join-Path ([System.IO.Path]::GetTempPath()) 'office_reader_fixture.png'
  if (Test-Path $docxPath) { Remove-Item $docxPath -Force }

  # Anh PNG nho tu ve: nen do, hinh chu nhat xanh, duong cheo trang (48x32).
  $bmp = New-Object System.Drawing.Bitmap 48, 32
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::FromArgb(255, 200, 30, 30))
  $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 30, 60, 200))), 8, 8, 20, 12)
  $g.DrawLine([System.Drawing.Pens]::White, 0, 0, 47, 31)
  $g.Dispose(); $bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

  $word = $null; $doc = $null
  try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.ScreenUpdating = $false
    $word.DisplayAlerts = 0
    $doc = $word.Documents.Add()

    $st = @{ Normal = -1; H1 = -2; H2 = -3; H3 = -4; Bullet = -49; Bullet2 = -55; Number = -50; Number2 = -59 }

    function New-Para($styleId) {
      $p = $doc.Paragraphs.Last
      $p.Range.ListFormat.RemoveNumbers()
      $p.Range.Style = $doc.Styles.Item($styleId)
      $p.Range.ParagraphFormat.Reset()
      $p.Range.Font.Reset()
    }
    function Add-Seg([string]$text, $fmt) {
      $e = $doc.Content.End - 1
      $r = $doc.Range($e, $e)
      $r.Text = $text
      $r.Font.Reset()
      if ($fmt) {
        if ($fmt.Bold) { $r.Font.Bold = 1 }
        if ($fmt.Italic) { $r.Font.Italic = 1 }
        if ($fmt.Underline) { $r.Font.Underline = 1 }
        if ($fmt.Color) { $r.Font.Color = $fmt.Color }
        if ($fmt.Size) { $r.Font.Size = $fmt.Size }
      }
    }
    function End-Para { $doc.Content.InsertParagraphAfter() }
    function Add-Line($styleId, [string]$text) {
      New-Para $styleId; Add-Seg $text $null; End-Para
    }

    Write-Host '-- Header / footer cua section 1 (A4)'
    $doc.Sections.Item(1).PageSetup.PaperSize = 7   # A4
    $doc.Sections.Item(1).Headers.Item(1).Range.Text = 'Header: ' + (U 'ti\u00EAu \u0111\u1EC1 trang')
    $doc.Sections.Item(1).Footers.Item(1).Range.Text = 'Footer: trang cuoi'

    Write-Host '-- Heading 1..3'
    Add-Line $st.H1 'Heading Mot'
    Add-Line $st.H2 'Heading Hai'
    Add-Line $st.H3 'Heading Ba'

    Write-Host '-- Dinh dang ky tu: mot doan nhieu run'
    New-Para $st.Normal
    Add-Seg 'Thuong ' $null
    Add-Seg 'Dam' @{ Bold = $true }
    Add-Seg ' ' $null
    Add-Seg 'Nghieng' @{ Italic = $true }
    Add-Seg ' ' $null
    Add-Seg 'GachChan' @{ Underline = $true }
    Add-Seg ' ' $null
    Add-Seg 'MauDo' @{ Color = (Rgb 255 0 0) }
    Add-Seg ' ' $null
    Add-Seg 'Co20' @{ Size = 20 }
    End-Para

    Write-Host '-- Tieng Viet chong dau + tieng Trung'
    New-Para $st.Normal
    Add-Seg (U 'Ti\u1EBFng Vi\u1EC7t: m\u1EB7t \u0111\u1ED7 ng\u1EEF c\u1EABn m\u1EADt \u01B0\u01A1ng') $null
    End-Para
    New-Para $st.Normal
    Add-Seg (U '\u4F60\u597D\uFF0C\u4E16\u754C \u4E2D\u6587\u6D4B\u8BD5') $null
    End-Para

    Write-Host '-- List gach dau dong 2 cap (style List Bullet / List Bullet 2)'
    Add-Line $st.Bullet 'Bullet A'
    Add-Line $st.Bullet2 'Bullet A1'
    Add-Line $st.Bullet 'Bullet B'
    Write-Host '-- List danh so 2 cap bang style'
    Add-Line $st.Number 'Number Mot'
    Add-Line $st.Number2 'Number Mot-a'
    Add-Line $st.Number 'Number Hai'

    Write-Host '-- Outline nhieu cap bang ListTemplate (1 / 1.1 / 1.1.1)'
    $startOutline = $doc.Paragraphs.Count
    foreach ($t in 'Outline L1', 'Outline L2', 'Outline L3', 'Outline L1 b') {
      New-Para $st.Normal; Add-Seg $t $null; End-Para
    }
    $rng = $doc.Range($doc.Paragraphs.Item($startOutline).Range.Start, $doc.Paragraphs.Item($startOutline + 3).Range.End)
    $tpl = $word.ListGalleries.Item(3).ListTemplates.Item(1)
    $rng.ListFormat.ApplyListTemplate($tpl, $false, 0)
    $doc.Paragraphs.Item($startOutline + 1).Range.ListFormat.ListLevelNumber = 2
    $doc.Paragraphs.Item($startOutline + 2).Range.ListFormat.ListLevelNumber = 3

    Write-Host '-- Bang 4x3: gop ngang + gop doc + to nen'
    New-Para $st.Normal
    $tbl = $doc.Tables.Add($doc.Paragraphs.Last.Range, 4, 3)
    $tbl.Borders.Enable = $true
    for ($r = 1; $r -le 4; $r++) { for ($c = 1; $c -le 3; $c++) { $tbl.Cell($r, $c).Range.Text = "R${r}C${c}" } }
    $tbl.Cell(1, 1).Shading.BackgroundPatternColor = (Rgb 255 255 0)
    $tbl.Cell(4, 2).Shading.BackgroundPatternColor = (Rgb 173 216 230)
    $tbl.Cell(1, 1).Merge($tbl.Cell(1, 2))         # gop ngang hang 1
    $tbl.Cell(2, 3).Merge($tbl.Cell(3, 3))         # gop doc cot 3 hang 2-3
    $tbl.Cell(1, 1).Range.Text = 'Gop ngang'
    $tbl.Cell(2, 3).Range.Text = 'Gop doc'

    Write-Host '-- Anh'
    New-Para $st.Normal
    Add-Seg 'Anh: ' $null
    $e = $doc.Content.End - 1
    [void]$doc.InlineShapes.AddPicture($pngPath, $false, $true, $doc.Range($e, $e))
    End-Para

    Write-Host '-- Hyperlink'
    New-Para $st.Normal
    Add-Seg 'Link: ' $null
    $e = $doc.Content.End - 1
    [void]$doc.Hyperlinks.Add($doc.Range($e, $e), 'https://example.com/test', '', '', 'Example link')
    End-Para

    Write-Host '-- Footnote'
    New-Para $st.Normal
    Add-Seg 'Co chu thich' $null
    $e = $doc.Content.End - 1
    [void]$doc.Footnotes.Add($doc.Range($e, $e), [Type]::Missing, 'Noi dung footnote')
    End-Para

    Write-Host '-- Textbox neo o doan rieng'
    New-Para $st.Normal
    Add-Seg 'Doan chua textbox' $null
    $e = $doc.Content.End - 1
    $tb = $doc.Shapes.AddTextbox(1, 300, 200, 160, 40, $doc.Range($e, $e))
    $tb.TextFrame.TextRange.Text = 'Noi dung textbox'
    End-Para

    Write-Host '-- Ngat trang'
    New-Para $st.Normal
    Add-Seg 'Truoc ngat trang' $null
    End-Para
    $e = $doc.Content.End - 1
    $doc.Range($e, $e).InsertBreak(7)   # wdPageBreak
    New-Para $st.Normal
    Add-Seg 'Sau ngat trang' $null
    End-Para

    Write-Host '-- Section 2: Letter ngang'
    $e = $doc.Content.End - 1
    $doc.Range($e, $e).InsertBreak(2)   # wdSectionBreakNextPage
    Write-Host "   break ok"
    $s2 = $doc.Sections.Item($doc.Sections.Count)
    $s2.PageSetup.Orientation = 1        # landscape
    $s2.PageSetup.PageWidth = 792; $s2.PageSetup.PageHeight = 612   # Letter 11x8.5in
    Write-Host "   pagesetup ok"
    New-Para $st.Normal
    Add-Seg 'Section hai Letter ngang' $null

    Write-Host "   saving"
    $fmt = 12; $doc.SaveAs2([ref]$docxPath, [ref]$fmt)   # wdFormatXMLDocument; [ref] tranh treo
    Write-Host "OK: $docxPath"
  }
  finally {
    if ($doc) { try { $doc.Close(0) } catch {} }
    if ($word) { try { $word.Quit() } catch {} }
    Release $doc; Release $word
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    if (Test-Path $pngPath) { Remove-Item $pngPath -Force }
  }
}

# ---------------------------------------------------------------- XLSX
function Make-Xlsx {
  [string]$xlsxPath = Join-Path $outDir 'excel_full.xlsx'
  if (Test-Path $xlsxPath) { Remove-Item $xlsxPath -Force }
  $excel = $null; $wb = $null
  try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $wb = $excel.Workbooks.Add()
    while ($wb.Worksheets.Count -lt 3) { [void]$wb.Worksheets.Add([Type]::Missing, $wb.Worksheets.Item($wb.Worksheets.Count)) }
    $ws1 = $wb.Worksheets.Item(1); $ws2 = $wb.Worksheets.Item(2); $ws3 = $wb.Worksheets.Item(3)
    $ws1.Name = U 'D\u1EEF li\u1EC7u'
    $ws2.Name = 'Cong thuc'
    $ws3.Name = 'An'

    Write-Host '-- --- Sheet 1: kieu du lieu'
    $ws1.Range('A1').Value2 = 'Loai'; $ws1.Range('B1').Value2 = 'Gia tri'; $ws1.Range('C1').Value2 = 'Ghi chu'
    $h = $ws1.Range('A1:C1'); $h.Font.Bold = $true; $h.Interior.Color = (Rgb 255 192 0); $h.HorizontalAlignment = -4108
    $rows = @(
      @('Nguyen', 1234, 'General', 'int'),
      @('Thap phan', 3.14159, '0.00', 'dec'),
      @('Phan tram', 0.256, '0.0%', 'pct'),
      @('USD', 1234567.5, '$#,##0.00', 'usd'),
      @('VND', 1500000, ('#,##0 "' + (U '\u20AB') + '"'), 'vnd'),
      @('Ngay dd/mm/yyyy', 46000, 'dd/mm/yyyy', 'd1'),
      @('Ngay iso', 46000, 'yyyy-mm-dd', 'd2'),
      @('Ngay dai', 46000, 'd mmm yyyy', 'd3'),
      @('Gio', 0.75, 'hh:mm', 't1'),
      @('Gio AM/PM', 0.5208333333333334, 'h:mm:ss AM/PM', 't2'),
      @('Ngay gio', 46000.5, 'dd/mm/yyyy hh:mm', 'dt')
    )
    $r = 2
    foreach ($row in $rows) {
      $ws1.Cells.Item($r, 1).Value2 = $row[0]
      $ws1.Cells.Item($r, 2).Value2 = [double]$row[1]
      $ws1.Cells.Item($r, 2).NumberFormat = $row[2]
      $ws1.Cells.Item($r, 3).Value2 = $row[3]
      $r++
    }
    $ws1.Cells.Item($r, 1).Value2 = U 'Ti\u1EBFng Vi\u1EC7t: \u0111\u1EB7c bi\u1EC7t, m\u1EB7t \u1EF1'
    $ws1.Cells.Item($r, 2).NumberFormat = '@'
    $ws1.Cells.Item($r, 2).Value2 = U '\u4F60\u597D'
    $ws1.Cells.Item($r, 3).Value2 = 'Hello'

    Write-Host '-- --- Sheet 2: cong thuc, gop o, dinh dang, kich thuoc, freeze, loi'
    $ws2.Range('A1').Value2 = 10; $ws2.Range('A2').Value2 = 20; $ws2.Range('A3').Value2 = 30; $ws2.Range('A4').Value2 = 40
    $ws2.Range('A5').Formula = '=SUM(A1:A4)'
    $ws2.Range('B1').Formula = '=IF(A5>50,"Lon","Nho")'
    $ws2.Range('B2').Formula = '=1/0'
    $ws2.Range('D1:F2').Merge()
    $ws2.Range('D1').Value2 = 'Gop o'
    $ws2.Range('D1').Font.Bold = $true
    $ws2.Range('D1').Interior.Color = (Rgb 0 176 80)
    $ws2.Range('D1').HorizontalAlignment = -4108
    $ws2.Range('D1').VerticalAlignment = -4108
    $ws2.Range('A7').Value2 = 'Day la mot chuoi rat dai can wrap xuong nhieu dong trong mot cot hep'
    $ws2.Range('A7').WrapText = $true
    $ws2.Columns.Item(1).ColumnWidth = 20
    $ws2.Columns.Item(2).ColumnWidth = 5
    $ws2.Rows.Item(3).RowHeight = 40
    $ws2.Range('A9').Value2 = 'Nghieng do'
    $ws2.Range('A9').Font.Italic = $true
    $ws2.Range('A9').Font.Color = (Rgb 255 0 0)
    $ws2.Range('A9').Font.Underline = 2   # xlUnderlineStyleSingle
    $ws2.Range('A9').Font.Size = 14
    $ws2.Activate()
    $excel.ActiveWindow.SplitRow = 1
    $excel.ActiveWindow.SplitColumn = 1
    $excel.ActiveWindow.FreezePanes = $true

    Write-Host '-- --- Sheet 3: an'
    $ws3.Range('A1').Value2 = 'bi mat'
    $ws3.Visible = 0   # xlSheetHidden

    $ws1.Activate()
    $wb.SaveAs($xlsxPath, 51)
    Write-Host "OK: $xlsxPath"
  }
  finally {
    if ($wb) { try { $wb.Close($false) } catch {} }
    if ($excel) { try { $excel.Quit() } catch {} }
    Release $wb; Release $excel
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
  }
}

Make-Docx
Make-Xlsx
