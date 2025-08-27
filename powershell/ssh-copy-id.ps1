function ssh-copy-id {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$UserHost,

        [Alias('i')]
        [string[]]$IdentityFile,

        [Alias('p')]
        [int]$Port,

        [Alias('o')]
        [string[]]$Option,

        [Alias('f')]
        [switch]$Force,

        [Alias('n')]
        [switch]$DryRun
    )

    $defaultCandidates = @(
        "$HOME\.ssh\id_rsa.pub",
        "$HOME\.ssh\id_ecdsa.pub",
        "$HOME\.ssh\id_ed25519.pub"
    )

    $keys = @()
    if ($IdentityFile) {
        foreach ($path in $IdentityFile) {
            $p = $path
            if (-not $p.EndsWith('.pub')) {
                $candidate = "$p.pub"
                if (Test-Path $candidate) { $p = $candidate }
            }
            if (-not (Test-Path $p)) { throw "Public key not found: $p" }
            $keys += (Resolve-Path $p).Path
        }
    } else {
        $found = $defaultCandidates | Where-Object { Test-Path $_ }
        if (-not $found) { throw "No public keys found. Generate one: ssh-keygen -t ed25519" }
        $keys += (Resolve-Path $found[0]).Path
    }

    $sshArgs = @()
    if ($Port)   { $sshArgs += @('-p', $Port) }
    if ($Option) { foreach ($opt in $Option) { $sshArgs += @('-o', $opt) } }

    if ($DryRun) {
        Write-Host ("DRY RUN: would install keys to {0}:" -f $UserHost) -ForegroundColor Yellow
        $keys | ForEach-Object { Write-Host "  $_" }
        if ($sshArgs) { Write-Host ("SSH args: {0}" -f ($sshArgs -join ' ')) -ForegroundColor Yellow }
        return
    }

    Write-Host "🔐 Note: You may be asked for your password twice — once for file transfer (scp), and once for remote execution (ssh)." -ForegroundColor Yellow

    foreach ($keyPath in $keys) {
        if (-not (Test-Path $keyPath)) { throw "Missing key: $keyPath" }

        $remoteTemp = "tempkey-$([Guid]::NewGuid().ToString('N')).pub"
        scp $keyPath "${UserHost}:~/$remoteTemp"

        $prepCmd   = 'set -e && umask 077 && mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys'
        $crlfCmd   = "tr -d '\r' < ~/$remoteTemp > ~/$remoteTemp.clean"

        if ($Force) {
            $appendCmd = "cat ~/$remoteTemp.clean >> ~/.ssh/authorized_keys"
        } else {
            $dedupeTpl = 'K=$(cat ~/{TEMP}.clean); grep -qxF "$K" ~/.ssh/authorized_keys || printf ''%s\n'' "$K" >> ~/.ssh/authorized_keys'
            $appendCmd = $dedupeTpl.Replace('{TEMP}', $remoteTemp)
        }

        $cleanupCmd = "rm -f ~/$remoteTemp ~/$remoteTemp.clean && chmod 600 ~/.ssh/authorized_keys"
        $remoteCmd = ($prepCmd, $crlfCmd, $appendCmd, $cleanupCmd) -join ' && '

        & ssh @sshArgs ${UserHost} $remoteCmd
        if ($LASTEXITCODE -ne 0) { throw "Failed to install key $(Split-Path $keyPath -Leaf) to $UserHost" }

        Write-Host "✅ Installed $(Split-Path $keyPath -Leaf) to $UserHost" -ForegroundColor Green
    }
}
