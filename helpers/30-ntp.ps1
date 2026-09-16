<#
.SYNOPSIS
    Windows NTP Server management functions.
.DESCRIPTION
    This script contains a collection of functions to configure and manage
    the Windows built-in W32Time service as an NTP server.
    To use, dot-source this file in PowerShell:
    . .\30-ntp.ps1
#>

# Registry paths
$W32TimeBase = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time"
$NtpServerPath = "$W32TimeBase\TimeProviders\NtpServer"
$ConfigPath = "$W32TimeBase\Config"

function Test-Administrator
{
  <#
    .SYNOPSIS
        Checks if the current PowerShell session is running as Administrator.
    #>
  $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-W32TimeService
{
  <#
    .SYNOPSIS
        Restarts the Windows Time service.
    #>
  if (-not (Test-Administrator))
  {
    Write-Warning "Administrator privileges required."
    return
  }
  Write-Host "Restarting Windows Time service..." -ForegroundColor Cyan
  Stop-Service w32time -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 1
  Start-Service w32time
  Write-Host "Windows Time service restarted." -ForegroundColor Green
}

function Enable-NtpServerFeature
{
  <#
    .SYNOPSIS
        Enables the NTP Server feature in the registry.
    #>
  if (-not (Test-Administrator))
  {
    Write-Warning "Administrator privileges required."
    return
  }
  Write-Host "Enabling NTP Server feature..." -ForegroundColor Cyan
  Set-ItemProperty -Path $NtpServerPath -Name "Enabled" -Value 1 -Type DWord
  Write-Host "NTP Server feature enabled." -ForegroundColor Green
}

function Disable-NtpServerFeature
{
  <#
    .SYNOPSIS
        Disables the NTP Server feature in the registry.
    #>
  if (-not (Test-Administrator))
  {
    Write-Warning "Administrator privileges required."
    return
  }
  Write-Host "Disabling NTP Server feature..." -ForegroundColor Cyan
  Set-ItemProperty -Path $NtpServerPath -Name "Enabled" -Value 0 -Type DWord
  Write-Host "NTP Server feature disabled." -ForegroundColor Yellow
}

function Set-NtpAnnounceFlags
{
  <#
    .SYNOPSIS
        Sets the AnnounceFlags registry value.
    .PARAMETER Flags
        Integer value (typically 5 for standalone server, 10 for domain member).
    #>
  param (
    [Parameter(Mandatory=$true)]
    [ValidateSet(5, 10)]
    [int]$Flags
  )
  if (-not (Test-Administrator))
  {
    Write-Warning "Administrator privileges required."
    return
  }
  Write-Host "Setting AnnounceFlags to $Flags..." -ForegroundColor Cyan
  Set-ItemProperty -Path $ConfigPath -Name "AnnounceFlags" -Value $Flags -Type DWord
  Write-Host "AnnounceFlags set to $Flags." -ForegroundColor Green
}

function Set-NtpFirewallRule
{
  <#
    .SYNOPSIS
        Configures Windows Firewall to allow or block UDP port 123.
    .PARAMETER FirewallAction
        "Allow" to open port, "Block" to close it.
    #>
  param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("Allow", "Block")]
    [string]$FirewallAction
  )
  if (-not (Test-Administrator))
  {
    Write-Warning "Administrator privileges required."
    return
  }
  $ruleName = "NTP Server (UDP 123)"
  if ($FirewallAction -eq "Allow")
  {
    Write-Host "Configuring firewall to allow UDP 123 inbound..." -ForegroundColor Cyan
    if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue))
    {
      New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol UDP -LocalPort 123 -Action Allow -Profile Any | Out-Null
    } else
    {
      Enable-NetFirewallRule -DisplayName $ruleName
    }
    Write-Host "Firewall rule configured to allow." -ForegroundColor Green
  } else
  {
    Write-Host "Disabling firewall rule..." -ForegroundColor Cyan
    if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)
    {
      Disable-NetFirewallRule -DisplayName $ruleName
    }
    Write-Host "Firewall rule disabled." -ForegroundColor Yellow
  }
}

