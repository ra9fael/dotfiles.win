# -----------------------------------------------------------------------------
# MAIN PROFILE ENTRY
# -----------------------------------------------------------------------------
# Loaded by the thin bootstrap (Microsoft.PowerShell_profile.ps1). This is the
# real entry point: import startup modules, then dot-source every helper in
# name order (numeric prefixes control order, e.g. 00-env, 20-cache, zz-custom).

Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue

$helpersDir = Join-Path $PSScriptRoot 'helpers'
if (Test-Path -LiteralPath $helpersDir)
{
    Get-ChildItem -Path $helpersDir -Filter *.ps1 -File | Sort-Object Name | ForEach-Object {
        $f = $_
        try { . $f.FullName }
        catch { Write-Warning "profile: '$($f.Name)' failed: $_" }
    }
}
