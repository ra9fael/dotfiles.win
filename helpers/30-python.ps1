function Enable-PythonGpuRuntime {
    [CmdletBinding()]
    param(
        [switch]$Quiet
    )

    $pythonCmd = Get-Command python -ErrorAction Stop
    $sitePackages = & $pythonCmd.Source -c `
        "import sysconfig; print(sysconfig.get_paths()['purelib'])"

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $sitePackages)) {
        throw "Cannot determine the active Python environment's site-packages path."
    }

    # NVIDIA pip wheels place CUDA/cuDNN DLLs here.
    $dllDirs = @(
        Get-ChildItem -Path "$sitePackages\nvidia\*\bin" -Directory `
            -ErrorAction SilentlyContinue

        # Common GPU frameworks which bundle runtime DLLs themselves.
        Get-Item -Path "$sitePackages\torch\lib" -ErrorAction SilentlyContinue
        Get-Item -Path "$sitePackages\ctranslate2" -ErrorAction SilentlyContinue
    ) |
        Where-Object { $_ -and (Test-Path $_.FullName) } |
        Select-Object -ExpandProperty FullName -Unique

    if (-not $dllDirs) {
        throw "No CUDA/cuDNN runtime DLL directories found in: $sitePackages"
    }

    # Prepend active environment paths, without duplicating existing entries.
    $oldPaths = @($env:Path -split ';' | Where-Object { $_ })
    $newPaths = @($dllDirs | Where-Object { $_ -notin $oldPaths })

    if ($newPaths) {
        $env:Path = ($newPaths + $oldPaths) -join ';'
    }

    if (-not $Quiet) {
        Write-Host "GPU runtime enabled for:" $env:VIRTUAL_ENV
        $dllDirs | ForEach-Object { Write-Host "  $_" }
    }
}