function Set-ExternalNtpSource
{
  <#
    .SYNOPSIS
        Configures the external NTP time sources for this machine.
    .PARAMETER PeerList
        Comma-separated list of NTP servers (e.g., "ntp.aliyun.com,0x8 pool.ntp.org,0x8").
    #>
  param (
    [string]$PeerList = "ntp.aliyun.com,0x8 pool.ntp.org,0x8"
  )
  if (-not (Test-Administrator))
  {
    Write-Warning "Administrator privileges required."
    return
  }
  Write-Host "Configuring external NTP sources: $PeerList" -ForegroundColor Cyan
  w32tm /config /manualpeerlist:"$PeerList" /syncfromflags:manual /reliable:yes /update | Out-Null
  Write-Host "External NTP sources configured." -ForegroundColor Green
}

function Get-NtpServerStatus
{
  <#
    .SYNOPSIS
        Displays the current status of the NTP server configuration.
    #>
  Write-Host "========== NTP Server Status ==========" -ForegroundColor Yellow

  $service = Get-Service w32time -ErrorAction SilentlyContinue
  if ($service)
  {
    Write-Host "Windows Time Service: " -NoNewline
    Write-Host $service.Status -ForegroundColor $(if($service.Status -eq 'Running')
      {'Green'
      } else
      {'Red'
      })
  } else
  {
    Write-Host "Windows Time Service: Not found" -ForegroundColor Red
  }

  $enabled = (Get-ItemProperty -Path $NtpServerPath -ErrorAction SilentlyContinue).Enabled
  Write-Host "NTP Server Feature (Enabled): $enabled" -ForegroundColor $(if($enabled -eq 1)
    {'Green'
    } else
    {'Red'
    })

  $announce = (Get-ItemProperty -Path $ConfigPath -ErrorAction SilentlyContinue).AnnounceFlags
  Write-Host "AnnounceFlags: $announce"

  $listener = netstat -ano | findstr ":123"
  if ($listener)
  {
    Write-Host "UDP Port 123 Listening: Yes" -ForegroundColor Green
  } else
  {
    Write-Host "UDP Port 123 Listening: No" -ForegroundColor Red
  }

  $fwRule = Get-NetFirewallRule -DisplayName "NTP Server (UDP 123)" -ErrorAction SilentlyContinue
  if ($fwRule -and $fwRule.Enabled -eq 'True')
  {
    Write-Host "Firewall Rule: Enabled" -ForegroundColor Green
  } else
  {
    Write-Host "Firewall Rule: Disabled or Not Exist" -ForegroundColor Yellow
  }
  Write-Host "======================================" -ForegroundColor Yellow
}

function Start-NtpServer
{
  <#
    .SYNOPSIS
        One-click deployment of NTP server.
    .PARAMETER UpstreamNtp
        External NTP servers to sync from. Default is "ntp.aliyun.com,0x8 pool.ntp.org,0x8".
    #>
  param (
    [string]$UpstreamNtp = "ntp.aliyun.com,0x8 pool.ntp.org,0x8"
  )
  if (-not (Test-Administrator))
  {
    Write-Warning "Administrator privileges required."
    return
  }
  Write-Host "========== Starting NTP Server Deployment ==========" -ForegroundColor Green

  Set-ExternalNtpSource -PeerList $UpstreamNtp
  Enable-NtpServerFeature
  Set-NtpAnnounceFlags -Flags 5
  Set-NtpFirewallRule -FirewallAction Allow
  Restart-W32TimeService

  Write-Host "Forcing local time synchronization..." -ForegroundColor Cyan
  w32tm /resync | Out-Null
  Start-Sleep -Seconds 2

  Write-Host "========== NTP Server Deployment Complete ==========" -ForegroundColor Green
  Get-NtpServerStatus
}

function Stop-NtpServer
{
  <#
    .SYNOPSIS
        Stops the NTP server and reverts settings.
    #>
  if (-not (Test-Administrator))
  {
    Write-Warning "Administrator privileges required."
    return
  }
  Write-Host "========== Stopping NTP Server ==========" -ForegroundColor Yellow
  Disable-NtpServerFeature
  Set-NtpAnnounceFlags -Flags 10
  Set-NtpFirewallRule -FirewallAction Block
  Restart-W32TimeService
  Write-Host "========== NTP Server Stopped ==========" -ForegroundColor Yellow
}

function Test-NtpServer
{
  <#
    .SYNOPSIS
        Tests NTP server response and latency.
    .PARAMETER ComputerName
        Target computer to test. Default is 127.0.0.1.
    #>
  param (
    [string]$ComputerName = "127.0.0.1"
  )
  Write-Host "Testing NTP latency with $ComputerName..." -ForegroundColor Cyan
  w32tm /stripchart /computer:$ComputerName /samples:5
}
