<#
  Builds the 60 made-up CVs (PDF + Word) from data\cv-source.txt into data\cvs\,
  plus 2 unreadable files in data\hard-cases\ for the "flag, never skip" demo.
  Nothing to install: plain Windows PowerShell.
  Usage: powershell -ExecutionPolicy Bypass -File scripts\generate-cvs.ps1
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem, System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out  = Join-Path $root 'data\cvs'
$hard = Join-Path $root 'data\hard-cases'
Get-ChildItem $out, $hard -File -ErrorAction SilentlyContinue | Remove-Item
$enc = [Text.Encoding]::GetEncoding(1252)
$monthNames = 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'

# ---------- bullet templates per tool family ({t} = tools, {i} = industry) ----------
$family = @{}
'GoHighLevel','HighLevel','GHL','Zapier','Make','n8n','ClickFunnels','ActiveCampaign','HubSpot','Mailchimp' | % { $family[$_] = 'auto' }
'Twilio' | % { $family[$_] = 'sms' }
'Zendesk','Freshdesk','Gorgias','Intercom','Salesforce Service Cloud','LiveChat','Jira' | % { $family[$_] = 'help' }
'Aircall','Avaya','Mojo Dialer' | % { $family[$_] = 'phone' }
'React','Node.js','TypeScript','PostgreSQL','AWS','MongoDB','Vue','Next.js','Docker','React Native','Google Cloud','Python','Django','C#','.NET','Angular','SQL Server','Azure','Java','Spring Boot','MySQL','JavaScript','PHP','Laravel','WordPress','Vercel' | % { $family[$_] = 'dev' }
'Stripe','Plaid' | % { $family[$_] = 'pay' }
'QuickBooks Online','Xero','Gusto','Bill.com','NetSuite','Expensify','Sage','MYOB','Tally','Zoho Books','Dext','Excel' | % { $family[$_] = 'acct' }
$tpl = @{
  auto  = @('Built and maintained {t} workflows, pipelines and calendars for {i} clients.', 'Automated lead follow-up and appointment reminders with {t} for {i} accounts.')
  sms   = @('Set up {t} numbers and A2P 10DLC registration so {i} text messages were delivered.', 'Managed two-way SMS through {t} for {i} campaigns.')
  help  = @('Handled 50-70 {t} tickets a day for {i} customers with a 95%+ satisfaction score.', 'Wrote {t} macros and help-center articles that cut repeat questions by a third.')
  phone = @('Took inbound and outbound calls on {t}: scheduling, billing and escalations.', 'Handled 40+ calls a day on {t} with clear call notes.')
  dev   = @('Shipped production features with {t} for a {i} product used by thousands of customers.', 'Designed, built and tested {t} code for {i} clients, from database to UI.')
  pay   = @('Integrated {t} for payments and bank connections in a {i} product.', 'Owned the {t} integration end to end, including webhooks and error handling.')
  acct  = @('Ran bank reconciliations and month-end close in {t} for {i}.', 'Categorized transactions and prepared monthly reports in {t} for {i}.')
  admin = @('Used {t} every day to manage calendars, files and follow-ups for {i}.', 'Kept {t} organized and up to date for a busy {i} team.')
}

function JoinNice($items) {
  $a = @($items)
  if ($a.Count -le 1) { return ($a -join '') }
  return (($a[0..($a.Count - 2)] -join ', ') + ' and ' + $a[-1])
}
function FmtDate($ym, $layout) {
  if ($ym -eq 'now') { return @{ A = 'Present'; B = 'present'; C = 'now'; S = 'Present' }[$layout] }
  $y, $m = $ym.Split('-')
  switch ($layout) { 'B' { return "$y-$m" } 'C' { return "$m/$y" } default { return "$($monthNames[[int]$m - 1]) $y" } }
}
function Months($a, $b) { $x = $a.Split('-'); $y = $b.Split('-'); return ([int]$y[0] - [int]$x[0]) * 12 + [int]$y[1] - [int]$x[1] }
function L($t, $s = 10, $b = $false, $sp = 0) { [pscustomobject]@{ t = $t; s = $s; b = $b; sp = $sp } }
function Wrap([string]$text, [int]$max) {
  $res = New-Object System.Collections.Generic.List[string]; $cur = ''
  foreach ($w in ($text -split ' ')) {
    if ($cur.Length -eq 0) { $cur = $w } elseif (($cur.Length + 1 + $w.Length) -le $max) { $cur += ' ' + $w } else { $res.Add($cur); $cur = $w }
  }
  if ($cur.Length) { $res.Add($cur) }
  return , $res
}

