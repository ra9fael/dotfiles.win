# -----------------------------------------------------------------------------
# CUSTOM LOADER
# -----------------------------------------------------------------------------
# Auto-loads per-machine scripts from ../custom. The folder is git-ignored
# (except this repo's .gitkeep), so each machine can carry its own env vars,
# proxies, private aliases, etc. without polluting the shared profile repo.
#
# Scripts are dotted into the global scope, so they can override helper
# functions/aliases. This file is named with a "zz-" prefix so it sorts LAST
# among helpers and therefore wins over them.
#
# Ordering: files are loaded by full path (depth-first, alphabetical). Use a
# numeric prefix (e.g. 10-env.ps1, 20-aliases.ps1) to control load order.
# Subfolders are supported (e.g. custom/aliases/, custom/env/).

$customDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'custom'

if (Test-Path -LiteralPath $customDir -PathType Container)
{
    Get-ChildItem -Path $customDir -Filter *.ps1 -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            try
            {
                . $_.FullName
            }
            catch
            {
                Write-Warning "custom-loader: failed to load '$($_.Name)': $_"
            }
        }
}
