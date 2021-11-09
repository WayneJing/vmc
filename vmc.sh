#!/bin/bash

# Prerequisite

## check fzf
if [ -z "$(which fzf | grep not)" ]; then
        export FZF_EXIST=1
else
        export FZF_EXIST=0
fi

## prevent wildcard expansion
set -o noglob


# glbal variable
# ip: vm's ip address
# pci: vm's pci device
# vmlist: current vm's list

# library

## get vm ip from vm's name
## $1: vm's name
_get_vm_ip ()
{
        ip=$(virsh domifaddr $1 | sed '1,2d' | awk '{print $4}')
        ip=${ip%/*}
}

## get vm pci dbsf from vm's name
## $1: vm's name
_get_vm_pci ()
{
        local xml dbsf
        xml=$(virsh dumpxml $1 | xmllint --xpath "//domain/devices/hostdev/source/address" -)
        if [ -z "$xml" ]; then
                pci=""
                return 0
        fi
        dbsf=$(echo "$xml" |  awk -F'[=/< "]' '{print $5 " " $9 " " $13 " " $17}')
        pci=$(echo "$dbsf" |  awk -F'[x ]' '{print $2":"$4":"$6"."$8}')
}

_finder_wrapper()
{
        local result=""
        if [ -n "$1" ]; then
                result=$(grep -E -m 1 "$1")
        fi
        if [ -z "$result" ] && [ 1 -eq $FZF_EXIST ]; then
                result=$(fzf -q "$1")
        fi
        echo "$result"
}

## match vm list
## $1   vm's name
## $2:  single -> match single vm
##      default -> match multi vm
_match_vmlist()
{
        # matching string end with *
        if [[ "$1" =~ [*\*$] ]];
        then
                local key=${1%\*}
                # matching string start with key
                vmlist=$(echo "$vmlist" | grep -E "^$key")
        else
                if [ 0 -eq $(echo "$1" | grep -cEi "[a-zA-Z]+") ] && [ -n "$1" ]; then
                        if [ "$2" == "single" ]; then
                                vmlist=$(echo $vmlist | grep -E "vats-test.*-$(printf "%02d" $1)")
                        else
                                local arr=()
                                for i in $(seq 1 $1);
                                do
                                        local tmp=$(echo "$vmlist" | grep -E "vats-test.*-$(printf "%02d" $i)")
                                        echo $tmp
                                        arr+=("$tmp")
                                done
                                vmlist=$arr
                        fi
                else
                        if [ "single" == "$1" ]; then
                                vmlist=$(echo "$vmlist" | _finder_wrapper "")
                        else
                                vmlist=$(echo "$vmlist" | _finder_wrapper "$1")
                        fi
                fi
        fi
}

# shell body

## list information of virtual machine
## $1: -v: verbose list
_list_vm()
{
        local name state
        vmlist=$(virsh list --all | sed '1,2d')
        if [ "$1" == "-v" ];
        then
                printf "%-60s %-10s %-20s %-10s\n" "NAME" "STATE" "IP ADDRESS" "PCI DEVICE"
        else
                printf "%-60s %-10s %-20s %-10s\n" "NAME" "STATE" "IP ADDRESS"
        fi
        printf "============================================================================================\n"
        while read -r vminfo; do
                name=$(echo "$vminfo" | awk '{print $2}')
                state=$(echo "$vminfo" | awk '{print $3}')
                if [ "$state" == "running" ];
                then
                        state="running"
                        _get_vm_ip "$name"
                        if [ ! -n "$ip" ];
                        then ip="none"
                        fi
                else
                        state="stop"
                        ip="none"
                fi
                if [ "$1" == "-v" ];
                then
                        _get_vm_pci "$name"
                        printf "%-60s %-10s %-20s %-10s\n" "$name" "$state" "$ip" "$pci"
                else
                        printf "%-60s %-10s %-20s %-10s\n" "$name" "$state" "$ip"
                fi
        done <<< "$vmlist"
}

## connect virtual machine
## $1: vm's name
_connect_vm()
{
        local state
        vmlist=$(virsh list --name)
        _match_vmlist $1 "single"
        if [ -z "$vmlist" ]; then
                echo "no matched vm"
                return -1
        fi
        state=$(virsh domstate $vmlist)
        if [ "$state" == "running" ];
        then
                ip=""
                while [ ! -n "$ip" ]
                do
                        sleep 1
                        _get_vm_ip $vmlist
                done
                until nc -vzw 2 $ip 22; do sleep 2; done
                sshpass -p amd1234 ssh -o StrictHostKeyChecking=no root@$ip
        else
                echo "VM is not running"
        fi
}

## start virtual machine
## $1: vm's name
_start_vm()
{
        vmlist=$(virsh list --name --all)
        _match_vmlist $1
        if [ -z "$vmlist" ];
        then
                echo "no matched vm"
        else
                while read -r vm; do
                        echo "starting $vm"
                        virsh start $vm
                done <<< "$vmlist"
        fi
}

## destroy virtual machine
## $1: vm's name
_destroy_vm()
{
        vmlist=$(virsh list --name)
        _match_vmlist $1
        if [ -z "$vmlist" ];
        then
                echo "no matched vm"
        else
                while read -r vm; do
                        echo "destroying $vm"
                        virsh destroy $vm
                done <<< "$vmlist"
        fi
}

## connect to vm console
## $1: vm's name
_connect_vm_console()
{
        local state
        vmlist=$(virsh list --name)
        _match_vmlist $1 "single"
        if [ -z "$vmlist" ];
        then
                echo "no matched vm"
                return -1
        fi
        state=$(virsh domstate $vmlist)
        if [ "$state" == "running" ];
        then
                ip=""
                while [ ! -n "$ip" ]
                do
                        sleep 1
                        _get_vm_ip $vmlist
                done
                until nc -vzw 2 $ip 22; do sleep 2; done
                virsh console $vmlist --force
        else
                echo "VM is not running"
        fi
}

## change attached vf device
## $1: vm's name
## $2: pci dbsf
_change_dev()
{
        vmlist=$(virsh list --name --all)
        _match_vmlist $1 "single"
        if [ -z "$vmlist" ];
        then
                echo "no matched vm"
                return -1
        fi
        _get_vm_pci "$vmlist"
        echo current device attached to $vmlist: $pci

        virt-xml $vmlist --remove-device --host-dev all
        pci=$(lspci -D| grep ATI | grep Display | _finder_wrapper "$2")
        if [ -n "$pci" ]; then
                virt-xml $vmlist --add-device --host-dev $(echo $pci | awk -F " " '{print $1}')
        else
                echo no pci-device attached
        fi
}

_help()
{
        case $1 in
        "--help"| "-h")
                echo "vmc <command> [args]"
                echo ""
                echo "commands:"
                echo ""
                printf "%-20s %-60s\n" "list" "list all virtual machines"
                printf "%-20s %-60s\n" "start" "start one/multi virtual machines according to pattern"
                printf "%-20s %-60s\n" "connect" "connect one virtual machine via ssh according to pattern"
                printf "%-20s %-60s\n" "destroy" "destroy one/multi virtual machines according to pattern"
                printf "%-20s %-60s\n" "console" "connect one virtual machine via console according to pattern"
                printf "%-20s %-60s\n" "change-dev" "change the vf attached to the virtual machine"
                printf "%-20s %-60s\n" "--help" "show this help document"
                echo ""
                echo "use vmc <command> --help to get detailed help"
                ;;
        "list")
                echo "NAME"
                echo "vmc list - list all virtual machines"
                echo ""
                echo "SYNOPSIS"
                echo "vmc list [-v]"
                echo ""
                echo "DESCRIPTION"
                echo "list all virtual machines' name, state and ip"
                echo ""
                echo "OPTION"
                printf "%-20s %-60s\n" "-v" "show the vf device attached to the virtual machine"
                ;;
        "start")
                echo "NAME"
                echo "vmc start - start one/multi virtual machines according to pattern"
                echo ""
                echo "SYNOPSIS"
                echo "vmc start <domain_name>           automatically start the VM"
                echo "vmc start <num>                   automatically start the VM that matches vats-test.*-xx"
                echo "vmc start <pattern>               automatically start the VM that starts with the pattern"
                echo ""
                echo "if fzf is installed"
                echo "vmc start                         call fzf to interactively find which vm to start"
                ;;
        "destroy")
                echo "NAME"
                echo "vmc destroy - destroy one/multi virtual machines according to pattern"
                echo ""
                echo "SYNOPSIS"
                echo "vmc destroy <domain_name>           automatically destroy the VM"
                echo "vmc destroy <num>                   automatically destroy the VM that matches vats-test.*-xx"
                echo "vmc destroy <pattern>               automatically destroy the VM that destroys with the pattern"
                echo ""
                echo "if fzf is installed"
                echo "vmc destroy                         call fzf to interactively find which vm to destroy"
                ;;
        "connect")
                echo "NAME"
                echo "vmc connect - connect one virtual machine via ssh according to pattern"
                echo ""
                echo "SYNOPSIS"
                echo "vmc connect <domain_name>           connect to the specific vm via ssh"
                echo "vmc connect <num>                   automatically connect the VM that matches vats-test.*-xx"
                echo ""
                echo "if fzf is installed"
                echo "vmc connect                         call fzf to interactively find which vm to connect"
                ;;
        "console")
                echo "NAME"
                echo "vmc console - connect one virtual machine via console according to pattern"
                echo ""
                echo "SYNOPSIS"
                echo "vmc console <domain_name>           connect to the specific vm via console"
                echo "vmc console <num>                   automatically connect the VM that matches vats-test.*-xx"
                echo ""
                echo "if fzf is installed"
                echo "vmc console                         call fzf to interactively find which vm to connect"
                ;;
        "change-dev")
                echo "NAME"
                echo "vmc change-dev - change the vf attached to the virtual machine"
                echo ""
                echo "SYNOPSIS"
                echo "vmc change-dev <domain_name> <pci_bdf>           change the specific vm to attach the specific device"
                echo "vmc change-dev <num> <pci_bdf>                   change the VM that matches vats-test.*-xx"
                echo ""
                echo "if fzf is installed"
                echo "vmc change-dev                                   call fzf to interactively find which vm to change and which device to attach"
                ;;
        *)
                echo "command undefined! Please use vmc --help"
                ;;
        esac
}
## vmc: virtual machine controller
if [ "${@: -1}" == "--help" ] || [ "${@: -1}" == "-h" ]; then
        _help $@
        exit 0
fi

case $1 in
"list")
        shift
        _list_vm $@
        ;;
"start")
        shift
        _start_vm $@
        ;;
"connect")
        shift
        _connect_vm $@
        ;;
"destroy")
        shift
        _destroy_vm $@
        ;;
"console")
        shift
        _connect_vm_console $@
        ;;
"change-dev")
        shift
        _change_dev $@
        ;;
*)
        echo "command undefined! Please use vmc --help"
esac

# clean and reset option

## restore wildcard expansion
set +o noglob
