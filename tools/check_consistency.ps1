<#
Consistency check for guide.txt: quote/apostrophe style, trailing whitespace,
emoji (only the chat bubble is allowed), legacy dialogue notation, known
misspellings, known item-casing regressions, and Bank header sequencing.

Usage:
  powershell -File tools\check_consistency.ps1              # report only
  powershell -File tools\check_consistency.ps1 -Fix          # also fixes the
                                                              # mechanical issues
                                                              # (curly quotes,
                                                              # trailing whitespace,
                                                              # stray emoji)

Everything else (dialogue notation, misspellings, item casing, bank headers)
is report-only on purpose -- those need a human to judge context before
changing anything. Extend $Misspellings / $ItemCasing as new issues are found;
they are seed lists, not exhaustive.

Exit code: 0 if clean, 1 if anything was flagged (fixed mechanical issues do
not count against this -- only unresolved/report-only findings do).
#>
param(
  [string]$Path = (Join-Path $PSScriptRoot "..\guide.txt"),
  [switch]$Fix
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Path)) { throw "File not found: $Path" }

$curlyApos1 = [char]0x2019
$curlyApos2 = [char]0x2018
$curlyOpenQ = [char]0x201C
$curlyCloseQ = [char]0x201D
$bubble = [char]::ConvertFromUtf32(0x1F4AC)
# any emoji/symbol except the chat bubble (U+1F4AC), the bullet (U+2022) and the check mark (U+2713)
$emojiRx = '(?:[' + [char]0x2600 + '-' + [char]0x2712 + [char]0x2714 + '-' + [char]0x27BF + [char]0x2300 + '-' + [char]0x23FF + ']|' + [char]0xD83C + '[' + [char]0xDC00 + '-' + [char]0xDFFF + ']|' + [char]0xD83D + '[' + [char]0xDC00 + '-' + [char]0xDCAB + [char]0xDCAD + '-' + [char]0xDFFF + ']|' + [char]0xD83E + '[' + [char]0xDC00 + '-' + [char]0xDFFF + '])' + [char]0xFE0F + '?'

$lines = Get-Content $Path -Encoding UTF8
$issues = @()   # each: [pscustomobject]@{ Line=n; Category='...'; Detail='...' }

# --- known misspellings (case-insensitive substring). Seed list -- extend as found. ---
$Misspellings = @(
  @{ Wrong = 'Geilinor';        Right = 'Gielinor' }
  @{ Wrong = 'Archeology';      Right = 'Archaeology' }
  @{ Wrong = 'Archeaology';     Right = 'Archaeology' }
  @{ Wrong = 'Taverly';         Right = 'Taverley' }
  @{ Wrong = 'Taverely';        Right = 'Taverley' }
  @{ Wrong = 'Al-khaird';       Right = 'Al Kharid' }
  @{ Wrong = 'Al-kharid';       Right = 'Al Kharid' }
  @{ Wrong = 'Alkharid';        Right = 'Al Kharid' }
  @{ Wrong = 'Barcrawl';        Right = 'Bar Crawl' }
  @{ Wrong = 'Ardounge';        Right = 'Ardougne' }
  @{ Wrong = 'Treaure';         Right = 'Treasure' }
  @{ Wrong = 'hairdesser';      Right = 'hairdresser' }
  @{ Wrong = 'entrace';         Right = 'entrance' }
  @{ Wrong = 'Pikkipstix';      Right = 'Pikkupstix' }
  @{ Wrong = 'Horvic';          Right = 'Horvik' }
  @{ Wrong = 'Jatixs';          Right = "Jatix's" }
  @{ Wrong = 'Lourehound';      Right = 'Lorehound' }
  @{ Wrong = 'arterfacts';      Right = 'artefacts' }
  @{ Wrong = 'dwavern';         Right = 'dwarven' }
  @{ Wrong = 'filration';       Right = 'filtration' }
  @{ Wrong = 'grimiore';        Right = 'grimoire' }
  @{ Wrong = 'Hearder';         Right = 'Herder' }
  @{ Wrong = 'Ghost Ahoy';      Right = 'Ghosts Ahoy' }
  @{ Wrong = "Lower's Archery"; Right = "Lowe's Archery" }
  @{ Wrong = 'Grimey';          Right = 'Grimy' }
  @{ Wrong = 'Varrrock';        Right = 'Varrock' }
  @{ Wrong = 'rannar';          Right = 'ranarr' }
  @{ Wrong = 'ghost speak';     Right = 'ghostspeak' }
  @{ Wrong = 'travellers necklace'; Right = "Traveller's necklace" }
  @{ Wrong = 'explorers ring';  Right = "Explorer's ring" }
  @{ Wrong = 'anti dragon';     Right = 'anti-dragon' }
  @{ Wrong = 'Mytic';           Right = 'Mystic' }
  @{ Wrong = 'taliman';         Right = 'talisman' }
  @{ Wrong = "Champion's Guild"; Right = "Champions' Guild" }
  @{ Wrong = '\btheres\b';      Right = "there's"; Rx = $true }
)

