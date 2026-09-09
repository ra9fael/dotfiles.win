<#
.SYNOPSIS
    smb.ps1 - dot-sourceable SMB / UNC helper functions

.DESCRIPTION
    Dot-source this file to load the functions into your session:

        . .\smb.ps1

    WHY UNC CAN BE SLOW WHILE THE MAPPED DRIVE IS INSTANT:
      - UNC paths go through MUP (Multiple UNC Provider). MUP asks every
        registered network provider one by one and waits synchronously.
        Extra providers (webclient, Nfsnp, P9NP) add seconds of timeout.
      - The DFS client lives inside MUP and is always asked FIRST,
        no matter the provider order. Disable it if you are not on a domain.
      - A mapped drive (Z:) and "net use" skip this path entirely.

.NOTES
    Registry changes need a REBOOT (mup.sys is a kernel driver).
    Write operations need an elevated shell.
#>

# ---------------------------------------------------------------- config ----
$SmbServer = '192.168.138.253'
$SmbShare  = 'rf'
$SmbDrive  = 'Z'

$RegOrder = 'HKLM:\SYSTEM\CurrentControlSet\Control\NetworkProvider\Order'
$RegMup   = 'HKLM:\System\CurrentControlSet\Services\Mup'

# --------------------------------------------------------------- helpers ----
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).
        IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Backup-SmbReg {
    $dir = Join-Path $env:TEMP 'smb_backup'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $file = Join-Path $dir ("regbak_{0}.reg" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    & reg export 'HKLM\System\CurrentControlSet\Services\Mup' $file /y 2>&1 | Out-Null
    & reg export 'HKLM\SYSTEM\CurrentControlSet\Control\NetworkProvider\Order' $file /y 2>&1 | Out-Null
    Write-Host "  Backed up to: $file" -ForegroundColor DarkGray
    $file
}

# --------------------------------------------------------------- measure ----
function Measure-PathLatency {
    <#
    .SYNOPSIS
        Measure Explorer (Shell layer) bind + enumerate time for a path.
    .DESCRIPTION
        Uses Shell.Application COM - the same code path as Explorer - and it is
        synchronous, so the number is real.
        Do NOT use Measure-Command { explorer ... }: explorer.exe returns
        immediately (async), you would only time the launcher.
    .EXAMPLE
        Measure-PathLatency '\\192.168.138.253\rf'
    .EXAMPLE
        Measure-PathLatency '\\host\a','\\host\b','Z:\' -Count 5
    .EXAMPLE
        '\\host\a','Z:\' | Measure-PathLatency
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string[]]$Path,
        [int]$Count = 3
    )
    process {
        foreach ($p in $Path) {
            $vals = @()
            $items = -1
            for ($i = 1; $i -le $Count; $i++) {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $shell = $null; $folder = $null
                try {
                    $shell  = New-Object -ComObject Shell.Application
                    $folder = $shell.NameSpace($p)
                    if ($folder) { $items = $folder.Items().Count }
                }
                catch { }
                finally {
                    $sw.Stop()
                    if ($folder) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($folder) }
                    if ($shell)  { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
                }
                $vals += $sw.Elapsed.TotalMilliseconds
            }
            $avg = [math]::Round(($vals | Measure-Object -Average).Average, 1)
            $min = [math]::Round(($vals | Measure-Object -Minimum).Minimum, 1)
            $tag = if ($avg -lt 300) { 'FAST' } elseif ($avg -lt 2000) { 'OK' } else { 'SLOW' }
            $col = if ($tag -eq 'SLOW') { 'Red' } elseif ($tag -eq 'OK') { 'Yellow' } else { 'Green' }
            Write-Host ("  {0,-40} avg {1,9} ms   min {2,8} ms   [{3}]" -f $p, $avg, $min, $tag) -ForegroundColor $col
            [PSCustomObject]@{ Path = $p; AvgMs = $avg; MinMs = $min; Items = $items }
        }
    }
}

