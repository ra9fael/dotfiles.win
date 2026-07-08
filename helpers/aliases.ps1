# -----------------------------------------------------------------------------
# ALIASES & FUNCTIONS
# -----------------------------------------------------------------------------
function fvim
{
  if ($args.Count -eq 0)
  {
    nvim
  } else
  {
    nvim $args
  }
}

function profileedit
{
  nvim $PROFILE
}

function profilereload {
    . $PROFILE
    Write-Host "PowerShell profile reloaded." -ForegroundColor Green
}

function lg
{
  lazygit
}

function zj
{
  zellij
}

function nvimn
{
  param([string]$filePath, [switch]$clean, [switch]$help)

  if ($help)
  {
    Write-Host "Usage: nvimn [<filePath>] [-clean] [-help]"
    return
  }

  $_args = @("-u", "NONE")
  if ($clean)
  { $_args += "-i", "NONE"
  }
  if ($filePath)
  { $_args += $filePath
  }

  nvim @_args
}

function sshrsa
{
  param(
    [Parameter(Mandatory=$true)]
    [string]$Target
  )
  ssh -o HostKeyAlgorithms=+ssh-rsa `
    -o PubkeyAcceptedAlgorithms=+ssh-rsa `
    $Target
}
