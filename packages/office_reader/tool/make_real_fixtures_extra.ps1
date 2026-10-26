<#
  Bo file THAT thu hai (nang hon): tao word_extra.docx va excel_extra.xlsx bang Word/Excel COM
  vao test/fixtures/real/. Chay:
    powershell -NoProfile -ExecutionPolicy Bypass -File tool\make_real_fixtures_extra.ps1 [-Only xlsx|docx]
  Script chi ASCII; ky tu Unicode dung \uXXXX. Chi tao file moi, khong mo tai lieu cua nguoi dung.
#>
param([ValidateSet('all', 'xlsx', 'docx')][string]$Only = 'all')
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
[string]$outDir = Join-Path $root 'test\fixtures\real'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outDir = (Resolve-Path $outDir).Path

function U([string]$s) { [regex]::Unescape($s) }
function Rgb([int]$r, [int]$g, [int]$b) { $r + ($g * 256) + ($b * 65536) }
function Release($o) { if ($null -ne $o) { try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($o) } catch {} } }

# ---------------------------------------------------------------- XLSX
function Make-XlsxExtra {
  [string]$path = Join-Path $outDir 'excel_extra.xlsx'
  if (Test-Path $path) { Remove-Item $path -Force }
  $excel = $null; $wb = $null
  try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $wb = $excel.Workbooks.Add()
    while ($wb.Worksheets.Count -lt 3) { [void]$wb.Worksheets.Add([Type]::Missing, $wb.Worksheets.Item($wb.Worksheets.Count)) }
    $ws = $wb.Worksheets.Item(1)
    $ws.Name = 'Formats'

    # Cot A: nhan, cot B: gia tri + numFmt
    $cases = @(
      @(1234.5678, 'General'),
      @(0.30000000000000004, 'General'),
      @(0.3333333333333333, 'General'),
      @(12345678901234, 'General'),
      @(0.000012345, 'General'),
      @(-42, 'General'),
      @(1234.5, '0.00E+00'),
      @(0.75, '# ?/?'),
      @(-1234.5, '#,##0;[Red]-#,##0'),
      @(1234.5, '_($* #,##0.00_);_($* (#,##0.00);_($* "-"??_);_(@_)'),
      @(0.5, '0%'),
      @(46000, 'mmmm d, yyyy'),
      @(46000, 'dddd'),
      @(1.5, '[h]:mm:ss'),
      @(46000, 'm/d/yyyy'),
      @(1234567, '#,##0'),
      @(0.056, '0.0%'),
      @(5, '000'),
      @(1234.5, '#,##0.00;(#,##0.00)'),
      @(0, '0.00;-0.00;"zero"')
    )
    $r = 1
    foreach ($c in $cases) {
      $ws.Cells.Item($r, 1).Value2 = "case$r"
      $ws.Cells.Item($r, 2).NumberFormat = $c[1]
      $ws.Cells.Item($r, 2).Value2 = [double]$c[0]
      $r++
    }
    # Kieu khac
    $ws.Cells.Item($r, 1).Value2 = 'bool'; $ws.Cells.Item($r, 2).Value2 = $true; $r++
    $ws.Cells.Item($r, 1).Value2 = 'newline'; $ws.Cells.Item($r, 2).Value2 = "dong1`ndong2"; $ws.Cells.Item($r, 2).WrapText = $true; $r++
    $ws.Cells.Item($r, 1).Value2 = 'textnum'; $ws.Cells.Item($r, 2).NumberFormat = '@'; $ws.Cells.Item($r, 2).Value2 = '00123'; $r++
    $ws.Cells.Item($r, 1).Value2 = 'spaces'; $ws.Cells.Item($r, 2).Value2 = "  lead & trail <x>  "; $r++
    $ws.Cells.Item($r, 1).Value2 = 'rich'; $ws.Cells.Item($r, 2).Value2 = 'BoldNormal'
    $ws.Cells.Item($r, 2).Characters(1, 4).Font.Bold = $true; $ws.Cells.Item($r, 2).Characters(5, 6).Font.Color = (Rgb 255 0 0); $r++
    $ws.Cells.Item($r, 1).Value2 = 'link'
    [void]$ws.Hyperlinks.Add($ws.Cells.Item($r, 2), 'https://example.com/x', '', '', 'Click'); $r++
    $ws.Cells.Item($r, 1).Value2 = 'serial60'; $ws.Cells.Item($r, 2).NumberFormat = 'yyyy-mm-dd'; $ws.Cells.Item($r, 2).Value2 = [double]61; $r++   # 1900-03-01
    $ws.Cells.Item($r, 1).Value2 = 'border'; $ws.Cells.Item($r, 2).Value2 = 'boxed'; $ws.Cells.Item($r, 2).Borders.LineStyle = 1; $r++
    $ws.Cells.Item($r, 1).Value2 = 'indent'; $ws.Cells.Item($r, 2).Value2 = 'indented'; $ws.Cells.Item($r, 2).IndentLevel = 2; $ws.Cells.Item($r, 2).HorizontalAlignment = -4131; $r++
    $ws.Cells.Item($r, 1).Value2 = 'strike'; $ws.Cells.Item($r, 2).Value2 = 'struck'; $ws.Cells.Item($r, 2).Font.Strikethrough = $true; $r++
    $ws.Cells.Item($r, 1).Value2 = 'theme'; $ws.Cells.Item($r, 2).Value2 = 'themecolor'; $ws.Cells.Item($r, 2).Interior.ThemeColor = 5; $ws.Cells.Item($r, 2).Font.ThemeColor = 2; $r++
    $ws.Cells.Item($r, 1).Value2 = 'tint'; $ws.Cells.Item($r, 2).Value2 = 'tinted'; $ws.Cells.Item($r, 2).Interior.ThemeColor = 5; $ws.Cells.Item($r, 2).Interior.TintAndShade = 0.6; $r++
    $ws.Cells.Item($r, 1).Value2 = 'arial'; $ws.Cells.Item($r, 2).Value2 = 'arial12'; $ws.Cells.Item($r, 2).Font.Name = 'Arial'; $ws.Cells.Item($r, 2).Font.Size = 12; $r++
    $ws.Cells.Item($r, 1).Value2 = 'comment'; $ws.Cells.Item($r, 2).Value2 = 'has note'; [void]$ws.Cells.Item($r, 2).AddComment('a note'); $r++

    # Cong thuc: chia se / mang / bool / chuoi
    $ws2 = $wb.Worksheets.Item(2); $ws2.Name = 'Formulas'
    for ($i = 1; $i -le 5; $i++) { $ws2.Cells.Item($i, 1).Value2 = [double]$i }
    $ws2.Range('B1:B5').Formula = '=A1*2'                 # cong thuc chia se
    $ws2.Range('C1').Formula = '=A1>2'                    # bool
    $ws2.Range('C2').Formula = '="x"&A2'                  # chuoi
    $ws2.Range('C3').Formula = '=TEXT(46000,"dd/mm/yyyy")'
    $ws2.Range('C4').Formula = '=A1/0'
    $ws2.Range('C5').Formula = '=NA()'
    $ws2.Range('D1').Formula = '=TODAY()-TODAY()'
    $ws2.Range('E1:E2').FormulaArray = '=A1:A2*10'
    # cot lien tiep cung do rong, hang an, cot an, nhom
    $ws2.Range('G1').Value2 = 'wide'
    $ws2.Range('G:I').ColumnWidth = 12
    $ws2.Columns.Item(10).Hidden = $true
    $ws2.Range('K1').Value2 = 'after hidden col'
    $ws2.Rows.Item(7).Hidden = $true
    $ws2.Range('A7').Value2 = 'hidden row'
    $ws2.Range('A8').Value2 = 'tab color sheet'
    $ws2.Tab.Color = (Rgb 255 0 0)

    # Sheet 3: trong ky + ListObject + dinh nghia ten
    $ws3 = $wb.Worksheets.Item(3); $ws3.Name = 'Table'
    $ws3.Range('A1').Value2 = 'Name'; $ws3.Range('B1').Value2 = 'Qty'
    $ws3.Range('A2').Value2 = 'apple'; $ws3.Range('B2').Value2 = 3
    $ws3.Range('A3').Value2 = 'pear'; $ws3.Range('B3').Value2 = 5
    [void]$ws3.ListObjects.Add(1, $ws3.Range('A1:B3'), $null, 1)
    $ws3.Range('D5').Value2 = 'far away'

    $ws.Activate()
    $wb.SaveAs($path, 51)
    Write-Host "OK: $path"
  }
  finally {
    if ($wb) { try { $wb.Close($false) } catch {} }
    if ($excel) { try { $excel.Quit() } catch {} }
    Release $wb; Release $excel
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
  }

  # Workbook 1904
  [string]$path2 = Join-Path $outDir 'excel_1904.xlsx'
  if (Test-Path $path2) { Remove-Item $path2 -Force }
  $excel = $null; $wb = $null
  try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false; $excel.DisplayAlerts = $false
    $wb = $excel.Workbooks.Add()
    $wb.Date1904 = $true
    $ws = $wb.Worksheets.Item(1)
    $ws.Range('A1').NumberFormat = 'yyyy-mm-dd'
    $ws.Range('A1').Formula = '=DATE(2025,12,9)'
    $ws.Range('A1').Value2 = $ws.Range('A1').Value2
    $wb.SaveAs($path2, 51)
    Write-Host "OK: $path2"
  }
  finally {
    if ($wb) { try { $wb.Close($false) } catch {} }
    if ($excel) { try { $excel.Quit() } catch {} }
    Release $wb; Release $excel
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
  }
}

