# -----------------------------------------------------------------------------
# STARTUP CACHE & INIT
# -----------------------------------------------------------------------------
# Generated init scripts (starship / zoxide / uv) live in $cacheDir, never in
# version-controlled profile files.
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
