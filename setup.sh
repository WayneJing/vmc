#!/bin/bash

path=$(pwd)
ln -s $path/vmc.sh /usr/bin/vmc
ln -s $path/vmc_bc.sh /etc/bash_completion.d

if [[ "$SHELL" =~ bash ]]; then
        echo "source /etc/bash_completion.d/vmc_bc.sh" >> $HOME/.bashrc
        source $HOME/.bashrc
elif [[ "$SHELL" =~ zsh ]]; then
        echo "source /etc/bash_completion.d/vmc_bc.sh" >> $HOME/.zshrc
        source $HOME/.zshrc
fi