# ---------------------------------------------------------------- DOCX
function Make-DocxExtra {
  Add-Type -AssemblyName System.Drawing
  [string]$path = Join-Path $outDir 'word_extra.docx'
  $png = Join-Path ([System.IO.Path]::GetTempPath()) 'office_reader_fixture2.png'
  if (Test-Path $path) { Remove-Item $path -Force }
  $bmp = New-Object System.Drawing.Bitmap 40, 40
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::FromArgb(255, 20, 160, 60)); $g.Dispose()
  $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

  $word = $null; $doc = $null
  try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.ScreenUpdating = $false
    $word.DisplayAlerts = 0
    $doc = $word.Documents.Add()

    # Them doan moi o cuoi; tra ve Range cua doan do (khong gom dau doan).
    function Add-P([string]$text) {
      $last = $doc.Paragraphs.Last
      $last.Range.ParagraphFormat.Reset(); $last.Range.Font.Reset(); $last.Range.Style = $doc.Styles.Item(-1)
      $start = $last.Range.Start
      $last.Range.InsertBefore($text)
      $doc.Content.InsertParagraphAfter()
      return $doc.Range($start, $start + $text.Length)
    }
    function Sub-Range($r, [string]$needle) {
      $i = $r.Text.IndexOf($needle)
      if ($i -lt 0) { throw "khong thay $needle" }
      return $doc.Range($r.Start + $i, $r.Start + $i + $needle.Length)
    }

    Write-Host '-- alignment'
    (Add-P 'AlignCenter').ParagraphFormat.Alignment = 1
    (Add-P 'AlignRight').ParagraphFormat.Alignment = 2
    (Add-P 'AlignJustify long text long text long text long text long text long text').ParagraphFormat.Alignment = 3

    Write-Host '-- indent + spacing'
    $r = Add-P 'IndentSpacing'
    $r.ParagraphFormat.LeftIndent = 36; $r.ParagraphFormat.FirstLineIndent = 18; $r.ParagraphFormat.RightIndent = 10
    $r.ParagraphFormat.SpaceBefore = 6; $r.ParagraphFormat.SpaceAfter = 12
    $r.ParagraphFormat.LineSpacingRule = 5; $r.ParagraphFormat.LineSpacing = 18

    Write-Host '-- char props'
    $r = Add-P 'Strike Sup Sub Hi Times Caps Small Hidden End'
    (Sub-Range $r 'Strike').Font.StrikeThrough = 1
    (Sub-Range $r 'Sup').Font.Superscript = 1
    (Sub-Range $r 'Sub').Font.Subscript = 1
    (Sub-Range $r 'Hi').HighlightColorIndex = 7
    (Sub-Range $r 'Times').Font.Name = 'Times New Roman'
    (Sub-Range $r 'Caps').Font.AllCaps = 1
    (Sub-Range $r 'Small').Font.SmallCaps = 1
    (Sub-Range $r 'Hidden').Font.Hidden = 1

    Write-Host '-- char styles'
    $r = Add-P 'StrongText EmphText'
    (Sub-Range $r 'StrongText').Style = $doc.Styles.Item(-88)
    (Sub-Range $r 'EmphText').Style = $doc.Styles.Item(-89)

    Write-Host '-- line break + tab'
    [void](Add-P ("Line1" + [char]11 + "Line2`tAfterTab"))

    Write-Host '-- special chars'
    [void](Add-P '  A & B < C > D "q"  ')

    Write-Host '-- bookmark + internal link'
    $r = Add-P 'Target para'
    [void]$doc.Bookmarks.Add('bm1', $r)
    $r = Add-P 'Go: '
    $e = $r.End
    [void]$doc.Hyperlinks.Add($doc.Range($e, $e), '', 'bm1', '', 'Go to bm1')

    Write-Host '-- fields'
    $r = Add-P 'Page: '
    $e = $r.End
    [void]$doc.Fields.Add($doc.Range($e, $e), -1, 'PAGE', $false)

    Write-Host '-- tracked changes'
    $r = Add-P 'Rev: keepgone'
    $word.UserName = 'Fixture'
    $doc.TrackRevisions = $true
    (Sub-Range $r 'gone').Text = 'NEW'
    $doc.TrackRevisions = $false

    Write-Host '-- content control'
    $r = Add-P 'CC: '
    $e = $r.End
    $cc = $doc.ContentControls.Add(1, $doc.Range($e, $e))
    $cc.Range.Text = 'cc value'

    Write-Host '-- comment'
    $r = Add-P 'Commented text'
    [void]$doc.Comments.Add($r, 'a comment')

    Write-Host '-- page break before'
    (Add-P 'Starts new page').ParagraphFormat.PageBreakBefore = $true

    Write-Host '-- nested table'
    [void](Add-P 'Table below')
    $last = $doc.Paragraphs.Last
    $last.Range.ParagraphFormat.Reset(); $last.Range.Font.Reset(); $last.Range.Style = $doc.Styles.Item(-1)
    $t = $doc.Tables.Add($last.Range, 3, 2)
    try { $t.Style = 'Table Grid' } catch { $t.Borders.Enable = $true }
    $t.Cell(1, 1).Range.Text = 'H1'; $t.Cell(1, 2).Range.Text = 'H2'
    $t.Rows.Item(1).HeadingFormat = $true
    $t.Cell(2, 2).Range.Text = 'R2C2'
    $t.Cell(3, 1).Range.Text = 'R3C1'; $t.Cell(3, 2).Range.Text = 'R3C2'
    $t.Rows.Item(3).HeightRule = 1; $t.Rows.Item(3).Height = 40
    $t.Cell(3, 2).VerticalAlignment = 1
    $t.Columns.Item(1).Width = 100
    $inner = $doc.Tables.Add($t.Cell(2, 1).Range, 2, 2)
    $inner.Borders.Enable = $true
    $inner.Cell(1, 1).Range.Text = 'in11'; $inner.Cell(1, 2).Range.Text = 'in12'
    $inner.Cell(2, 1).Range.Text = 'in21'; $inner.Cell(2, 2).Range.Text = 'in22'

    Write-Host '-- floating image'
    $r = Add-P 'Float: '
    $e = $r.End
    $ils = $doc.InlineShapes.AddPicture($png, $false, $true, $doc.Range($e, $e))
    $shape = $ils.ConvertToShape()
    $shape.WrapFormat.Type = 0

    Write-Host '-- last para'
    [void](Add-P 'The end')

    Write-Host '   saving'
    $fmt = 12; $doc.SaveAs2([ref]$path, [ref]$fmt)
    Write-Host "OK: $path"
  }
  finally {
    if ($doc) { try { $doc.Close(0) } catch {} }
    if ($word) { try { $word.Quit() } catch {} }
    Release $doc; Release $word
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    if (Test-Path $png) { Remove-Item $png -Force }
  }
}

if ($Only -in 'all', 'xlsx') { Make-XlsxExtra }
if ($Only -in 'all', 'docx') { Make-DocxExtra }
