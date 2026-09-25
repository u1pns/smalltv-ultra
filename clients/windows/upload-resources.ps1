<#
.SYNOPSIS
  Upload resources to the device storage: a resource pack (.res) or single files.
.DESCRIPTION
  A pack ADDS and REPLACES files by name: your photos and panels stay where they are. Files already
  present with the same size are skipped, so an interrupted run can simply be started again.
  Only works in normal (app) mode. The device never decodes JPG/PNG/GIF: convert photos first with
  the album page of the device web (/api/app/album).
.EXAMPLE
  .\upload-resources.ps1 -Address 10.0.0.42 -Path .\smalltv-resources.res
.EXAMPLE
  .\upload-resources.ps1 -Path .\p-note.jpp, .\i-sun.jpi -Force
#>
param(
    [string]$Address,
    [Parameter(Mandatory = $true)][string[]]$Path,
    [switch]$Force    # upload even the files already on the device with the same size
)
. (Join-Path $PSScriptRoot 'smalltv-common.ps1')

# Read-ResourcePack: "JPR1\n" + one line of JSON manifest + "\n\n" + the files, raw, in manifest order.
function Read-ResourcePack([byte[]]$bytes, [string]$label) {
    $latin = [Text.Encoding]::GetEncoding(28591)
    $head = $latin.GetString($bytes, 0, [math]::Min($bytes.Length, 65536))
    $cut = $head.IndexOf("`n`n")
    if ($cut -lt 0) { throw "${label}: not a valid resource pack (header not found)" }
    try { $m = $head.Substring(5, $cut - 5) | ConvertFrom-Json } catch { throw "${label}: broken pack manifest" }
    if (-not $m.archivos) { throw "${label}: the pack lists no files" }
    $offset = $cut + 2; $list = @()
    foreach ($a in $m.archivos) {
        if (-not (Test-ResourceName $a.nombre)) { throw "${label}: invalid file name in the pack: $($a.nombre)" }
        $n = [int]$a.bytes
        if ($offset + $n -gt $bytes.Length) { throw "${label}: the pack is cut short (at $($a.nombre))" }
        $chunk = New-Object byte[] $n
        [Array]::Copy($bytes, $offset, $chunk, 0, $n)
        if ($a.md5 -and (Get-FileMD5 $chunk) -ne $a.md5) { throw "${label}: $($a.nombre) is corrupted (MD5 mismatch)" }
        $list += , @{ Name = $a.nombre; Data = $chunk }
        $offset += $n
    }
    if ($offset -ne $bytes.Length) { throw "${label}: size mismatch (pack is cut or has extra data)" }
    return @{ Minimum = $m.minimo; Files = $list }
}

function Compare-Version([string]$a, [string]$b) {
    $pa = ($a -replace '^(\d+\.\d+\.\d+).*$', '$1').Split('.'); $pb = $b.Split('.')
    for ($i = 0; $i -lt 3; $i++) {
        $x = [int]$pa[$i]; $y = [int]$pb[$i]
        if ($x -ne $y) { if ($x -lt $y) { return -1 } else { return 1 } }
    }
    return 0
}

try {
    Initialize-SmallTV $Address
    $queue = @(); $minimum = $null
    foreach ($p in $Path) {
        $full = (Resolve-Path -LiteralPath $p).Path
        $bytes = [IO.File]::ReadAllBytes($full)
        if ($bytes.Length -ge 5 -and [Text.Encoding]::ASCII.GetString($bytes, 0, 5) -eq "JPR1`n") {
            $pack = Read-ResourcePack $bytes (Split-Path -Leaf $full)
            $minimum = $pack.Minimum
            $total = 0; foreach ($f in $pack.Files) { $total += $f.Data.Length }
            "pack $(Split-Path -Leaf $full): $($pack.Files.Count) files, $total bytes, for firmware $minimum or later"
            $queue += $pack.Files
        } else {
            $name = Split-Path -Leaf $full
            if (-not (Test-ResourceName $name)) { throw "invalid resource name '$name': letters, digits, dot, dash, underscore; max 30" }
            if ($name -match '\.(jpe?g|png|gif|webp|heic|bmp)$') { throw "$name is a normal image: the device cannot show it. Convert it with the album page first" }
            $queue += , @{ Name = $name; Data = $bytes }
        }
    }

    $s = Read-SmallTVStatus
    Assert-AppMode
    if ($minimum -and (Compare-Version $s.version $minimum) -lt 0) {
        Write-Host "WARNING: this pack needs firmware $minimum or later; the device runs $($s.version)." -ForegroundColor Yellow
    }

    $r = Invoke-SmallTV -Path '/api/app/files'
    if ($r.Code -ne 200 -or -not $r.Json) { throw "cannot list the storage: $(Get-SmallTVHint $r)" }
    if (-not $r.Json.PSObject.Properties['mounted']) { throw "unexpected answer from the device: no 'mounted' field (firmware older than 0.6.0?)" }
    if ($r.Json.mounted -eq $false) { throw 'the device storage is not formatted: format it once from the device web page' }
    if (-not $r.Json.PSObject.Properties['files']) { throw "unexpected answer from the device: no 'files' list" }
    $present = @{}
    if ($r.Json.truncated) { 'storage list truncated: uploading everything' }
    else { foreach ($a in $r.Json.files) { $present[$a.name] = [long]$a.bytes } }

    $done = 0; $skipped = 0; $i = 0
    foreach ($f in $queue) {
        $i++
        if (-not $Force -and $present.ContainsKey($f.Name) -and $present[$f.Name] -eq $f.Data.Length) { $skipped++; continue }
        $u = Send-SmallTVResource -Name $f.Name -Data $f.Data
        if ($u.Code -ne 200) {
            Write-Host "stopped at $i of $($queue.Count) ($($f.Name)): $(Get-SmallTVHint $u)" -ForegroundColor Red
            Write-Host "The $done files before it ARE installed; run the same command again to continue."
            exit 3
        }
        $done++
        "[$i/$($queue.Count)] $($f.Name)  $($f.Data.Length) bytes"
    }
    "done: $done uploaded, $skipped already there with the same size"
} catch { Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
