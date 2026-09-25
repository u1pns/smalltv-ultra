<#
.SYNOPSIS
  List, download or delete files in the device storage.
.DESCRIPTION
  To upload, use upload-resources.ps1. Formatting the storage is only offered in the device web
  page, on purpose: it deletes fonts, icons and photos at once.
.EXAMPLE
  .\files.ps1 -Action list
.EXAMPLE
  .\files.ps1 -Action get -Name p-stocks.jpp -OutFile .\p-stocks.jpp
.EXAMPLE
  .\files.ps1 -Action delete -Name p-stocks.jpp
#>
param(
    [string]$Address,
    [Parameter(Mandatory = $true)][ValidateSet('list', 'get', 'delete')][string]$Action,
    [string]$Name,
    [string]$OutFile
)
. (Join-Path $PSScriptRoot 'smalltv-common.ps1')
try {
    if ($Action -ne 'list') {
        if (-not $Name) { throw "-Name is required for $Action" }
        if (-not (Test-ResourceName $Name)) { throw "invalid name: $Name" }
    }
    Initialize-SmallTV $Address
    $null = Read-SmallTVStatus
    Assert-AppMode
    switch ($Action) {
        'list' {
            $r = Invoke-SmallTV -Path '/api/app/files'
            if ($r.Code -ne 200 -or -not $r.Json) { throw (Get-SmallTVHint $r) }
            if (-not $r.Json.PSObject.Properties['mounted']) { throw "unexpected answer from the device: no 'mounted' field (firmware older than 0.6.0?)" }
            if ($r.Json.mounted -eq $false) { 'storage not formatted'; exit 0 }
            if (-not $r.Json.PSObject.Properties['files']) { throw "unexpected answer from the device: no 'files' list" }
            $r.Json.files | ForEach-Object { '{0,10}  {1}' -f $_.bytes, $_.name }
            "used $($r.Json.used) of $($r.Json.total) bytes"
            if ($r.Json.truncated) { '(list truncated by the device: more files exist)' }
        }
        'get' {
            if (-not $OutFile) { $OutFile = $Name }
            if (Test-Path -LiteralPath $OutFile) { throw "$OutFile already exists" }
            $r = Invoke-SmallTV -Path "/api/app/files/get?name=$Name" -OutFile $OutFile -TimeoutSec (Get-UploadBudget 2097152)
            if ($r.Code -ne 200) { Remove-Item -LiteralPath $OutFile -ErrorAction SilentlyContinue; throw (Get-SmallTVHint $r) }
            "saved $OutFile ($((Get-Item -LiteralPath $OutFile).Length) bytes)"
        }
        'delete' {
            $r = Invoke-SmallTV -Method POST -Path "/api/app/files/delete?name=$Name" -WithToken
            if ($r.Code -ne 200) { throw (Get-SmallTVHint $r) }
            "deleted $Name"
        }
    }
} catch { Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