function Compare-PathAccess {
    <#
    .SYNOPSIS
        UNC vs mapped drive vs bogus share. Tells you where the delay is.
    .EXAMPLE
        Compare-PathAccess
        Compare-PathAccess -Server 192.168.1.10 -Share data -Drive Y
    #>
    param(
        [string]$Server = $SmbServer,
        [string]$Share  = $SmbShare,
        [string]$Drive  = $SmbDrive
    )
    $root = "\\$Server"
    $unc  = "\\$Server\$Share"
    $fake = "$root\__nope__$([guid]::NewGuid().ToString('N').Substring(0,6))"

    Write-Host "`n=== UNC vs drive ($unc) ===" -ForegroundColor Cyan
    Measure-PathLatency $root -Count 2 | Out-Null
    $u = Measure-PathLatency $unc  -Count 2
    $f = Measure-PathLatency $fake -Count 1
    $d = if (Test-Path "$Drive`:\") { Measure-PathLatency "$Drive`:\" -Count 2 } else { $null }

    Write-Host "`n  Verdict:" -ForegroundColor Cyan
    if (-not $d) {
        Write-Host "    Drive $Drive not mapped. Run: Mount-SmbShare -DriveLetter $Drive" -ForegroundColor Yellow
    }
    elseif ($u.AvgMs -gt ($d.AvgMs * 5) -and $u.AvgMs -gt 500) {
        Write-Host "    UNC is 5x+ slower than the drive -> MUP / DFS resolution layer." -ForegroundColor Yellow
        Write-Host "    Fix: Set-SmbProviderOrder 'RDPNP,LanmanWorkstation' ; Disable-SmbDfs" -ForegroundColor Gray
    }
    elseif ($f.AvgMs -gt 3000) {
        Write-Host "    Even a bogus share takes $($f.AvgMs) ms -> pure path resolution." -ForegroundColor Yellow
    }
    elseif ($u.AvgMs -lt 500) {
        Write-Host "    Healthy. UNC avg $($u.AvgMs) ms." -ForegroundColor Green
    }
    else {
        Write-Host "    UNC avg $($u.AvgMs) ms. Remainder is likely a server-side RPC timeout." -ForegroundColor Yellow
    }
    Write-Host ""
}

# -------------------------------------------------------------- provider ----
function Get-SmbProviderOrder {
    <#
    .SYNOPSIS
        Show MUP network provider order.
    #>
    $o = (Get-ItemProperty $RegOrder -Name ProviderOrder).ProviderOrder
    Write-Host "  $o`n" -ForegroundColor White
    Write-Host "    RDPNP              Remote Desktop - keep"
    Write-Host "    LanmanWorkstation  SMB - must keep"
    Write-Host "    webclient          WebDAV - remove if unused (UNC delay)"
    Write-Host "    Nfsnp              NFS client - remove if unused (UNC delay)"
    Write-Host "    P9NP               WSL2 Plan9 - usually safe to remove`n"
    $o
}

function Set-SmbProviderOrder {
    <#
    .SYNOPSIS
        Set MUP provider order (backs up first, needs reboot).
    .EXAMPLE
        Set-SmbProviderOrder 'RDPNP,LanmanWorkstation'          # aggressive
        Set-SmbProviderOrder 'RDPNP,P9NP,LanmanWorkstation'     # keep WSL
        Set-SmbProviderOrder 'RDPNP,P9NP,LanmanWorkstation,webclient,Nfsnp'  # default
    #>
    param([Parameter(Mandatory)][string]$Order)
    if (-not (Test-IsAdmin)) { Write-Host "  Need Administrator." -ForegroundColor Red; return }
    $old = (Get-ItemProperty $RegOrder -Name ProviderOrder).ProviderOrder
    if ($old -eq $Order) { Write-Host "  Already set." -ForegroundColor DarkGray; return }
    Backup-SmbReg | Out-Null
    Set-ItemProperty $RegOrder -Name ProviderOrder -Value $Order -Force
    Write-Host "  $old -> $Order" -ForegroundColor Green
    Write-Host "  Reboot required." -ForegroundColor Yellow
}

function Get-SmbDfs {
    <#
    .SYNOPSIS
        Show DFS client status. 1 = disabled (good for workgroup).
    #>
    $v = (Get-ItemProperty $RegMup -Name DisableDfs -ErrorAction SilentlyContinue).DisableDfs
    if ($null -eq $v) { $v = 0 }
    $txt = if ($v -eq 1) { 'DISABLED (good for workgroup)' } else { 'ENABLED' }
    Write-Host "  DisableDfs = $v   $txt" -ForegroundColor $(if ($v -eq 1) { 'Green' } else { 'Yellow' })
    $v
}

function Disable-SmbDfs {
    <#
    .SYNOPSIS
        Disable the DFS client (backs up first, needs reboot).
    #>
    if (-not (Test-IsAdmin)) { Write-Host "  Need Administrator." -ForegroundColor Red; return }
    Backup-SmbReg | Out-Null
    Set-ItemProperty $RegMup -Name DisableDfs -Value 1 -Type DWORD -Force
    Write-Host "  DisableDfs = 1" -ForegroundColor Green
    Write-Host "  mup.sys is a kernel driver - REBOOT required." -ForegroundColor Yellow
}

function Enable-SmbDfs {
    <#
    .SYNOPSIS
        Restore the DFS client (default).
    #>
    if (-not (Test-IsAdmin)) { Write-Host "  Need Administrator." -ForegroundColor Red; return }
    Backup-SmbReg | Out-Null
    Set-ItemProperty $RegMup -Name DisableDfs -Value 0 -Type DWORD -Force
    Write-Host "  DisableDfs = 0" -ForegroundColor Green
    Write-Host "  REBOOT required." -ForegroundColor Yellow
}

# ----------------------------------------------------------------- mount ----
function Mount-SmbShare {
    <#
    .SYNOPSIS
        Map the share to a drive letter. Fastest way to use it day to day.
    .EXAMPLE
        Mount-SmbShare
        Mount-SmbShare -DriveLetter Y -Server 192.168.1.10 -Share data
    #>
    param(
        [string]$Server = $SmbServer,
        [string]$Share  = $SmbShare,
        [string]$DriveLetter = $SmbDrive
    )
    $l = $DriveLetter.TrimEnd(':')
    & net use "${l}:" /delete /y 2>&1 | Out-Null
    $out = & net use "${l}:" "\\$Server\$Share" /persistent:yes 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "  Mapped ${l}: -> \\$Server\$Share" -ForegroundColor Green }
    else { Write-Host "  Failed: $out" -ForegroundColor Red }
}

