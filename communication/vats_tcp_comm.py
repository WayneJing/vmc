import VatsTCPChannel
import argparse

def run_cmd():
    channel = VatsTCPChannel.VatsTCPChannel(ip=ip, port=port)
    ret = channel.execute(cmd)
    print(ret)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="communicate with VatsTCPServer to run a cmd in server")
    parser.add_argument("--ip", default="", help="the vm ip")
    parser.add_argument("--port", default="5902", help="the vm tcp server port")
    parser.add_argument("--cmd", default="echo hello", help="enter the cmd string you want to execute")

    args = parser.parse_args()
    cmd = args.cmd
    ip = args.ip
    port = args.port
    run_cmd()
