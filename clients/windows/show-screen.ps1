<#
.SYNOPSIS
  Jump to a screen right now.
.DESCRIPTION
  Screen names: clock, weather, forecast, status, album, panels.
.EXAMPLE
  .\show-screen.ps1 -Address 10.0.0.42 -Screen weather
#>
param(
    [string]$Address,
    [Parameter(Mandatory = $true)][ValidateSet('clock', 'weather', 'forecast', 'status', 'album', 'panels')][string]$Screen
)
. (Join-Path $PSScriptRoot 'smalltv-common.ps1')
try {
    Initialize-SmallTV $Address
    $null = Read-SmallTVStatus
    Assert-AppMode
    $r = Invoke-SmallTV -Method POST -Path "/api/app/show?screen=$Screen" -WithToken
    if ($r.Code -ne 200) { throw (Get-SmallTVHint $r) }
    "showing: $Screen"
} catch { Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
