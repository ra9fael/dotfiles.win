# -----------------------------------------------------------------------------
# THIN BOOTSTRAP
# -----------------------------------------------------------------------------
# The real profile lives in main.ps1 (version-controlled). This file is kept
# deliberately tiny so auto-modifying tools (e.g. the coreutils installer)
# never have a reason to grow it. Local edits made by such tools are excluded
# from git via: git update-index --skip-worktree Microsoft.PowerShell_profile.ps1

$main = Join-Path $PSScriptRoot 'main.ps1'
if (Test-Path -LiteralPath $main) { . $main }
