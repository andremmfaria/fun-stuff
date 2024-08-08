# Install terminal things script

echo "Installing git and posh-git... (accept any prompt message that appears)"
winget install --id Git.Git -s winget
Install-Module posh-git -Scope CurrentUser -Force

echo "Installing oh-my-posh... (accept any prompt message that appears)"
winget install --id JanDeDobbeleer.OhMyPosh -s winget
$env:Path += ";$env:USERPROFILE\AppData\Local\Programs\oh-my-posh\bin"

echo "Installing winfetch... (accept any prompt message that appears)"
Install-Script winfetch -Scope CurrentUser -Force
mv .\.config $env:USERPROFILE

echo "Installing fzf... (accept any prompt message that appears)"
winget install --id junegunn.fzf -s winget
Install-Module -Name PSFzf -Scope CurrentUser -Force