# --- missing apostrophe in common contractions (case-insensitive whole word) ---
$Contractions = @('dont','wont','cant','arent','isnt','wasnt','werent','youre','theyre','weve','ive','doesnt','didnt','havent','hasnt','hadnt','shouldnt','couldnt','wouldnt')

# --- known item-casing regressions (case-SENSITIVE exact form). Seed list from
#     the 2026-09 wiki-verification pass -- extend as new items get verified. ---
$ItemCasing = @(
  @{ Wrong = 'Archaeology Journal';   Right = 'Archaeology journal' }
  @{ Wrong = 'Jug of Water';          Right = 'Jug of water' }
  @{ Wrong = 'Rotten Tomato';         Right = 'Rotten tomato' }
  @{ Wrong = 'Rat Poison';            Right = 'Rat poison' }
  @{ Wrong = 'Purple Dye';            Right = 'Purple dye' }
  @{ Wrong = 'Gnome Spice';           Right = 'Gnome spice' }
  @{ Wrong = 'Elemental Bars';        Right = 'Elemental bars' }
  @{ Wrong = 'Iron Chainbody';        Right = 'Iron chainbody' }
  @{ Wrong = 'Oak Longbow';           Right = 'Oak longbow' }
  @{ Wrong = 'Willow Longbow';        Right = 'Willow longbow' }
  @{ Wrong = 'Studded Body & Chaps';  Right = 'Studded body & chaps' }
  @{ Wrong = 'Shiny Money Pouch';     Right = 'Shiny money pouch' }
  @{ Wrong = 'Monkey Paw';            Right = 'Monkey paw' }
  @{ Wrong = 'Grimey Rogue''s Purse'; Right = 'Grimy rogue''s purse' }
  @{ Wrong = 'Shiny Light foot';      Right = 'Shiny light foot' }
  @{ Wrong = 'Phlegmatic Bead';       Right = 'Phlegmatic bead' }
  @{ Wrong = 'Runescape';             Right = 'RuneScape' }
  @{ Wrong = 'Tzhaar';                Right = 'TzHaar' }
  @{ Wrong = 'Mcgrubers';             Right = "McGrubor's" }
  @{ Wrong = "Mcgrubor's";            Right = "McGrubor's" }
  @{ Wrong = 'excalibur';             Right = 'Excalibur' }
  @{ Wrong = 'silverlight';           Right = 'Silverlight' }
  @{ Wrong = 'strange implement';     Right = 'Strange implement' }
  @{ Wrong = 'display cabinet key';   Right = 'Display cabinet key' }
  @{ Wrong = 'phoenix quill pen';     Right = 'Phoenix quill pen' }
  @{ Wrong = "varmen's notes";        Right = "Varmen's notes" }
  @{ Wrong = 'demonic sigil';         Right = 'Demonic sigil' }
  @{ Wrong = 'demonic tome';          Right = 'Demonic tome' }
  @{ Wrong = "traveller's necklace";  Right = "Traveller's necklace" }
  @{ Wrong = 'Big Day out';           Right = 'Big Day Out' }
  @{ Wrong = 'Hermit Permit(?!s)';    Right = 'Hermit Permits'; Rx = $true }
  @{ Wrong = '\bxp\b';                Right = 'XP'; Rx = $true }
  @{ Wrong = '\bosrs\b';              Right = 'OSRS'; Rx = $true }
)

