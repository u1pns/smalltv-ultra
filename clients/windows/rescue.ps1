<#
.SYNOPSIS
  Enter or leave rescue mode without cutting the power.
.DESCRIPTION
  enter: restart into rescue mode (only the web page and firmware updates run).
  exit:  leave rescue mode and restart into the normal app.
  If the device does not answer at all, use the power-cut gesture instead (see the recovery guide).
.EXAMPLE
  .\rescue.ps1 -Address 10.0.0.42 -Action enter
#>
param(
    [string]$Address,
    [Parameter(Mandatory = $true)][ValidateSet('enter', 'exit')][string]$Action
)
. (Join-Path $PSScriptRoot 'smalltv-common.ps1')
try {
    Initialize-SmallTV $Address
    $s = Read-SmallTVStatus
    if ($Action -eq 'enter' -and $s.mode -eq 'rescue') { 'already in rescue mode'; exit 0 }
    if ($Action -eq 'exit' -and $s.mode -ne 'rescue') { "not in rescue mode (mode: $($s.mode))"; exit 0 }
    $r = Invoke-SmallTV -Method POST -Path "/api/rescue/$Action" -WithToken
    if ($r.Code -ne 200 -and $r.Code -ne 202) { throw (Get-SmallTVHint $r) }
    'accepted: the device is restarting. Give it about 30 seconds.'
    if ($Action -eq 'enter') { "If it cannot join your network in rescue mode, connect to its own Wi-Fi (SmallTV-Setup-...): see the recovery guide." }
} catch { Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
