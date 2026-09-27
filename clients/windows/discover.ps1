<#
.SYNOPSIS
  Find the SmallTV devices on this network: one line per device (address, name, MAC, firmware, mode).
.DESCRIPTION
  Sends one UDP datagram to port 7778 and listens for the answers on port 7779. The device answers in rescue
  mode too (without its name). Exit code 0 if at least one device answered, 1 if none.
  -Name keeps only the device(s) called that way: the name set in the device web page (firmware 0.6.8+) or its
  host name smalltv-xxxxxx; case does not matter. With -IpOnly, two devices with that name are an error (exit 1).
  Windows may ask once whether PowerShell can use the network: allow it for private networks.
.EXAMPLE
  .\discover.ps1
.EXAMPLE
  $env:SMALLTV_HOST = .\discover.ps1 -IpOnly
.EXAMPLE
  $env:SMALLTV_HOST = .\discover.ps1 -Name Kitchen -IpOnly
#>
param(
    [double]$Wait = 0,     # seconds to listen (default 2, or $env:SMALLTV_DISCOVERY_WAIT)
    [string]$Name = '',    # only the device(s) called this way (label or host name)
    [switch]$IpOnly,       # print only the address of the first device
    [switch]$Json          # print the list as JSON
)
. (Join-Path $PSScriptRoot 'smalltv-common.ps1')
try {
    if ($Wait -lt 0 -or $Wait -gt 30) { throw '-Wait must be between 0 and 30 seconds' }
    $all = @(Find-SmallTV $Wait)
    $found = if ($Name) { @(Select-SmallTVByName $all $Name) } else { $all }
    if ($Name -and $found.Count -eq 0 -and $all.Count -gt 0) {
        [Console]::Error.WriteLine("no device is called `"$Name`".")
        exit 1
    }
    if ($Name -and $IpOnly -and $found.Count -gt 1) {
        [Console]::Error.WriteLine("several devices are called `"$Name`"; choose one by its address:")
        $found | ForEach-Object { [Console]::Error.WriteLine((Format-SmallTVDevice $_)) }
        exit 1
    }
    if ($found.Count -eq 0) {
        if (-not $IpOnly) { [Console]::Error.WriteLine('no device answered. It may be off, on another network, or running firmware without discovery; guest networks often block broadcasts.') }
        exit 1
    }
    if ($IpOnly) { $found[0].IP }
    elseif ($Json) { ConvertTo-Json -InputObject $found -Depth 3 }
    else { $found | ForEach-Object { Format-SmallTVDevice $_ } }
    exit 0
} catch { Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red; exit 2 }
