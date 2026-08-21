using namespace System.Management.Automation
using namespace System.Management.Automation.Language

Import-Module PSReadLine

Set-PSReadLineOption -BellStyle Visual

Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -HistoryNoDuplicates

# Enable smart history prediction (ListView shows history suggestions in a dropdown list)
# Prediction needs an interactive VT console; skip when output is redirected
# (e.g. `pwsh -Command` piped from another tool) so it doesn't throw mid-file.
if (-not [Console]::IsOutputRedirected)
{
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
}

# History file location + filter (all PSReadLine options live in this file)
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

Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
function vhist
{ nvim (Get-PSReadLineOption).HistorySavePath
}
function Clean-History
{
    <#
    .SYNOPSIS
    Deduplicates the PSReadLine history file, keeping only the most recent commands.
    #>
    try
    {
        $historyPath = (Get-PSReadLineOption).HistorySavePath
        if (-not (Test-Path $historyPath))
        { return
        }

        $lines = [System.IO.File]::ReadAllLines($historyPath)
        $hash = [System.Collections.Generic.HashSet[string]]::new()
        $clean = [System.Collections.Generic.List[string]]::new($lines.Count)

        # Reverse iteration to keep the most recent occurrence of each command
        for ($i = $lines.Count - 1; $i -ge 0; $i--)
        {
            if (-not [string]::IsNullOrWhiteSpace($lines[$i]) -and $hash.Add($lines[$i]))
            {
                $clean.Add($lines[$i])
            }
        }

        $clean.Reverse()
        [System.IO.File]::WriteAllLines($historyPath, $clean)
    } catch
    {
        # Silently fail if the file is locked by another concurrent session (e.g., Zellij)
    }
}

# Create a short alias for manual triggering if needed
Set-Alias -Name chist -Value Clean-History -ErrorAction SilentlyContinue
Clean-History

# Basic arrow key search and exit
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -ScriptBlock { [System.Environment]::Exit(0) }
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Utility shortcuts
Set-PSReadLineKeyHandler -Key Alt+w -BriefDescription SaveInHistory -ScriptBlock {
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
}

Set-PSReadLineKeyHandler -Key 'Alt+(' -BriefDescription ParenthesizeSelection -ScriptBlock {
    $selStart = $null; $selLen = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selStart, [ref]$selLen)
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($selStart -ne -1)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selStart, $selLen, '(' + $line.SubString($selStart, $selLen) + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selStart + $selLen + 2)
    } else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, '(' + $line + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
    }
}

Set-PSReadLineKeyHandler -Key "Alt+'" -BriefDescription ToggleQuoteArgument -ScriptBlock {
    $ast = $null; $tokens = $null; $errors = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)
    $tokenToChange = $null
    foreach ($token in $tokens)
    {
        $extent = $token.Extent
        if ($extent.StartOffset -le $cursor -and $extent.EndOffset -ge $cursor)
        {
            $tokenToChange = $token
            if ($extent.EndOffset -eq $cursor -and $foreach.MoveNext())
            {
                $nextToken = $foreach.Current
                if ($nextToken.Extent.StartOffset -eq $cursor)
                { $tokenToChange = $nextToken
                }
            }
            break
        }
    }
    if ($tokenToChange -ne $null)
    {
        $extent = $tokenToChange.Extent; $tokenText = $extent.Text
        if ($tokenText[0] -eq '"' -and $tokenText[-1] -eq '"')
        { $replacement = $tokenText.Substring(1, $tokenText.Length - 2)
        } elseif ($tokenText[0] -eq "'" -and $tokenText[-1] -eq "'")
        { $replacement = '"' + $tokenText.Substring(1, $tokenText.Length - 2) + '"'
        } else
        { $replacement = "'" + $tokenText + "'"
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($extent.StartOffset, $tokenText.Length, $replacement)
    }
}

Set-PSReadLineKeyHandler -Key "Alt+%" -BriefDescription ExpandAliases -ScriptBlock {
    $ast = $null; $tokens = $null; $errors = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)
    $startAdjustment = 0
    foreach ($token in $tokens)
    {
        if ($token.TokenFlags -band [TokenFlags]::CommandName)
        {
            $alias = $ExecutionContext.InvokeCommand.GetCommand($token.Extent.Text, 'Alias')
            if ($alias -ne $null -and $alias.ResolvedCommandName)
            {
                $extent = $token.Extent; $length = $extent.EndOffset - $extent.StartOffset
                [Microsoft.PowerShell.PSConsoleReadLine]::Replace($extent.StartOffset + $startAdjustment, $length, $alias.ResolvedCommandName)
                $startAdjustment += ($alias.ResolvedCommandName.Length - $length)
            }
        }
    }
}

Set-PSReadLineKeyHandler -Key F1 -BriefDescription CommandHelp -ScriptBlock {
    $ast = $null; $tokens = $null; $errors = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)
    $commandAst = $ast.FindAll( { $node = $args[0]; $node -is [CommandAst] -and $node.Extent.StartOffset -le $cursor -and $node.Extent.EndOffset -ge $cursor }, $true) | Select-Object -Last 1
    if ($commandAst)
    {
        $commandName = $commandAst.GetCommandName()
        if ($commandName)
        {
            $command = $ExecutionContext.InvokeCommand.GetCommand($commandName, 'All')
            if ($command -is [AliasInfo])
            { $commandName = $command.ResolvedCommandName
            }
            if ($commandName)
            { Get-Help $commandName -ShowWindow
            }
        }
    }
}

# --- Smart Insert/Delete (Quotes and Braces matching) ---
Set-PSReadLineKeyHandler -Key '(','{','[' -BriefDescription InsertPairedBraces -ScriptBlock {
    $key = $args[0]
    $closeChar = switch ($key.KeyChar)
    { '('
        {')'
        }; '{'
        {'}'
        }; '['
        {']'
        }
    }
    $selStart = $null; $selLen = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selStart, [ref]$selLen)
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($selStart -ne -1)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selStart, $selLen, $key.KeyChar + $line.SubString($selStart, $selLen) + $closeChar)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selStart + $selLen + 2)
    } else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
}

Set-PSReadLineKeyHandler -Key ')',']','}' -BriefDescription SmartCloseBraces -ScriptBlock {
    $key = $args[0]
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($cursor -lt $line.Length -and $line[$cursor] -eq $key.KeyChar)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    } else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
    }
}

Set-PSReadLineKeyHandler -Key Backspace -BriefDescription SmartBackspace -ScriptBlock {
    $key = $args[0]
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($cursor -gt 0)
    {
        $toMatch = $null
        if ($cursor -lt $line.Length)
        {
            switch ($line[$cursor])
            {
                '"'
                { $toMatch = '"'
                }
                "'"
                { $toMatch = "'"
                }
                ')'
                { $toMatch = '('
                }
                ']'
                { $toMatch = '['
                }
                '}'
                { $toMatch = '{'
                }
            }
        }
        if ($toMatch -ne $null -and $line[$cursor-1] -eq $toMatch)
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
        } else
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $null)
        }
    }
}
