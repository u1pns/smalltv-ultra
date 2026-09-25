<#
.SYNOPSIS
  Install a firmware image (.bin) over Wi-Fi, the same way the device web page does.
.DESCRIPTION
  DO NOT CUT THE POWER while the update runs or while the device restarts. The device checks the
  whole image (size, MD5, structure) before it replaces anything; a rejected or interrupted upload
  leaves the old firmware in place and you can simply try again.
  Works in both modes: normal (app) and rescue.
.EXAMPLE
  .\update-firmware.ps1 -Address 10.0.0.42 -File .\smalltv-ultra-v0.6.5.bin
#>
param(
    [string]$Address,
    [Parameter(Mandatory = $true)][string]$File,
    [switch]$Yes,      # do not ask for confirmation
    [switch]$NoWait    # do not wait for the device to come back after the restart
)
. (Join-Path $PSScriptRoot 'smalltv-common.ps1')
try {
    Initialize-SmallTV $Address
    $path = (Resolve-Path -LiteralPath $File).Path
    $data = [IO.File]::ReadAllBytes($path)
    # ESP8266 images start with the byte 0xE9. A resource pack starts with "JPR1".
    if ($data.Length -ge 4 -and [Text.Encoding]::ASCII.GetString($data, 0, 4) -eq 'JPR1') {
        throw "$File is a resource pack (.res), not firmware: use upload-resources.ps1"
    }
    if ($data.Length -lt 1 -or $data[0] -ne 0xE9) { throw "$File is not an ESP8266 firmware image (it does not start with 0xE9)" }
    $md5 = Get-FileMD5 $data

    $s = Read-SmallTVStatus
    if ($s.maxFirmware -and $data.Length -gt [long]$s.maxFirmware) {
        throw "the image is $($data.Length) bytes; the device accepts at most $($s.maxFirmware)"
    }
    "device:     $($script:SmallTV.Address)  (running $($s.version), $($s.mode) mode)"
    "firmware:   $(Split-Path -Leaf $path)  $($data.Length) bytes  md5 $md5"
    ''
    Write-Host 'Do NOT cut the power until the device is back (about a minute).' -ForegroundColor Yellow
    if (-not $Yes) {
        $answer = Read-Host 'Install it now? [y/N]'
        if ($answer -notmatch '^(y|yes)$') { 'cancelled, nothing was sent'; exit 1 }
    }

    $budget = Get-UploadBudget $data.Length
    "uploading (up to ${budget}s)..."
    $oldToken = $script:SmallTV.Token
    $mp = New-MultipartBody -FieldName 'firmware' -FileName (Split-Path -Leaf $path) -Data $data
    $r = Invoke-SmallTV -Method POST -Path '/update' -WithToken -Body $mp.Body -ContentType $mp.ContentType `
        -TimeoutSec $budget -Headers @{ 'X-Firmware-Size' = [string]$data.Length; 'X-Firmware-MD5' = $md5 }
    if ($r.Code -eq 0) {
        Write-Host 'Contact was lost during the upload. The update has NOT been confirmed.' -ForegroundColor Red
        Write-Host 'Check the version with status.ps1 before trying again.'
        exit 3
    }
    if ($r.Code -ne 200 -or -not $r.Json -or -not $r.Json.ok) {
        Write-Host "rejected: $(Get-SmallTVHint $r)" -ForegroundColor Red
        Write-Host 'The old firmware is still installed. You can try again.'
        exit 3
    }
    'image verified; the device is restarting.'
    # The field is "warning" since firmware 0.6.4; 0.6.3 and older call it "aviso".
    $warn = if ($r.Json.PSObject.Properties['warning'] -and $r.Json.warning) { $r.Json.warning } elseif ($r.Json.PSObject.Properties['aviso'] -and $r.Json.aviso) { $r.Json.aviso } else { $null }
    if ($warn) { Write-Host "WARNING from the device: $warn" -ForegroundColor Yellow }
    if ($NoWait) { exit 0 }

    # Wait for a NEW boot: the session token changes on every boot. 3 minutes is generous.
    'waiting for the device to come back...'
    for ($i = 0; $i -lt 90; $i++) {
        Start-Sleep -Seconds 2
        $q = Invoke-SmallTV -Path '/api/status' -TimeoutSec 3
        if ($q.Code -eq 200 -and $q.Json -and $q.Json.token -and $q.Json.token -ne $oldToken) {
            "back: firmware $($q.Json.version), $($q.Json.mode) mode"
            exit 0
        }
    }
    Write-Host 'The device has not answered after 3 minutes. If it changed network address, find it again;' -ForegroundColor Yellow
    Write-Host 'if it does not come back at all, see the recovery guide (rescue mode).'
    exit 4
} catch { Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