function Dismount-SmbShare {
    <#
    .SYNOPSIS
        Remove a drive mapping.
    #>
    param([string]$DriveLetter = $SmbDrive)
    $l = $DriveLetter.TrimEnd(':')
    & net use "${l}:" /delete /y 2>&1 | Out-Null
    Write-Host "  Removed ${l}:" -ForegroundColor Green
}

# ------------------------------------------------------------------ diag ----
function Test-SmbPort {
    <#
    .SYNOPSIS
        Check SMB ports (445 / 139).
    #>
    param([string]$Server = $SmbServer)
    foreach ($p in 445, 139) {
        $r = Test-NetConnection -ComputerName $Server -Port $p -WarningAction SilentlyContinue
        $ok = if ($r.TcpTestSucceeded) { 'OPEN' } else { 'CLOSED' }
        $col = if ($r.TcpTestSucceeded) { 'Green' } else { 'Red' }
        Write-Host "  TCP $p : $ok (resolved $($r.RemoteAddress))" -ForegroundColor $col
    }
}

function Test-DnsHijack {
    <#
    .SYNOPSIS
        Detect NXDOMAIN hijacking - a hidden amplifier of SMB delays.
    #>
    $name = "no-such-host-$([guid]::NewGuid().ToString('N').Substring(0,8)).invalid"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $r = Resolve-DnsName $name -ErrorAction SilentlyContinue
    $sw.Stop()
    if ($r) {
        Write-Host "  HIJACKED: bogus name resolved to $($r[0].IPAddress)" -ForegroundColor Red
        Write-Host "  Change DNS to 223.5.5.5 / 119.29.29.29" -ForegroundColor Yellow
    }
    else {
        Write-Host "  OK, clean NXDOMAIN in $([math]::Round($sw.Elapsed.TotalMilliseconds)) ms" -ForegroundColor Green
    }
    Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } |
        ForEach-Object { Write-Host "    $($_.InterfaceAlias): $($_.ServerAddresses -join ', ')" }
}

