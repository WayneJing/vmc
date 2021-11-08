#!/bin/bash

_vmc()
{
        if [[ "${COMP_CWORD}" == "1" ]];
        then
                COMPREPLY=( $( compgen -W "list start connect destroy console change-dev" -- ${COMP_WORDS[${COMP_CWORD}]}))
        elif [[ "${COMP_CWORD}" == "2" ]]; then
                local word=${COMP_WORDS[1]}
                local vmlist
                case ${word} in
                start)
                        vmlist=$(virsh list --name --all)
                        ;;
                connect)
                        vmlist=$(virsh list --name)
                        ;;
                destroy)
                        vmlist=$(virsh list --name)
                        ;;
                console)
                        vmlist=$(virsh list --name)
                        ;;
                change-dev)
                        vmlist=$(virsh list --name --all)
                        ;;
                esac
                COMPREPLY=( $( compgen -W "$vmlist" -- ${COMP_WORDS[${COMP_CWORD}]}))
        elif [[ "${COMP_CWORD}" == "3" ]]; then
                local word=${COMP_WORDS[1]}
                local pci
                case ${word} in
                change-dev)
                        pci=$(lspci -D | grep ATI | grep Display | awk -F" " '{print $1}')
                        ;;
                esac
                COMPREPLY=( $( compgen -W "$pci" -- ${COMP_WORDS[${COMP_CWORD}]}))
        fi
}

complete -F _vmc vmc
