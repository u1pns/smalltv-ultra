<#
.SYNOPSIS
  Show a text panel on the device, composed from the command line.
.DESCRIPTION
  Rows are drawn top to bottom in this order: -Big, then -Line, then -KeyValue, then -Bar
  (at most 8 rows; big text takes two).
  A one-off panel (the default) is kept in memory only: it never writes the flash. With -Save the
  panel is stored as p-NAME.jpp: it survives restarts and rotates with the other panels (turn on
  the "panels" screen in the web page). Do not re-save one every minute: save only when its
  content has really changed.
.EXAMPLE
  .\send-panel.ps1 -Title Home -Big 'Dinner ready' -Line 'Come down'
.EXAMPLE
  .\send-panel.ps1 -KeyValue 'CPU=42 %' -Bar '42:' -Seconds 15
.EXAMPLE
  .\send-panel.ps1 -Save stocks -TtlHours 8 -Title Stocks -KeyValue 'ACME=12.40','EURUSD=1.09'
.EXAMPLE
  .\send-panel.ps1 -File .\my-panel.txt
#>
param(
    [string]$Address,
    [string]$Title,                 # up to 24 bytes, top left
    [string]$Big,                   # one line of big text (two rows)
    [string[]]$Line,                # lines of normal text
    [ValidateSet('normal', 'accent', 'alert')][string]$Tone = 'normal',   # colour of -Line
    [string[]]$KeyValue,            # 'Label=Value': label left, value right
    [string[]]$Bar,                 # 'PERCENT:text': a gauge
    [ValidateRange(5, 120)][int]$Seconds = 0,   # time on screen (default 8)
    [switch]$Alert,                 # white flash and full brightness when it appears
    [string]$Save,                  # store as p-NAME.jpp instead of showing it once
    [int]$TtlHours = 0,             # with -Save: expires and is deleted after this many hours
    [string]$File                   # send an already written PANEL1 file as it is
)
. (Join-Path $PSScriptRoot 'smalltv-common.ps1')

# Panel limits (the device's, from the panel API).
$PanelMaxBytes = 512; $LineMaxBytes = 96; $MaxRows = 8

try {
    $utf8 = New-Object Text.UTF8Encoding($false)
    function Clean([string]$t) { return ($t -replace "[`t`r`n]", ' ') }
    if ($File) {
        $text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $File).Path, $utf8) -replace "`r`n", "`n"
        if (-not $text.StartsWith("PANEL1`n")) { throw 'a panel file must start with the line PANEL1' }
    } else {
        if ($TtlHours -and -not $Save) { throw '-TtlHours only makes sense with -Save' }
        $rows = New-Object System.Collections.Generic.List[string]; $row = 0
        $add = {
            param([int]$height, [string]$line)
            if ($row + $height -gt $MaxRows) { throw "too many rows: a panel has $MaxRows rows (big text takes two)" }
            if ($utf8.GetByteCount($line) + 1 -gt $LineMaxBytes) { throw "line too long (max $LineMaxBytes bytes): $line" }
            $rows.Add($line); Set-Variable -Name row -Value ($row + $height) -Scope 1
        }
        # Size and tone keywords of the PANEL1 protocol: large/normal/small, normal/accent/alert.
        $toneWord = $Tone
        if ($Big) { & $add 2 "L`t$row`tlarge`tnormal`t$(Clean $Big)" }
        foreach ($l in @($Line | Where-Object { $_ })) { & $add 1 "L`t$row`tnormal`t$toneWord`t$(Clean $l)" }
        foreach ($kv in @($KeyValue | Where-Object { $_ })) {
            if ($kv -notmatch '^([^=]*)=(.*)$') { throw "-KeyValue expects Label=Value, got: $kv" }
            & $add 1 "K`t$row`t$(Clean $Matches[1])`t$(Clean $Matches[2])"
        }
        foreach ($b in @($Bar | Where-Object { $_ })) {
            if ($b -notmatch '^(\d+)(:(.*))?$') { throw "-Bar expects PERCENT:text, got: $b" }
            $pct = [math]::Min([int]$Matches[1], 100); $label = if ($Matches[3]) { $Matches[3] } else { '' }
            & $add 1 "B`t$row`t$pct`t$(Clean $label)"
        }
        if ($rows.Count -eq 0) { throw 'nothing to show: give -Big, -Line, -KeyValue, -Bar or -File' }
        $head = @('PANEL1')
        if ($Title) { $head += "T`t$(Clean $Title)" }
        if ($Seconds) { $head += "S`t$Seconds" }
        if ($Alert) { $head += "X`tevery" }
        if ($Save) {
            $now = [long][Math]::Floor(([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalSeconds)
            $head += "G`t$now"
            if ($TtlHours) { $head += "V`t$($now + 3600 * $TtlHours)" }
        }
        $text = (($head + $rows) -join "`n") + "`n"
    }
    if ($Save -and $Save -notmatch '^[A-Za-z0-9_-]{1,23}$') { throw '-Save: use letters, digits, - and _ (max 23)' }
    $bytes = $utf8.GetBytes($text)
    if ($bytes.Length -gt $PanelMaxBytes) { throw "the panel is $($bytes.Length) bytes; the limit is $PanelMaxBytes" }

    Initialize-SmallTV $Address
    $null = Read-SmallTVStatus
    Assert-AppMode
    if ($Save) {
        $r = Send-SmallTVResource -Name "p-$Save.jpp" -Data $bytes -PartType 'text/plain'
        if ($r.Code -ne 200) { throw (Get-SmallTVHint $r) }
        "saved as p-$Save.jpp (shown on the 'panels' screen; turn it on in the web page if it is off)"
    } else {
        $r = Invoke-SmallTV -Method POST -Path '/api/app/panel' -WithToken -Body $bytes -ContentType 'text/plain; charset=utf-8'
        if ($r.Code -ne 200) { throw (Get-SmallTVHint $r) }
        "shown: $($r.Json.rows) rows, $($r.Json.durationS) s on screen"
        if ($r.Json.invalid) { Write-Host "WARNING: the device discarded $($r.Json.invalid) line(s) of this panel" -ForegroundColor Yellow }
    }
} catch { Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
