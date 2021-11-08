#!/bin/bash

if [ -z "$(which fzf | grep not)" ]; then
        export FZF_EXIST=1
else
        export FZF_EXIST=0
fi
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
                if [ "$2" == "-v" ];
                then
                        _get_vm_pci "$name"
                        printf "%-60s %-10s %-20s %-10s\n" "$name" "$state" "$ip" "$pci"
                else
                        printf "%-60s %-10s %-20s %-10s\n" "$name" "$state" "$ip"
                fi
        done <<< "$vmlist"
}

#### match vm list
_match_vmlist()
{
        # matching string end with *
        if [[ "$2" =~ [*\*$] ]];
        then
                local key=${2%\*}
                # matching string start with key
                vmlist=$(echo "$vmlist" | grep "^$key")
        else
                _fuzzer_filter_vm $@
        fi
}

#### filter vm via fuzzer matching
_fuzzer_filter_vm()
{
        if [ 0 -eq $FZF_EXIST ]; then
                vmlist=$2
                return 0
        fi
        if [ -z "$2" ]; then
                vmlist=$(echo "$vmlist" | fzf)
        elif [ 0 -eq $(echo $2 | grep -cEi "[a-zA-Z]+") ]; then
                if [ -z $(echo "$1" | grep -E "[(connect)|(console)]") ]; then
                        vmlist=$(echo $vmlist | grep -E "vats-test.*-$(printf "%02d" $2)")
                else
                        local arr=()
                        for i in $(seq 1 $2);
                        do
                                local tmp=$(echo "$vmlist" | grep -E "vats-test.*-$(printf "%02d" $i)")
                                echo $tmp
                                arr+=("$tmp")
                        done
                        vmlist=$arr
                fi
        fi

}
### connect virtual machine
_connect_vm()
{
        vmlist=$(virsh list --name)
        _fuzzer_filter_vm $@
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

### connect to vm console
_connect_vm_console()
{
        vmlist=$(virsh list --name)
        _fuzzer_filter_vm $@
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
"console")
        _connect_vm_console $@
        ;;
esac