for ($i = 0; $i -lt $lines.Count; $i++) {
  $ln = $i + 1
  $l = $lines[$i]

  if ($l -match [regex]::Escape($curlyApos1) -or $l -match [regex]::Escape($curlyApos2)) {
    $issues += [pscustomobject]@{ Line=$ln; Category='curly-apostrophe'; Detail=$l.Trim() }
  }
  if ($l -match [regex]::Escape($curlyOpenQ) -or $l -match [regex]::Escape($curlyCloseQ)) {
    $issues += [pscustomobject]@{ Line=$ln; Category='curly-quote'; Detail=$l.Trim() }
  }
  if ($l -match '[ \t]+$') {
    $issues += [pscustomobject]@{ Line=$ln; Category='trailing-whitespace'; Detail=$l.Trim() }
  }
  if ($l -match $emojiRx) {
    $issues += [pscustomobject]@{ Line=$ln; Category='emoji'; Detail=$l.Trim() }
  }
  if ($l -match '(?i)\bOption\s+\d' -or $l -match '(?i)\(Chat\s+\d') {
    $issues += [pscustomobject]@{ Line=$ln; Category='legacy-dialogue-notation'; Detail=$l.Trim() }
  }
  if ($l -match '(?i)\[?\(?Note:\S') {
    $issues += [pscustomobject]@{ Line=$ln; Category='note-colon-spacing'; Detail=$l.Trim() }
  }
  if ($l -match [regex]::Escape($bubble) + '\d') {
    $issues += [pscustomobject]@{ Line=$ln; Category='bubble-spacing'; Detail=$l.Trim() }
  }
  if ($l -match '\S {2,}\S') {
    $issues += [pscustomobject]@{ Line=$ln; Category='double-space'; Detail=$l.Trim() }
  }
  if ($l -match '^#\s*\d+\s+Bank') {
    $issues += [pscustomobject]@{ Line=$ln; Category='bank-header-format'; Detail="should be '# Bank N', not '# N Bank' | $($l.Trim())" }
  }
  if ($l -match ',,|, ,') {
    $issues += [pscustomobject]@{ Line=$ln; Category='double-comma'; Detail=$l.Trim() }
  }
  if ($l -cmatch '^\s*[-*]\s+[a-z]' -and $l -notmatch '^\s*[-*]\s+https?://') {
    $issues += [pscustomobject]@{ Line=$ln; Category='lowercase-step-start'; Detail=$l.Trim() }
  }
  foreach ($m in $Misspellings) {
    $pat = if ($m.Rx) { $m.Wrong } else { [regex]::Escape($m.Wrong) }
    if ($l -match $pat) {
      $issues += [pscustomobject]@{ Line=$ln; Category='misspelling'; Detail="'$($m.Wrong)' -> should be '$($m.Right)' | $($l.Trim())" }
    }
  }
  foreach ($w in $Contractions) {
    if ($l -match "(?i)\b$w\b") {
      $issues += [pscustomobject]@{ Line=$ln; Category='missing-apostrophe'; Detail="'$w' | $($l.Trim())" }
    }
  }
  foreach ($c in $ItemCasing) {
    $cpat = if ($c.Rx) { $c.Wrong } else { [regex]::Escape($c.Wrong) }
    if ($l -cmatch $cpat) {
      $issues += [pscustomobject]@{ Line=$ln; Category='item-casing'; Detail="'$($c.Wrong)' -> should be '$($c.Right)' | $($l.Trim())" }
    }
  }
}

# --- Bank header sequencing ---
$bankLines = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^#\s*Bank\s+(\d+)\s*$') { $bankLines += [pscustomobject]@{ Line=$i+1; Num=[int]$Matches[1] } }
}
for ($i = 1; $i -lt $bankLines.Count; $i++) {
  $prev = $bankLines[$i-1].Num
  $cur = $bankLines[$i].Num
  if ($cur -ne $prev + 1) {
    $issues += [pscustomobject]@{ Line=$bankLines[$i].Line; Category='bank-sequence'; Detail="Bank $cur follows Bank $prev (expected Bank $($prev+1))" }
  }
}

# --- apply mechanical fixes if requested ---
if ($Fix) {
  $changed = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $orig = $lines[$i]
    $l = $orig
    if ($l -match $emojiRx) {
      $l = [regex]::Replace($l, "[ \t]*(?:$emojiRx[ \t]*)+`$", '')
      $l = [regex]::Replace($l, "^(\s*[-*]\s+)(?:$emojiRx[ \t]*)+", '$1')
      $l = [regex]::Replace($l, "[ \t]*(?:$emojiRx[ \t]*)+", ' ')
    }
    $l = $l -replace [regex]::Escape($curlyApos1), "'" -replace [regex]::Escape($curlyApos2), "'"
    $l = $l -replace [regex]::Escape($curlyOpenQ), '"' -replace [regex]::Escape($curlyCloseQ), '"'
    $l = $l -replace '[ \t]+$', ''
    if ($l -ne $orig) { $lines[$i] = $l; $changed = $true }
  }
  if ($changed) {
    $out = ($lines -join "`r`n")
    [System.IO.File]::WriteAllText($Path, $out, [System.Text.UTF8Encoding]::new($false))
    Write-Output "Fixed curly quotes/apostrophes, stray emoji and trailing whitespace in place."
  } else {
    Write-Output "No mechanical fixes needed."
  }
  $issues = @($issues | Where-Object { $_.Category -notin @('curly-apostrophe','curly-quote','trailing-whitespace','emoji') })
}

# --- report ---
if ($issues.Count -eq 0) {
  Write-Output "guide.txt is consistent: no issues found."
  exit 0
}

Write-Output "Found $($issues.Count) issue(s):"
$issues | Group-Object Category | Sort-Object Name | ForEach-Object {
  Write-Output ""
  Write-Output "== $($_.Name) ($($_.Count)) =="
  $_.Group | ForEach-Object { Write-Output ("  L{0}: {1}" -f $_.Line, $_.Detail) }
}
exit 1