# ---------- the CV text for one person in one layout ----------
function Build-Lines($p, $name, $layout) {
  $lines = New-Object System.Collections.Generic.List[object]
  $first = $name.Split(' ')[0]
  $years = [math]::Floor((Months ($p.jobs | % { $_.start } | Sort-Object | Select-Object -First 1) $p.cvdate) / 12)
  $tools = @($p.jobs | % { $_.tools } | ? { $_ } | Select-Object -Unique)
  $inds  = @($p.jobs | % { $_.ind } | Select-Object -Unique)
  $langsProse = $p.langs -replace '; ', ', '
  $certs = if ($p.certs -ne '-') { $p.certs } else { '' }

  $jobBlocks = foreach ($j in $p.jobs) {
    $k = [array]::IndexOf($p.jobs, $j)
    $groups = @($j.tools | Group-Object { if ($family[$_]) { $family[$_] } else { 'admin' } })
    $bul = foreach ($g in $groups) {
      $choice = $tpl[$g.Name][($k + $p.key.Length + [array]::IndexOf($groups, $g)) % 2]
      $choice.Replace('{t}', (JoinNice $g.Group)).Replace('{i}', $j.ind)
    }
    if (-not $bul) { $bul = @("Day-to-day work in $($j.ind).") }
    [pscustomobject]@{ j = $j; bullets = @($bul) }
  }

  switch ($layout) {
    'B' {
      $lines.Add((L $name 18 $true)); $lines.Add((L "Contact: $($p.email) / $($p.phone)" 9)); $lines.Add((L "Based in: $($p.loc) - open to remote US work" 9))
      $lines.Add((L $p.headline 12 $true 8))
      $lines.Add((L 'CORE SKILLS' 11 $true 10)); $lines.Add((L ((@($tools) + $p.extra) -join ' | ') 10))
      $lines.Add((L 'LANGUAGES' 11 $true 10)); $p.langs.Split(';') | % { $lines.Add((L ('* ' + $_.Trim()) 10)) }
      $lines.Add((L 'WORK HISTORY' 11 $true 10))
      foreach ($b in $jobBlocks) {
        $lines.Add((L "$($b.j.company) | $($b.j.title) | $(FmtDate $b.j.start 'B') to $(FmtDate $b.j.end 'B')" 10 $true 6))
        $b.bullets | % { $lines.Add((L "* $_" 10)) }
      }
      $lines.Add((L 'EDUCATION' 11 $true 10)); $lines.Add((L $p.edu 10))
      if ($certs) { $lines.Add((L 'CERTIFICATIONS' 11 $true 10)); $lines.Add((L $certs 10)) }
      $lines.Add((L "Last updated: $($p.cvdate)" 8 $false 14))
    }
    'C' {
      $lines.Add((L 'Curriculum Vitae' 9)); $lines.Add((L $name 14 $true 4)); $lines.Add((L "$($p.loc) - $($p.phone) - $($p.email)" 9))
      $lines.Add((L 'About me' 11 $true 12))
      $lines.Add((L "Hi! I'm $first, a $($p.headline.ToLower()) with about $years years of experience in $(JoinNice $inds). I speak $langsProse. Tools I use: $(JoinNice $tools). Also good at: $($p.extra)." 10))
      $lines.Add((L 'Experience' 11 $true 12))
      foreach ($b in $jobBlocks) {
        $lines.Add((L "$(FmtDate $b.j.start 'C') - $(FmtDate $b.j.end 'C'): $($b.j.title) at $($b.j.company) ($($b.j.ind))" 10 $true 6))
        $lines.Add((L ($b.bullets -join ' ') 10))
      }
      $lines.Add((L "Education: $($p.edu)" 10 $false 12))
      if ($certs) { $lines.Add((L "Certificates: $certs" 10)) }
    }
    default {
      # A (classic) and S (scanned) share this layout
      $lines.Add((L $name.ToUpper() 20 $true)); $lines.Add((L $p.headline 12)); $lines.Add((L "$($p.email)  |  $($p.phone)  |  $($p.loc)" 9 $false 4))
      $lines.Add((L "CV updated: $(FmtDate $p.cvdate 'A')" 8))
      $lines.Add((L 'SUMMARY' 11 $true 12))
      $lines.Add((L "$($p.headline) with $years+ years of experience in $(JoinNice $inds). Strong in $($p.extra)." 10))
      $lines.Add((L 'EXPERIENCE' 11 $true 12))
      foreach ($b in $jobBlocks) {
        $lines.Add((L "$($b.j.title) - $($b.j.company)" 10 $true 6)); $lines.Add((L "$(FmtDate $b.j.start 'A') - $(FmtDate $b.j.end 'A')  |  $($b.j.ind)" 9))
        $b.bullets | % { $lines.Add((L "- $_" 10)) }
      }
      $lines.Add((L 'SKILLS' 11 $true 12)); $lines.Add((L ((@($tools) + $p.extra) -join ', ') 10))
      $lines.Add((L 'LANGUAGES' 11 $true 12)); $lines.Add((L $langsProse 10))
      $lines.Add((L 'EDUCATION' 11 $true 12)); $lines.Add((L $p.edu 10))
      if ($certs) { $lines.Add((L 'CERTIFICATIONS' 11 $true 12)); $lines.Add((L $certs 10)) }
    }
  }
  return , $lines
}

