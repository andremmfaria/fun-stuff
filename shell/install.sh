#!/bin/sh

if [ -f $HOME/.zshrc ]; then
  echo "ZSH detected"

  echo "Installing fzf and integrating it on .zshrc..."
  sudo apt install fzf -y
  echo "source <(fzf --zsh)" >> $HOME/.zshrc

  echo "Installing fastfetch and integrating it..."
  sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
  sudo apt install fastfetch -y
  mkdir -p $HOME/.config/fastfetch
  cp ./fastfetch-config.jsonc $HOME/.config/fastfetch/config.jsonc
  echo "fastfetch -c $HOME/.config/fastfetch/config.jsonc" >> $HOME/.zshrc
fi

