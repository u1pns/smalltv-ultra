<#
.SYNOPSIS
  Find the SmallTV devices on this network: one line per device (address, name, MAC, firmware, mode).
.DESCRIPTION
  Sends one UDP datagram to port 7778 and listens for the answers on port 7779. The device answers in rescue
  mode too. Exit code 0 if at least one device answered, 1 if none.
  Windows may ask once whether PowerShell can use the network: allow it for private networks.
.EXAMPLE
  .\discover.ps1
.EXAMPLE
  $env:SMALLTV_HOST = .\discover.ps1 -IpOnly
#>
param(
    [double]$Wait = 0,     # seconds to listen (default 2, or $env:SMALLTV_DISCOVERY_WAIT)
    [switch]$IpOnly,       # print only the address of the first device
    [switch]$Json          # print the list as JSON
)
. (Join-Path $PSScriptRoot 'smalltv-common.ps1')
try {
    if ($Wait -lt 0 -or $Wait -gt 30) { throw '-Wait must be between 0 and 30 seconds' }
    $found = @(Find-SmallTV $Wait)
    if ($found.Count -eq 0) {
        if (-not $IpOnly) { [Console]::Error.WriteLine('no device answered. It may be off, on another network, or running firmware without discovery; guest networks often block broadcasts.') }
        exit 1
    }
    if ($IpOnly) { $found[0].IP }
    elseif ($Json) { ConvertTo-Json -InputObject $found -Depth 3 }
    else { $found | ForEach-Object { Format-SmallTVDevice $_ } }
    exit 0
} catch { Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red; exit 2 }
