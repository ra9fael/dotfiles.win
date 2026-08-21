function proxy
{
  param(
    [string]$Action = "toggle",
    [string]$IP = "127.0.0.1",
    [string]$Port = "7897"
  )

  $ProxyServer = "http://$IP`:$Port"
  $ProxyUri    = [System.Uri]::new($ProxyServer)
  $ProxyObject = [System.Net.WebProxy]::new($ProxyUri)

  $Green  = "Green"; $Red = "Red"; $Yellow = "Yellow"; $Cyan = "Cyan"

  $EnvProxy = $env:HTTP_PROXY ?? $env:http_proxy
  $IsEnvProxySet = $EnvProxy -eq $ProxyServer

  $HttpClientProxy = [System.Net.Http.HttpClient]::DefaultProxy
  $IsHttpClientProxySet = $false
  if ($null -ne $HttpClientProxy)
  {
    $address = if ($HttpClientProxy -is [System.Net.WebProxy])
    { $HttpClientProxy.Address
    } else
    { $HttpClientProxy.GetProxy($ProxyUri)
    }
    if ($address -and $address.AbsoluteUri)
    { $IsHttpClientProxySet = $address.AbsoluteUri -eq $ProxyServer
    }
  }

  switch ($Action.ToLower())
  {
    "on"
    {
      $env:HTTP_PROXY = $ProxyServer; $env:HTTPS_PROXY = $ProxyServer
      $env:http_proxy = $ProxyServer; $env:https_proxy = $ProxyServer
      [System.Net.WebRequest]::DefaultWebProxy = $ProxyObject
      [System.Net.Http.HttpClient]::DefaultProxy = $ProxyObject
      Write-Host "Proxy enabled: $ProxyServer" -ForegroundColor $Green
    }
    "off"
    {
      Remove-Item Env:HTTP_PROXY, Env:HTTPS_PROXY, Env:http_proxy, Env:https_proxy -ErrorAction SilentlyContinue
      $emptyProxy = [System.Net.WebProxy]::new()
      [System.Net.WebRequest]::DefaultWebProxy = $emptyProxy
      [System.Net.Http.HttpClient]::DefaultProxy = $emptyProxy
      Write-Host "Proxy disabled" -ForegroundColor $Red
    }
    "status"
    {
      Write-Host "Proxy Status:" -ForegroundColor $Cyan
      Write-Host "  HTTP_PROXY:  $($env:HTTP_PROXY ?? 'Not set')"
      Write-Host "  HTTPS_PROXY: $($env:HTTPS_PROXY ?? 'Not set')"

      $httpClientProxy = [System.Net.Http.HttpClient]::DefaultProxy
      if ($null -ne $httpClientProxy)
      {
        $dotNetAddress = if ($httpClientProxy -is [System.Net.WebProxy])
        { $httpClientProxy.Address
        } else
        { $httpClientProxy.GetProxy("https://example.com")
        }
        Write-Host "  HttpClient (iwr) Proxy: $(if ($dotNetAddress -and $dotNetAddress.AbsoluteUri) {$dotNetAddress.AbsoluteUri} else {'Direct'})"
      } else
      { Write-Host "  HttpClient (iwr) Proxy: Not set"
      }

      if ($IsEnvProxySet -or $IsHttpClientProxySet)
      {
        Write-Host "  Testing connection to Google..." -ForegroundColor $Yellow
        try
        {
          $null = Invoke-WebRequest -Uri "https://www.google.com" -TimeoutSec 5 -UseBasicParsing
          Write-Host "  Connection test: SUCCESS" -ForegroundColor $Green
        } catch
        { Write-Host "  Connection test: FAILED" -ForegroundColor $Red
        }
      } else
      { Write-Host "  Status: DISABLED" -ForegroundColor $Red
      }
    }
    "toggle"
    {
      if ($IsEnvProxySet -or $IsHttpClientProxySet)
      { proxy -Action off -IP $IP -Port $Port
      } else
      { proxy -Action on -IP $IP -Port $Port
      }
    }
    "reset"
    {
      Remove-Item Env:HTTP_PROXY, Env:HTTPS_PROXY, Env:http_proxy, Env:https_proxy -ErrorAction SilentlyContinue
      $defaultProxy = [System.Net.WebRequest]::GetSystemWebProxy()
      [System.Net.WebRequest]::DefaultWebProxy = $defaultProxy
      [System.Net.Http.HttpClient]::DefaultProxy = $defaultProxy
      Write-Host "Proxy reset to system default (IE settings)" -ForegroundColor $Yellow
    }
    default
    {
      Write-Host "Valid actions: on, off, status, toggle, reset" -ForegroundColor $Yellow
    }
  }
}

Set-Alias -Name pxy -Value proxy
