$env:Path += ";$env:USERPROFILE\AppData\Local\Programs\oh-my-posh\bin;$env:ProgramFiles\Vim\vim91;"

function prompt {
    $loc = $PWD.Path.Replace("\","/")
    $upr = $env:USERPROFILE.Replace("\","/")
        $pr = $env:USERNAME + "@" + $env:COMPUTERNAME + ":[" + "<rep>" + "]$"
        if($loc -match $upr) { $pr = $pr.Replace("<rep>",($loc.Replace($upr,"~").Replace("/","\"))) }
    else {$pr = $pr.Replace("<rep>",$loc.Replace("\","/"))}
        "$pr "
}

function ll {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [string]$Path = "."
    )
    # Folders first (descending on PSIsContainer), then Name ascending
    Get-ChildItem -Force -Path $Path |
        Sort-Object -Property @{Expression='PSIsContainer';Descending=$true}, @{Expression='Name';Descending=$false} |
        Format-Table Mode, LastWriteTime, Length, Name -AutoSize
}

function which {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Name
    )

    $cmds = Get-Command -All -Name $Name -ErrorAction SilentlyContinue
    if (-not $cmds) {
        Write-Error "Command not found: $Name"
        return
    }

    foreach ($c in $cmds) {
        switch ($c.CommandType) {
            'Alias' {
                '{0} -> {1}' -f $c.Name, $c.Definition
            }
            'Function' {
                $mod = if ($c.ModuleName) { $c.ModuleName } else { 'global' }
                '{0} (function in {1})' -f $c.Name, $mod
            }
            'Application' {
                # Prefer Path if present; fall back to Source or Definition
                if ($c.Path) { $c.Path }
                elseif ($c.Source) { $c.Source }
                elseif ($c.Definition) { $c.Definition }
                else { $c.Name }
            }
            default {
                if ($c.Path) { $c.Path }
                elseif ($c.Source) { $c.Source }
                elseif ($c.Definition) { $c.Definition }
                else { $c.Name }
            }
        }
    }
}

. $env:USERPROFILE\Documents\WindowsPowerShell\Scripts\import-ssh-copy-id.ps1

$configPath = "$env:USERPROFILE\.config\winfetch\config.ps1"
if (Get-InstalledScript -Name winfetch -ErrorAction Ignore) {
    if (-not (Test-Path -Path $configPath -PathType Leaf)) {
        Write-Output "Winfetch config file not found on " + $configPath
	Write-Output "Create one following the instructions here https://github.com/lptstr/winfetch/wiki/Configuration#basic-configuration"
    } else {	
        winfetch -configpath $configPath
    }
} else {
    Write-Output "Winfetch not found."
    Write-Output "See https://github.com/lptstr/winfetch for installation instructions."
}

Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

$themes = @(
    "$env:POSH_THEMES_PATH\paradox.omp.json",
    "$env:POSH_THEMES_PATH\agnoster.omp.json",
    "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json",
    "$env:POSH_THEMES_PATH\powerline.omp.json",
    "$env:POSH_THEMES_PATH\hul10.omp.json"
)

oh-my-posh init pwsh --config $(Get-Random -InputObject $themes) | Invoke-Expression

Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
