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
    Param( [parameter(position=1)][String] $currPath )
    if($currPath -eq "") {
        Get-ChildItem $PWD -Force
    }
    else {
        Get-ChildItem $currPath -Force
    }
}

function which($cmd) { get-command $cmd | % { $_.Path } }

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

Import-Module posh-git

Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

oh-my-posh --init --shell pwsh --config "$env:POSH_THEMES_PATH\agnoster.omp.json" | Invoke-Expression

Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
