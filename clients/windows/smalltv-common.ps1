# Shared helpers for the SmallTV PowerShell clients. Dot-sourced by the other scripts.
#
# Works on Windows PowerShell 5.1 and PowerShell 7+. No modules, no downloads: only Invoke-WebRequest.
#
# Configuration:
#   -Address HOST        device address, e.g. 10.0.0.42 or smalltv.local (a ":port" suffix is allowed)
#   $env:SMALLTV_HOST    same, from the environment (-Address wins)
#                        With neither, the scripts find the device on the network (UDP discovery, below).
#   $env:SMALLTV_USER    web user     (default: admin)
#   $env:SMALLTV_PASSWORD web password (default: 12345678, the same on every unit)
#
# Discovery overrides (optional; the defaults are what the device uses):
#   $env:SMALLTV_DISCOVERY_WAIT        seconds to listen for answers (default 2)
#   $env:SMALLTV_DISCOVERY_ADDR        comma-separated addresses to ask (default: every broadcast address)
#   $env:SMALLTV_DISCOVERY_PORT        where the device listens (default 7778)
#   $env:SMALLTV_DISCOVERY_REPLY_PORT  where it answers (default 7779)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 sends "Expect: 100-continue" on POST by default; the device's small web
# server does not need it, so switch it off.
[System.Net.ServicePointManager]::Expect100Continue = $false

# Upload time budget, same rule as the device web page: 60 s plus 1 s per KiB (a phone far from the
# access point can be as slow as ~1 KiB/s), capped at 20 minutes. Never a fixed number.
$script:UploadBaseSeconds = 60
$script:UploadMinBytesPerSecond = 1024
$script:UploadMaxSeconds = 1200
$script:RequestMaxSeconds = 15

function Get-UploadBudget([long]$Bytes) {
    $s = $script:UploadBaseSeconds + [math]::Floor($Bytes / $script:UploadMinBytesPerSecond)
    return [int][math]::Min($s, $script:UploadMaxSeconds)
}

# Find-SmallTV: asks the network which devices are there. Returns objects with IP, Name, MAC, Version, Mode
# ("app" or "rescue"); an empty list if nobody answered. The device answers any UDP datagram on port 7778 with one
# broadcast line on 7779:  "M 21:43:07 [HERE] smalltv-a1b2c3 mac=aa:bb:... ip=10.0.0.42 v=0.6.4 mode=app"
# (mode "app" or "rescue"). Firmware 0.6.3 and older answer "[AQUI] ... modo=app|rescate"; both forms are accepted.
function Get-DiscoverySetting([string]$Name, [double]$Default) {
    $v = [Environment]::GetEnvironmentVariable($Name)
    if (-not $v) { return $Default }
    $n = 0.0
    if (-not [double]::TryParse($v, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n) -or $n -le 0) {
        throw "$Name must be a positive number"
    }
    return $n
}

function Get-BroadcastAddresses {
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add('255.255.255.255')
    foreach ($nic in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($nic.OperationalStatus -ne 'Up') { continue }
        foreach ($u in $nic.GetIPProperties().UnicastAddresses) {
            if ($u.Address.AddressFamily -ne 'InterNetwork' -or [System.Net.IPAddress]::IsLoopback($u.Address)) { continue }
            if ($null -eq $u.IPv4Mask) { continue }
            $ip = $u.Address.GetAddressBytes(); $mask = $u.IPv4Mask.GetAddressBytes()
            $b = New-Object 'int[]' 4
            for ($i = 0; $i -lt 4; $i++) { $b[$i] = [int]$ip[$i] -bor ((-bnot [int]$mask[$i]) -band 255) }
            $txt = ($b -join '.')
            if (-not $out.Contains($txt)) { $out.Add($txt) }
        }
    }
    return $out
}

