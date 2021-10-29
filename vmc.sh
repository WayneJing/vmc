#!/bin/bash

#### get vm ip from vm name
_get_vm_ip ()
{
        ip=$(virsh domifaddr $1 | sed '1,2d' | awk '{print $4}')
        ip=${ip%/*}
}

_get_vm_pci ()
{
        local xml domain bus slot function
        xml=$(virsh dumpxml $1 | xmllint --xpath "//domain/devices/hostdev/source/address" -)
        domain=$(echo "$xml" | xmllint --xpath "//@domain" - | \
        awk -F\= '{print $2}' | tr -d \" | awk -F\x '{print $2}')
        bus=$(echo "$xml" | xmllint --xpath "//@bus" - | \
        awk -F\= '{print $2}' | tr -d \" | awk -F\x '{print $2}')
        slot=$(echo "$xml" | xmllint --xpath "//@slot" - | \
        awk -F\= '{print $2}' | tr -d \" | awk -F\x '{print $2}')
        function=$(echo "$xml" | xmllint --xpath "//@function" - | \
        awk -F\= '{print $2}' | tr -d \" | awk -F\x '{print $2}')
        pci="$domain:$bus:$slot.$function"
}

### list information of virtual machine
_list_vm()
{
        vmlist=$(virsh list --all | sed '1,2d')
        if [ "$2" == "-v" ];
        then
                printf "%-40s %-10s %-20s %-10s\n" "NAME" "STATE" "IP ADDRESS" "PCI DEVICE"
        else
                printf "%-40s %-10s %-20s %-10s\n" "NAME" "STATE" "IP ADDRESS"
        fi
        printf "=============================================================\n"
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
                if [ "$2" == "-v" ];
                then
                        _get_vm_pci "$name"
                        printf "%-40s %-10s %-20s %-10s\n" "$name" "$state" "$ip" "$pci"
                else
                        printf "%-40s %-10s %-20s %-10s\n" "$name" "$state" "$ip"
                fi
        done <<< "$vmlist"
}

#### match vm list
_match_vmlist()
{
        if [[ "$2" =~ [*\*$] ]];
        then
                local key=${2%\*}
                vmlist=$(echo "$vmlist" | grep $key)
        else
                vmlist=$2
        fi
}

### connect virtual machine
_connect_vm()
{
        state=$(virsh domstate $2)
        if [ "$state" == "running" ];
        then
                ip=""
                while [ ! -n "$ip" ]
                do
                        sleep 1
                        _get_vm_ip $2
                done
                until nc -vzw 2 $ip 22; do sleep 2; done
                sshpass -p amd1234 ssh -o StrictHostKeyChecking=no root@$ip
        else
                echo "VM is not running"
        fi
}

### start virtual machine
_start_vm()
{
        vmlist=$(virsh list --name --all)
        _match_vmlist $@
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

### destroy virtual machine
_destroy_vm()
{
        vmlist=$(virsh list --name)
        _match_vmlist $@
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

## vmc: virtual machine controller
case $1 in
"list")
        _list_vm $@
        ;;
"start")
        _start_vm $@
        ;;
"connect")
        _connect_vm $@
        ;;
"destroy")
        _destroy_vm $@
        ;;
esac

