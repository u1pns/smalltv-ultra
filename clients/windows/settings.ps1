<#
.SYNOPSIS
  Read or change the device settings.
.DESCRIPTION
  Without -Set, prints all settings. With -Set, changes one or more of them. Changes are
  all-or-nothing: if one value is rejected, nothing is saved and the device says which key.

  Common keys:
    brightness=0..100      screen brightness
    screens=LIST           screens that rotate, comma separated: clock, weather, forecast, status,
                           album, panels
    rotate_s=5..3600       seconds per screen
    tz=POSIX-TZ            time zone, e.g. CET-1CEST,M3.5.0,M10.5.0/3 or EST5EDT,M3.2.0,M11.1.0
    h12=0|1                12-hour clock
    night=0|1  night_start=0..23  night_end=0..23  night_brightness=0..100    night dimming
    city=NAME  lat=..  lon=..  temp=C|F  wind=kmh|ms|mph                weather
    log_udp=0|1            debug log over UDP port 7777 (off by default)
.EXAMPLE
  .\settings.ps1 -Address 10.0.0.42
.EXAMPLE
  .\settings.ps1 -Set 'brightness=40'
.EXAMPLE
  .\settings.ps1 -Set 'screens=clock,weather,panels', 'rotate_s=20'
#>
param(
    [string]$Address,
    [string[]]$Set      # KEY=VALUE pairs
)
. (Join-Path $PSScriptRoot 'smalltv-common.ps1')
try {
    Initialize-SmallTV $Address
    $null = Read-SmallTVStatus
    Assert-AppMode
    if (-not $Set) {
        $r = Invoke-SmallTV -Path '/api/app/settings'
        if ($r.Code -ne 200 -or -not $r.Json) { throw (Get-SmallTVHint $r) }
        $r.Json | Format-List
        exit 0
    }
    $pairs = foreach ($kv in $Set) {
        if ($kv -notmatch '^([A-Za-z0-9_]+)=(.*)$') { throw "expected KEY=VALUE, got: $kv" }
        [Uri]::EscapeDataString($Matches[1]) + '=' + [Uri]::EscapeDataString($Matches[2])
    }
    $body = [Text.Encoding]::UTF8.GetBytes(($pairs -join '&'))
    $r = Invoke-SmallTV -Method POST -Path '/api/app/settings' -WithToken -Body $body -ContentType 'application/x-www-form-urlencoded'
    if ($r.Code -ne 200) {
        $key = if ($r.Json -and $r.Json.PSObject.Properties['key']) { " (key: $($r.Json.key))" } else { '' }
        throw "$(Get-SmallTVHint $r)$key. Nothing was changed."
    }
    "saved: $($Set -join ' ')"
} catch { Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