function Find-SmallTV([double]$WaitSeconds = 0) {
    $ask = [int](Get-DiscoverySetting 'SMALLTV_DISCOVERY_PORT' 7778)
    $reply = [int](Get-DiscoverySetting 'SMALLTV_DISCOVERY_REPLY_PORT' 7779)
    if ($WaitSeconds -le 0) { $WaitSeconds = Get-DiscoverySetting 'SMALLTV_DISCOVERY_WAIT' 2 }
    $targets = if ($env:SMALLTV_DISCOVERY_ADDR) { $env:SMALLTV_DISCOVERY_ADDR -split '\s*,\s*' | Where-Object { $_ } } else { Get-BroadcastAddresses }
    $pattern = '\[(?:HERE|AQUI)\]\s+(\S+)\s+mac=(\S+)\s+ip=([0-9.]+)\s+v=(\S+)\s+(?:mode|modo)=(\S+)'
    $udp = New-Object System.Net.Sockets.UdpClient
    try {
        # Shared port: other tools may be listening for the same answers.
        $udp.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
        $udp.Client.Bind((New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, $reply)))
        $udp.EnableBroadcast = $true
        $question = [Text.Encoding]::ASCII.GetBytes("SMALLTV?`n")
        foreach ($t in $targets) {
            try { [void]$udp.Send($question, $question.Length, $t, $ask) } catch { }   # one bad address must not stop the rest
        }
        $seen = @{}
        $deadline = [DateTime]::UtcNow.AddSeconds($WaitSeconds)
        while ($true) {
            $left = ($deadline - [DateTime]::UtcNow).TotalMilliseconds
            if ($left -le 0) { break }
            $udp.Client.ReceiveTimeout = [int][math]::Max(1, $left)
            $from = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
            try { $data = $udp.Receive([ref]$from) } catch { break }   # timeout: nobody else answered
            $text = [Text.Encoding]::UTF8.GetString($data)
            if ($text -match $pattern) {
                $mode = if ($Matches[5] -eq 'rescate') { 'rescue' } else { $Matches[5] }
                $mac = $Matches[2].ToLowerInvariant()
                $seen[$mac] = [pscustomobject]@{ IP = $Matches[3]; Name = $Matches[1]; MAC = $mac; Version = $Matches[4]; Mode = $mode }
            }
        }
        return @($seen.Values)
    } catch {
        # Method calls wrap the SocketException, so the type is not matched here: the message says enough.
        throw "cannot listen on UDP port $reply for discovery: $($_.Exception.Message)"
    } finally { $udp.Close() }
}

function Format-SmallTVDevice($d) {
    return ('{0,-16} {1,-16} {2,-18} v{3,-8} {4}' -f $d.IP, $d.Name, $d.MAC, $d.Version, $d.Mode)
}

function Initialize-SmallTV([string]$Address) {
    if (-not $Address) { $Address = $env:SMALLTV_HOST }
    if (-not $Address) {
        $found = @(Find-SmallTV)
        if ($found.Count -eq 1) {
            $d = $found[0]
            [Console]::Error.WriteLine("found $($d.Name) at $($d.IP) (firmware $($d.Version), $($d.Mode) mode)")
            $Address = $d.IP
        } elseif ($found.Count -eq 0) {
            throw ('no device answered the discovery. It may be off, on another network, or running firmware without ' +
                'discovery (older than 0.5.23); guest networks often block broadcasts. Pass the address with ' +
                '-Address HOST or $env:SMALLTV_HOST (the Status screen of the device shows it).')
        } else {
            $list = ($found | ForEach-Object { Format-SmallTVDevice $_ }) -join "`n"
            throw "several devices answered; choose one with -Address HOST (or `$env:SMALLTV_HOST):`n$list"
        }
    }
    $Address = $Address -replace '^http://', '' -replace '/$', ''
    $user = if ($env:SMALLTV_USER) { $env:SMALLTV_USER } else { 'admin' }
    $pass = if ($env:SMALLTV_PASSWORD) { $env:SMALLTV_PASSWORD } else { '12345678' }
    $script:SmallTV = @{
        Address = $Address
        Base    = "http://$Address"
        Auth    = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${pass}"))
        Token   = ''
        Status  = $null
    }
}