function Get-SmbConnectionInfo {
    <#
    .SYNOPSIS
        Show active SMB connections and client config.
    #>
    $c = Get-SmbConnection -ErrorAction SilentlyContinue
    if ($c) { $c | Format-Table ServerName, ShareName, Dialect, Signed, NumOpens -AutoSize }
    else    { Write-Host "  No active SMB connection." -ForegroundColor DarkGray }
    $cfg = Get-SmbClientConfiguration
    Write-Host "  RequireSecuritySignature: $($cfg.RequireSecuritySignature)"
    Write-Host "  EnableMultiChannel      : $($cfg.EnableMultiChannel)"
}

function Reset-SmbStack {
    <#
    .SYNOPSIS
        Drop all SMB sessions, clear DNS cache, restart the workstation service.
    #>
    net use * /delete /y 2>&1 | Out-Null
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Restart-Service LanmanWorkstation -Force -ErrorAction SilentlyContinue
    Write-Host "  Done." -ForegroundColor Green
}

function Invoke-SmbFix {
    <#
    .SYNOPSIS
        One-shot: trim provider order + disable DFS. Backs up first.
    .EXAMPLE
        Invoke-SmbFix                 # keep only RDPNP + SMB
        Invoke-SmbFix -KeepP9NP       # also keep WSL's P9NP
    #>
    param([switch]$KeepP9NP)
    $order = if ($KeepP9NP) { 'RDPNP,P9NP,LanmanWorkstation' } else { 'RDPNP,LanmanWorkstation' }
    Set-SmbProviderOrder $order
    Disable-SmbDfs
    Write-Host "`n  Reboot, then run: Compare-PathAccess`n" -ForegroundColor Yellow
}

function Show-SmbHelp {
    <#
    .SYNOPSIS
        List the functions provided by smb.ps1.
    .EXAMPLE
        Show-SmbHelp
    #>
    Write-Host @"

  smb.ps1 - Server=$SmbServer Share=$SmbShare Drive=${SmbDrive}:

    Show-SmbHelp                          this list

    Measure-PathLatency '\\host\share'    measure a path (pipeable, -Count n)
    Compare-PathAccess                    UNC vs drive, with verdict
    Test-SmbPort                          check 445 / 139
    Test-DnsHijack                        detect NXDOMAIN hijacking
    Get-SmbConnectionInfo                 active sessions + client config

    Get-SmbProviderOrder                  show MUP provider order
    Set-SmbProviderOrder 'RDPNP,LanmanWorkstation'
    Get-SmbDfs                            show DFS status
    Disable-SmbDfs / Enable-SmbDfs
    Invoke-SmbFix [-KeepP9NP]             one-shot: trim order + disable DFS

    Mount-SmbShare / Dismount-SmbShare
    Reset-SmbStack                        drop sessions + clear caches
    Backup-SmbReg                         back up the registry keys we touch

  Registry changes need a REBOOT (mup.sys is a kernel driver).

"@ -ForegroundColor DarkGray
}

# Loaded silently. Run Show-SmbHelp for the function list.
