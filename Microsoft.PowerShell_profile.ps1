# -----------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# -----------------------------------------------------------------------------
$env:SHELL = "pwsh"
$env:EDITOR = "nvim"
$MaximumHistoryCount = 32767

# -----------------------------------------------------------------------------
# MODULES & HELPERS
# -----------------------------------------------------------------------------
Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue

$helpersDir = "$PSScriptRoot/helpers"
if (Test-Path $helpersDir)
{
  Get-ChildItem -Path $helpersDir -Filter *.ps1 -File | ForEach-Object { . $_.FullName }
}

# -----------------------------------------------------------------------------
# HISTORY MANAGEMENT
# -----------------------------------------------------------------------------
Set-PSReadLineOption -HistoryNoDuplicates

Set-PSReadLineOption -HistorySavePath "$env:USERPROFILE\.powershell\pwsh_history.txt"

Set-PSReadLineOption -AddToHistoryHandler {
  param([string]$line)

  if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 3)
  {
    return $false
  }

  if ($line -match '^(clear|cls)$')
  {
    return $false
  }

  $sensitiveKeywords = @('password', 'token', 'secret', 'apikey', 'sk-')
  foreach ($keyword in $sensitiveKeywords)
  {
    if ($line -match "(?i)$keyword")
    {
      return $false
    }
  }

  return $true
}

# -----------------------------------------------------------------------------
# STARTUP CACHE & INIT
# -----------------------------------------------------------------------------
$cacheDir = "$env:LOCALAPPDATA\pwsh_cache"
if (-not (Test-Path $cacheDir))
{
  New-Item -ItemType Directory -Path $cacheDir | Out-Null
}

# Starship
$starshipCache = "$cacheDir\starship.ps1"
if (-not (Test-Path $starshipCache))
{
  starship init powershell | Out-File $starshipCache -Encoding utf8
}
. $starshipCache

# Zoxide
$zoxideCache = "$cacheDir\zoxide.ps1"
if (-not (Test-Path $zoxideCache))
{
  zoxide init powershell | Out-File $zoxideCache -Encoding utf8
}
. $zoxideCache

# uv
$uvCache = "$cacheDir\uv.ps1"
if (-not (Test-Path $uvCache) -and (Get-Command uv -ErrorAction SilentlyContinue))
{
  uv generate-shell-completion powershell | Out-File $uvCache -Encoding utf8
}
if (Test-Path $uvCache)
{
  . $uvCache
}
