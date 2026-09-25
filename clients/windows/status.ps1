<#
.SYNOPSIS
  Show what the device is running: version, mode, address, network, memory and uptime.
.DESCRIPTION
  Read-only: it changes nothing on the device. The session token is never printed.
.EXAMPLE
  .\status.ps1 -Address 10.0.0.42
.EXAMPLE
  $env:SMALLTV_HOST = 'smalltv.local'; .\status.ps1 -Json
#>
param(
    [string]$Address,
    [switch]$Json   # print the raw answers of /api/status and /api/app/health
)
. (Join-Path $PSScriptRoot 'smalltv-common.ps1')
try {
    Initialize-SmallTV $Address
    $s = Read-SmallTVStatus
    if ($Json) {
        $copy = $s | Select-Object *; $copy.token = '<hidden>'
        $copy | ConvertTo-Json -Depth 5
    } else {
        $rescueNote = if ($s.mode -eq 'rescue') { '  (rescue: only the web page and firmware updates work)' } else { '' }
        "device:        $($script:SmallTV.Address)"
        "firmware:      $($s.version)"
        "mode:          $($s.mode)$rescueNote"
        "state:         $($s.state)"
        "network:       $($s.ssid)   ip $($s.ip)"
        "access point:  $($s.ap)"
        "last reset:    $($s.resetReason)"
        "uptime:        $($s.uptime) s"
        "max firmware:  $($s.maxFirmware) bytes"
    }
    if ($s.mode -ne 'app') { exit 0 }
    $r = Invoke-SmallTV -Path '/api/app/health'
    if ($r.Code -ne 200 -or -not $r.Json) { "health:        $(Get-SmallTVHint $r)"; exit 0 }
    $h = $r.Json
    if ($Json) { $r.Body } else {
        "free heap:     $($h.heap) bytes   (lowest seen $($h.heapMin), largest block $($h.maxBlock))"
        "slowest loop:  $($h.tickMax) ms"
        "clock synced:  $($h.ntp)"
        "on screen:     $($h.screen)"
    }
} catch { Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
