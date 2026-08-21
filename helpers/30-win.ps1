# -----------------------------------------------------------------------------
# ULTIMATE WINDOWS SETTINGS LAUNCHER
# -----------------------------------------------------------------------------
function winset
{
  param(
    [ValidateSet(
      "help",
      # Developer & Hardware
      "env", "hosts", "features", "dev", "disk", "power",
      # System & Admin
      "godmode", "services", "registry", "policy", "events", "users",
      # Network
      "adapters", "network", "proxy",
      # General Settings
      "display", "apps", "startup", "update", "sound", "security"
    )]
    [string]$Target = "help",

    [switch]$Help
  )

  if ($Help -or $Target -eq "help")
  {
    Write-Host "`nUsage: ws [<Target>]" -ForegroundColor Cyan
    Write-Host "Quickly launch deep Windows settings and admin tools.`n" -ForegroundColor DarkGray

    Write-Host "🛠️ Developer & Hardware:" -ForegroundColor Yellow
    Write-Host "  env      " -NoNewline -ForegroundColor Green; Write-Host ": Environment Variables"
    Write-Host "  hosts    " -NoNewline -ForegroundColor Green; Write-Host ": Edit hosts file as Administrator (Neovim)"
    Write-Host "  features " -NoNewline -ForegroundColor Green; Write-Host ": Windows Optional Features (WSL, Hyper-V)"
    Write-Host "  dev      " -NoNewline -ForegroundColor Green; Write-Host ": Device Manager"
    Write-Host "  disk     " -NoNewline -ForegroundColor Green; Write-Host ": Disk Management"
    Write-Host "  power    " -NoNewline -ForegroundColor Green; Write-Host ": Advanced Power Options`n"

    Write-Host "💻 System & Admin:" -ForegroundColor Yellow
    Write-Host "  godmode  " -NoNewline -ForegroundColor Green; Write-Host ": Windows Master Control Panel (God Mode)"
    Write-Host "  services " -NoNewline -ForegroundColor Green; Write-Host ": Windows Services Manager"
    Write-Host "  registry " -NoNewline -ForegroundColor Green; Write-Host ": Registry Editor"
    Write-Host "  policy   " -NoNewline -ForegroundColor Green; Write-Host ": Local Group Policy Editor"
    Write-Host "  events   " -NoNewline -ForegroundColor Green; Write-Host ": Event Viewer"
    Write-Host "  users    " -NoNewline -ForegroundColor Green; Write-Host ": Advanced User Accounts (netplwiz)`n"

    Write-Host "🌐 Network:" -ForegroundColor Yellow
    Write-Host "  adapters " -NoNewline -ForegroundColor Green; Write-Host ": Network Connections (Classic Control Panel)"
    Write-Host "  network  " -NoNewline -ForegroundColor Green; Write-Host ": Network Status (UWP)"
    Write-Host "  proxy    " -NoNewline -ForegroundColor Green; Write-Host ": Network Proxy Settings`n"

    Write-Host "⚙️ General Settings:" -ForegroundColor Yellow
    Write-Host "  display  " -NoNewline -ForegroundColor Green; Write-Host ": Display Settings"
    Write-Host "  apps     " -NoNewline -ForegroundColor Green; Write-Host ": Installed Apps"
    Write-Host "  startup  " -NoNewline -ForegroundColor Green; Write-Host ": Startup Applications"
    Write-Host "  sound    " -NoNewline -ForegroundColor Green; Write-Host ": Classic Sound Control Panel"
    Write-Host "  security " -NoNewline -ForegroundColor Green; Write-Host ": Windows Security Center"
    Write-Host "  update   " -NoNewline -ForegroundColor Green; Write-Host ": Windows Update`n"
    return
  }

  switch ($Target)
  {
    # Developer & Hardware
    "env"
    { Start-Process "rundll32.exe" -ArgumentList "sysdm.cpl,EditEnvironmentVariables"
    }
    "hosts"
    {
      $editor = $env:EDITOR ?? "notepad"
      Start-Process "pwsh" -Verb RunAs -ArgumentList "-c $editor C:\Windows\System32\drivers\etc\hosts"
    }
    "features"
    { Start-Process "optionalfeatures.exe"
    }
    "dev"
    { Start-Process "devmgmt.msc"
    }
    "disk"
    { Start-Process "diskmgmt.msc"
    }
    "power"
    { Start-Process "powercfg.cpl"
    }

    # System & Admin
    "godmode"
    { Start-Process "explorer.exe" -ArgumentList "shell:::{ED7BA470-8E54-465E-825C-99712043E01C}"
    }
    "services"
    { Start-Process "services.msc"
    }
    "registry"
    { Start-Process "regedit.exe"
    }
    "policy"
    { Start-Process "gpedit.msc"
    }
    "events"
    { Start-Process "eventvwr.msc"
    }
    "users"
    { Start-Process "netplwiz.exe"
    }

    # Network
    "adapters"
    { Start-Process "ncpa.cpl"
    }
    "network"
    { Start-Process "ms-settings:network-status"
    }
    "proxy"
    { Start-Process "ms-settings:network-proxy"
    }

    # General Settings
    "display"
    { Start-Process "ms-settings:display"
    }
    "apps"
    { Start-Process "ms-settings:appsfeatures"
    }
    "startup"
    { Start-Process "ms-settings:startupapps"
    }
    "sound"
    { Start-Process "mmsys.cpl"
    }
    "security"
    { Start-Process "windowsdefender:"
    }
    "update"
    { Start-Process "ms-settings:windowsupdate"
    }
  }
}

Set-Alias -Name ws -Value winset
