# -----------------------------------------------------------------------------
# QUICK NETWORK INFORMATION
# -----------------------------------------------------------------------------
function netinfo
{
  param(
    [switch]$Help
  )

  if ($Help)
  {
    Write-Host "`nUsage: ni" -ForegroundColor Cyan
    Write-Host "Displays current network IP addresses and proxy status.`n" -ForegroundColor DarkGray
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -Help    " -NoNewline -ForegroundColor Green; Write-Host ": Show this help message`n"
    return
  }

  Write-Host "`n🌐 Network Information" -ForegroundColor Cyan
  Write-Host "----------------------" -ForegroundColor DarkGray

  $localIp = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi", "Ethernet" -ErrorAction SilentlyContinue |
      Where-Object { $_.IPAddress -notmatch '^169\.254\.' }).IPAddress | Select-Object -First 1

  if ($localIp)
  {
    Write-Host "   Local IP  : $localIp" -ForegroundColor Green
  } else
  {
    Write-Host "   Local IP  : Not Found / Disconnected" -ForegroundColor Red
  }

  try
  {
    $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 3 -UseBasicParsing).Trim()
    Write-Host "   Public IP : $publicIp" -ForegroundColor Green
  } catch
  {
    Write-Host "   Public IP : Offline or Timeout" -ForegroundColor Red
  }

  $proxy = $env:HTTP_PROXY ?? "Direct (No Proxy)"
  Write-Host "   Env Proxy : $proxy`n" -ForegroundColor Yellow
}
