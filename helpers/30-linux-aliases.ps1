# -----------------------------------------------------------------------------
# LINUX-STYLE COMMAND HELPERS
# Auto-loaded by the profile (helpers/*.ps1 are dot-sourced on startup).
#
# PHILOSOPHY: prefer the real open-source tools over hand-rolled PowerShell.
# The heavy GNU commands below are provided by Microsoft.Coreutils
# (winget install Microsoft.Coreutils) and are therefore NOT reimplemented
# here -- PowerShell function/alias resolution would otherwise shadow the
# real binaries. This file only defines what those packages do NOT cover.
#
# Provided by Microsoft.Coreutils (do NOT redefine):
#   ls cat cp mv rm mkdir rmdir pwd echo sleep tee sort uniq cut tr wc head
#   tail touch ln du df grep find xargs diff stat seq printf date hostname
#   uptime ...
#
# Still provided below (NOT part of coreutils):
#   which         - coreutils has no `which`
#   export/unset  - env-var helpers (shell builtins, no external binary)
# -----------------------------------------------------------------------------

# --- which -----------------------------------------------------------------
function which
{
  <#
  .SYNOPSIS
  Locate a command, like GNU which. With -a, list all matches.
  #>
  param(
    [Parameter(Mandatory = $true, ValueFromRemainingArguments)]
    [string[]]$Name,
    [switch]$a
  )

  foreach ($n in $Name)
  {
    $cmds = Get-Command -Name $n -All -ErrorAction SilentlyContinue
    if (-not $cmds)
    {
      Write-Warning "which: no $n in PATH"
      continue
    }
    foreach ($c in $cmds)
    {
      if ($c.CommandType -in 'Application', 'ExternalScript')
      {
        $c.Source
      }
      else
      {
        '{0} -> {1} ({2})' -f $c.Name, $c.CommandType, $c.Source
      }
      if (-not $a) { break }
    }
  }
}

# --- export / unset (env vars) ---------------------------------------------
function export
{
  param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Assignment
  )
  foreach ($a in $Assignment)
  {
    if ($a -match '^([^=]+)=(.*)$')
    {
      Set-Item -Path "Env:$($matches[1])" -Value $matches[2]
    }
  }
}

function unset
{
  param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Name
  )
  foreach ($n in $Name)
  {
    Remove-Item -Path "Env:$n" -ErrorAction SilentlyContinue
  }
}

