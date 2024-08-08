#!/bin/bash

#Put this on your ".*rc" after installing cowsay and fortune

COMMANDS=(cowsay cowthink)
COW=$(ls /usr/share/cowsay/cows/ | shuf -n 1)
EYES=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 1 | head -n 1)
TONG=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 1 | head -n 1)

if [  -x $(which cowsay) -a -x $(which cowthink) -a -x $(which fortune) ]; then
  fortune -a | $(echo ${COMMANDS[RANDOM % ${#COMMANDS[@]}]}) -f $COW -e $EYES$EYES -T $TONG$TONG
fi