# ---------- file writers ----------
function Bytes($s) { return , $enc.GetBytes($s) }
function Concat([object[]]$parts) { $ms = New-Object IO.MemoryStream; foreach ($x in $parts) { $ms.Write($x, 0, $x.Length) }; return , $ms.ToArray() }
function Stream-Obj($dict, [byte[]]$data) { return , (Concat @((Bytes "<< $dict /Length $($data.Length) >>`nstream`n"), $data, (Bytes "`nendstream"))) }
function Pdf-Bytes([object[]]$objects) {
  $ms = New-Object IO.MemoryStream
  $w = { param($s) $b = $enc.GetBytes($s); $ms.Write($b, 0, $b.Length) }
  & $w "%PDF-1.4`n"
  $offs = @()
  for ($i = 0; $i -lt $objects.Count; $i++) {
    $offs += $ms.Position; & $w "$($i + 1) 0 obj`n"; $ms.Write($objects[$i], 0, $objects[$i].Length); & $w "`nendobj`n"
  }
  $xref = $ms.Position
  & $w "xref`n0 $($objects.Count + 1)`n0000000000 65535 f `n"
  foreach ($o in $offs) { & $w ("{0:D10} 00000 n `n" -f $o) }
  & $w "trailer`n<< /Size $($objects.Count + 1) /Root 1 0 R >>`nstartxref`n$xref`n%%EOF`n"
  return , $ms.ToArray()
}
function Write-Pdf($path, $lines) {
  $pages = New-Object System.Collections.Generic.List[string]; $ops = ''; $y = 750
  foreach ($l in $lines) {
    $y -= $l.sp
    foreach ($w in (Wrap $l.t ([int](500 / ($l.s * 0.52))))) {
      if ($y -lt 70) { $pages.Add($ops); $ops = ''; $y = 750 }
      $y -= [int]($l.s * 1.4)
      $f = if ($l.b) { 'F2' } else { 'F1' }
      $ops += "BT /$f $($l.s) Tf 54 $y Td ($($w.Replace('\','\\').Replace('(','\(').Replace(')','\)'))) Tj ET`n"
    }
  }
  $pages.Add($ops)
  $kids = (0..($pages.Count - 1) | % { "$(5 + 2 * $_) 0 R" }) -join ' '
  $objs = @((Bytes '<< /Type /Catalog /Pages 2 0 R >>'), (Bytes "<< /Type /Pages /Kids [$kids] /Count $($pages.Count) >>"),
    (Bytes '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'),
    (Bytes '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>'))
  for ($i = 0; $i -lt $pages.Count; $i++) {
    $objs += , (Bytes "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents $(6 + 2 * $i) 0 R >>")
    $objs += , (Stream-Obj '' (Bytes $pages[$i]))
  }
  [IO.File]::WriteAllBytes($path, (Pdf-Bytes $objs))
}
function Write-ImagePdf($path, [Drawing.Bitmap]$bmp) {
  $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | ? { $_.MimeType -eq 'image/jpeg' }
  $ep = New-Object Drawing.Imaging.EncoderParameters 1
  $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality, [long]55)
  $ms = New-Object IO.MemoryStream; $bmp.Save($ms, $codec, $ep); $jpg = $ms.ToArray()
  $objs = @((Bytes '<< /Type /Catalog /Pages 2 0 R >>'), (Bytes '<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
    (Bytes '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R >>'),
    (Stream-Obj '' (Bytes 'q 595 0 0 842 0 0 cm /Im1 Do Q')),
    (Stream-Obj "/Type /XObject /Subtype /Image /Width $($bmp.Width) /Height $($bmp.Height) /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode" $jpg))
  [IO.File]::WriteAllBytes($path, (Pdf-Bytes $objs))
}
function New-ScanBitmap($lines, [int]$noise, [int]$ink) {
  $bmp = New-Object Drawing.Bitmap 1240, 1754
  $g = [Drawing.Graphics]::FromImage($bmp); $g.Clear([Drawing.Color]::FromArgb(242, 240, 233))
  $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAlias; $g.RotateTransform(0.7)
  $brush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb($ink, $ink, $ink + 5)); $y = 90
  foreach ($l in $lines) {
    $y += $l.sp * 2; $px = $l.s * 2.1
    $font = New-Object Drawing.Font 'Arial', $px, ($(if ($l.b) { 'Bold' } else { 'Regular' })), ([Drawing.GraphicsUnit]::Pixel)
    foreach ($w in (Wrap $l.t ([int](1040 / ($px * 0.52))))) { $g.DrawString($w, $font, $brush, 110, $y); $y += $px * 1.45 }
  }
  $g.ResetTransform(); $rnd = New-Object Random 7
  for ($i = 0; $i -lt $noise; $i++) { $c = $rnd.Next(60, 200); $g.FillEllipse((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb($c, $c, $c))), $rnd.Next(1240), $rnd.Next(1754), $rnd.Next(1, 4), $rnd.Next(1, 4)) }
  $g.FillRectangle((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(40, 90, 90, 90))), 1180, 0, 14, 1754)   # scanner streak
  $g.Dispose(); return $bmp
}
function Write-Docx($path, $lines) {
  $body = ($lines | % {
      $rpr = "<w:rPr>$(if ($_.b) { '<w:b/>' })<w:sz w:val=`"$([int]($_.s * 2))`"/></w:rPr>"
      "<w:p><w:pPr><w:spacing w:before=`"$([int]($_.sp * 20))`" w:after=`"40`"/></w:pPr><w:r>$rpr<w:t xml:space=`"preserve`">$([Security.SecurityElement]::Escape($_.t))</w:t></w:r></w:p>"
    }) -join ''
  $parts = [ordered]@{
    '[Content_Types].xml' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'
    '_rels/.rels'         = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'
    'word/document.xml'   = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:document xmlns:w=`"http://schemas.openxmlformats.org/wordprocessingml/2006/main`"><w:body>$body<w:sectPr><w:pgSz w:w=`"12240`" w:h=`"15840`"/><w:pgMar w:top=`"1080`" w:right=`"1080`" w:bottom=`"1080`" w:left=`"1080`" w:header=`"720`" w:footer=`"720`" w:gutter=`"0`"/></w:sectPr></w:body></w:document>"
  }
  $zip = [IO.Compression.ZipFile]::Open($path, 'Create')
  foreach ($k in $parts.Keys) {
    $sw = New-Object IO.StreamWriter ($zip.CreateEntry($k).Open()), (New-Object Text.UTF8Encoding $false)
    $sw.Write($parts[$k]); $sw.Dispose()
  }
  $zip.Dispose()
}

# ---------- read the source list and write every file ----------
$manifest = @()
foreach ($row in (Get-Content (Join-Path $root 'data\cv-source.txt') -Encoding UTF8 | ? { $_ -and -not $_.StartsWith('#') })) {
  $f = $row.Split('|')
  $p = [pscustomobject]@{ key = $f[0]; email = $f[2]; phone = $f[3]; loc = $f[4]; langs = $f[5]; headline = $f[6]; extra = $f[8]; edu = $f[9]; certs = $f[10]; cvdate = $f[13]
    jobs = @($f[7].Split(';') | % { $j = $_.Split('~'); [pscustomobject]@{ title = $j[0]; company = $j[1]; start = $j[2]; end = $(if ($j[3] -eq 'now') { 'now' } else { $j[3] }); tools = @($j[4].Split(',') | ? { $_ -ne '-' }); ind = $j[5] } })
  }
  $names = $f[1].Split('/'); $files = $f[11].Split('/'); $layouts = $f[12].Split('/')
  for ($k = 0; $k -lt $files.Count; $k++) {
    $name = $names[[math]::Min($k, $names.Count - 1)]; $layout = $layouts[[math]::Min($k, $layouts.Count - 1)]
    $lines = Build-Lines $p $name $layout
    $path = Join-Path $out $files[$k]
    if ($layout -eq 'S') { $bmp = New-ScanBitmap $lines 5000 45; Write-ImagePdf $path $bmp; $bmp.Dispose() }
    elseif ($path.EndsWith('.pdf')) { Write-Pdf $path $lines }
    else { Write-Docx $path $lines }
    $note = @()
    if ($files.Count -gt 1) { $note += 'same person sent twice' }
    if ($p.key -match '^[A-Z]\d+a$') { $note += 'OLD version (an updated CV exists)' }
    if ($p.key -match '^[A-Z]\d+b$') { $note += 'UPDATED version (replaces the old one)' }
    if ($layout -eq 'S') { $note += 'scanned image only - no text layer' }
    $manifest += [pscustomobject]@{ file = $files[$k]; person = $name; email = $p.email; cv_date = $p.cvdate; layout = $layout; note = ($note -join '; ') }
  }
}
$manifest | Export-Csv (Join-Path $root 'data\cv-manifest.csv') -NoTypeInformation -Encoding UTF8

# ---------- hard cases that must be FLAGGED, never skipped ----------
$smudge = New-Object System.Collections.Generic.List[object]; 1..25 | % { $smudge.Add((L ('~ ' * 30) 9)) }
$bmp = New-ScanBitmap $smudge 90000 225; Write-ImagePdf (Join-Path $hard 'Blurry_Phone_Photo_CV.pdf') $bmp; $bmp.Dispose()
$rnd = New-Object Random 3; $junk = New-Object byte[] 4096; $rnd.NextBytes($junk); [IO.File]::WriteAllBytes((Join-Path $hard 'Corrupted_Download_CV.docx'), $junk)

Write-Host "CVs written: $((Get-ChildItem $out -File).Count)  (pdf: $((Get-ChildItem $out -Filter *.pdf).Count), docx: $((Get-ChildItem $out -Filter *.docx).Count))"
Write-Host "Hard-case files: $((Get-ChildItem $hard -File).Count)"
