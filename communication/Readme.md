# Vats TCP communication

this is a tool to isolate vats tcp server communication. we can directly use vats_tcp_comm.py to let vats tcp sever to run cmd inside vm.

## example

```bash
python3 vats_tcp_comm.py --ip <vm_ip>  --port <port> --cmd <cmd>

#or use the built binary in dist/
./vats_tcp_comm --ip <vm_ip>  --port <port> --cmd <cmd>

#help doc
➜  ./vats_tcp_comm -h
usage: vats_tcp_comm [-h] [--ip IP] [--port PORT] [--cmd CMD]

communicate with VatsTCPServer to run a cmd in server

optional arguments:
  -h, --help   show this help message and exit
  --ip IP      the vm ip
  --port PORT  the vm tcp server port
  --cmd CMD    enter the cmd string you want to execute
```