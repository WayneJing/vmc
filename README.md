# Virtual Machine Controller(VMC)

[toc]

## TODO

- [ ] beautiful print for vmc list
- [x] attach/detach vf by virt-xml
- [ ] attach/detach disk by virt-xml
- [x] create vm by virt-clone

## Guides

### Dependency

-   xmllint: xml parsing tool
-   libguestfs-tools: guest image manage tool


### List VMs

```sh
vmc list
```

expected output:

```sh
NAME                                                         STATE      IP ADDRESS                     
============================================================================================
ubuntu2004-clean-mainline-promotion                          running    192.168.122.62                 
ubuntu2004-NV21-clean                                        stop       none                           
ubuntu2004-NV21-clean-mainline                               stop       none                           
ubuntu2004-NV21-clean-mainline-clone                         stop       none                           
ubuntu2004-NV21-clean-mainline-promotion                     stop       none                           
ubuntu2004-NV21-clean-research                               stop       none                           
vats-test-ubuntu2004-clean-mainline-promotion-01             stop       none                           
vats-test-ubuntu2004-clean-mainline-promotion-02             stop       none                           
vats-test-ubuntu2004-clean-mainline-promotion-03             stop       none                           
vats-test-ubuntu2004-clean-mainline-promotion-04             stop       none                           
```



**Verbose** version will show the vf device that attached to the vm

```sh
vmc list -v
```

expected output:

```sh
NAME                                                         STATE      IP ADDRESS           PCI DEVICE
============================================================================================
ubuntu2004-clean-mainline-promotion                          running    192.168.122.62       0000:06:00.0
ubuntu2004-NV21-clean                                        stop       none                 0000:0c:00.0
ubuntu2004-NV21-clean-mainline                               stop       none                 0000:06:02.0
ubuntu2004-NV21-clean-mainline-clone                         stop       none                 0000:06:02.0
ubuntu2004-NV21-clean-mainline-promotion                     stop       none                 0000:06:02.0
ubuntu2004-NV21-clean-research                               stop       none                 0000:0c:02.0
vats-test-ubuntu2004-clean-mainline-promotion-01             stop       none                 0000:0c:02.0
vats-test-ubuntu2004-clean-mainline-promotion-02             stop       none                 0000:06:02.1
vats-test-ubuntu2004-clean-mainline-promotion-03             stop       none                 0000:06:02.2
vats-test-ubuntu2004-clean-mainline-promotion-04             stop       none                 0000:06:02.3
```



### Start VMs

```sh
vmc start <domain_name>
vmc start <num> #will automatically start the VM that matches vats-test.*-xx
vmc start <pattern> #will automatically start the VM that starts with the pattern
```


### Destroy VMs

```sh
vmc destroy <domain_name>
vmc destroy <num> #will automatically destroy the VM that matches vats-test.*-xx
vmc destroy <pattern> #will automatically destroy the VM that starts with the pattern
```



### Connect VMs

```sh
vmc connect <domain_name> #will connect to the specific vm via ssh
vmc connect <num> #will automatically connect the VM that matches vats-test.*-xx
```



### Console

```sh
vmc console <domain_name> #will connect to the specific vm console via ssh
vmc console <num> #will automatically connect the VM console that matches vats-test.*-xx
```



### Change-dev

```sh
vmc change-dev <domain_name> <pci_bdf> # will remove all vf device attached to the vm and attach the specified device
```

### Clone

```sh
# clone a child VM from the base VM
vmc clone <base_domain_name> <child_domain_name>
```


### Reset VMs

```sh
vmc reset <domain_name>
vmc reset <num> #will automatically reset the VM that matches vats-test.*-xx
vmc reset <pattern> #will automatically reset the VM that starts with the pattern
```

***All command parameters support bash completion***

