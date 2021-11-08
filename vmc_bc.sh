#!/bin/bash

_vmc()
{
        if [[ "${COMP_CWORD}" == "1" ]];
        then
                COMPREPLY=( $( compgen -W "list start connect destroy console" -- ${COMP_WORDS[${COMP_CWORD}]}))
        else
                local word=${COMP_WORDS[COMP_CWORD-1]}
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
                esac
                COMPREPLY=( $( compgen -W "$vmlist" -- ${COMP_WORDS[${COMP_CWORD}]}))
        fi
}

complete -F _vmc vmc