# Invoke-SmallTV: one HTTP request. Never throws on HTTP errors: returns @{ Code; Body; Json }.
# Code 0 means no answer at all. Never prints the password or the token.
function Invoke-SmallTV {
    param(
        [string]$Method = 'GET',
        [string]$Path,
        [switch]$WithToken,
        [hashtable]$Headers = @{},
        [object]$Body = $null,
        [string]$ContentType = $null,
        [int]$TimeoutSec = $script:RequestMaxSeconds,
        [string]$OutFile = $null
    )
    $h = @{ Authorization = $script:SmallTV.Auth }
    if ($WithToken) { $h['X-Rescue-Token'] = $script:SmallTV.Token }
    foreach ($k in $Headers.Keys) { $h[$k] = $Headers[$k] }
    $params = @{
        Uri = $script:SmallTV.Base + $Path; Method = $Method; Headers = $h
        TimeoutSec = $TimeoutSec; UseBasicParsing = $true
    }
    if ($null -ne $Body) { $params['Body'] = $Body }
    if ($ContentType) { $params['ContentType'] = $ContentType }
    if ($OutFile) { $params['OutFile'] = $OutFile; $params['PassThru'] = $true }
    $code = 0; $text = ''
    try {
        $r = Invoke-WebRequest @params
        $code = [int]$r.StatusCode
        if (-not $OutFile) {
            $text = if ($r.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
        }
    } catch {
        $resp = $null
        if ($_.Exception.PSObject.Properties['Response']) { $resp = $_.Exception.Response }
        if ($null -ne $resp) {
            $code = [int]$resp.StatusCode
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $text = $_.ErrorDetails.Message }
        }
    }
    $json = $null
    if ($text) { try { $json = $text | ConvertFrom-Json } catch { $json = $null } }
    return @{ Code = $code; Body = $text; Json = $json }
}

function Get-SmallTVHint($r) {
    switch ($r.Code) {
        0   { return "no answer from $($script:SmallTV.Address) (wrong address, device off, or not on this network)" }
        401 { return 'wrong user or password (401)' }
        403 { return 'missing or expired token (403): the device probably restarted; run the command again' }
        404 { return 'not available (404): the device is in rescue mode, or its firmware is older than this feature' }
        409 { return 'a firmware update is in progress (409): try again when it finishes' }
        507 { return 'not enough space in the device storage (507): delete something first' }
    }
    $e = ''
    if ($r.Json -and $r.Json.PSObject.Properties['error']) { $e = ': ' + $r.Json.error }
    return "device answered HTTP $($r.Code)$e"
}

# Read-SmallTVStatus: GET /api/status, keeps the session token. Throws on failure.
function Read-SmallTVStatus {
    $r = Invoke-SmallTV -Path '/api/status'
    if ($r.Code -ne 200 -or -not $r.Json) { throw (Get-SmallTVHint $r) }
    if (-not $r.Json.token) { throw 'the device did not return a session token' }
    $script:SmallTV.Token = $r.Json.token
    $script:SmallTV.Status = $r.Json
    return $r.Json
}

function Assert-AppMode {
    $m = $script:SmallTV.Status.mode
    if ($m -ne 'app') { throw "the device is in '$m' mode: this only works in normal (app) mode" }
}

# New-MultipartBody: multipart/form-data with ONE file part. Built by hand because the -Form
# parameter does not exist in Windows PowerShell 5.1. Returns @{ Body = byte[]; ContentType }.
function New-MultipartBody([string]$FieldName, [string]$FileName, [byte[]]$Data, [string]$PartType = 'application/octet-stream') {
    $boundary = '----smalltv' + [Guid]::NewGuid().ToString('N')
    $enc = [Text.Encoding]::UTF8
    $head = $enc.GetBytes("--$boundary`r`nContent-Disposition: form-data; name=`"$FieldName`"; filename=`"$FileName`"`r`nContent-Type: $PartType`r`n`r`n")
    $tail = $enc.GetBytes("`r`n--$boundary--`r`n")
    $ms = New-Object System.IO.MemoryStream
    $ms.Write($head, 0, $head.Length); $ms.Write($Data, 0, $Data.Length); $ms.Write($tail, 0, $tail.Length)
    return @{ Body = $ms.ToArray(); ContentType = "multipart/form-data; boundary=$boundary" }
}

function Test-ResourceName([string]$Name) { return $Name -cmatch '^[A-Za-z0-9_-][A-Za-z0-9._-]{0,29}$' }

function Get-FileMD5([byte[]]$Data) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try { return (($md5.ComputeHash($Data) | ForEach-Object { $_.ToString('x2') }) -join '') } finally { $md5.Dispose() }
}

# Upload one resource to /api/app/files. Returns the response hashtable.
function Send-SmallTVResource([string]$Name, [byte[]]$Data, [string]$PartType = 'application/octet-stream') {
    $mp = New-MultipartBody -FieldName 'file' -FileName $Name -Data $Data -PartType $PartType
    return Invoke-SmallTV -Method POST -Path '/api/app/files' -WithToken -Body $mp.Body -ContentType $mp.ContentType `
        -TimeoutSec (Get-UploadBudget $Data.Length)
}
