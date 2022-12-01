import os
import time
import socket
import VatsTCPProtocol


MAX_RETRY = 100


class DataTimeoutException(Exception):
    pass


class VatsTCPChannel():
    def __init__(self, **params):
        self.enabled = True
        self.tcp = VatsTCPProtocol.VatsTCPProtocol()
        self.frame_size = self.tcp.get_framesize()
        self.timeout = self.tcp.TCP_TIMEOUT

        self.ip = None
        self.port = None

        self.ip = self.ip if "ip" not in params.keys() else params["ip"]
        self.ip = self.ip if "IP" not in params.keys() else params["IP"]
        self.port = self.port if "port" not in params.keys() else params["port"]
        self.port = self.port if "Port" not in params.keys() else params["Port"]
        if not self.ip or not self.port:
            self.enabled = False

    def open(self, **params):
        if self.enabled is False:
            self.ip = self.ip if "ip" not in params.keys() else params["ip"]
            self.ip = self.ip if "IP" not in params.keys() else params["IP"]
            self.port = self.port if "port" not in params.keys() else params["port"]
            self.port = self.port if "Port" not in params.keys() else params["Port"]
            if not self.ip or not self.port:
                print("Can't get IP or Port")
                return None
        # connect to the specified port
        retry = 0
        while retry < MAX_RETRY:
            try:
                conn = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                conn.settimeout(self.timeout)
                conn.connect((self.ip, int(self.port)))
                break
            except SystemExit:
                raise SystemExit
            except Exception:
                time.sleep(0.1)
                retry += 1
        else:
            print("Cannot connect to the port %d" % int(self.port))
            return None
        return conn

    def waitAvailable(self, timeout=180, **params):
        current_time = int(time.time())
        # disable logging since there will be many unable to connect errors
        print("Waiting for %s:%s available..." % (self.ip, self.port))
        self.logger.disable()
        while int(time.time()) < current_time + timeout:
            if self.open():
                # test if the channel is actually open
                if 'hello' != self.execute("echo hello"):
                    time.sleep(5)
                    continue
                self.logger.enable()
                print("%s Connected" % (self.ip))
                self.close()
                break
            else:
                time.sleep(5)
        else:
            print("Unable to wait for connection(%s:%d) available." % (self.ip, self.port))
            return False
        return True

    # conn.recv may return data less than desired bytes, so need to continues to wait for the left parts
    def receiveBytes(self, conn, length, data_timeout=0):
        rsize = length
        ret = bytes()
        timeout_left = data_timeout
        try:
            while rsize > 0 and timeout_left >= 0:
                try:
                    buf = conn.recv(rsize)
                except SystemExit:
                    raise SystemExit
                except socket.timeout:
                    # if timed out, continues to wait. This is for socket recv to exit immediately
                    if data_timeout > 0:
                        timeout_left -= self.timeout
                    continue
                if buf:
                    ret += buf
                    rsize -= len(buf)
                else:
                    break
        except SystemExit:
            raise SystemExit
        except Exception as e:
            print(e)
        # if timeout hit, throw an exception to stop data transfer immediately
        if timeout_left < 0:
            raise DataTimeoutException("Data transfer timeout hit!")
        return ret

    def receiveContent(self, conn, data_timeout=0):
        data = None
        data_len = 0
        try:
            buf = self.receiveBytes(conn, self.frame_size, data_timeout)
            if buf:
                frame = self.tcp.unpack(buf)
                if frame["tcp_cmd"] == self.tcp.TCP_CMD_CONTENT:
                    data_len = frame["content_len"]
                    if data_len > 0:
                        rsize = frame["content_len"]
                        data = self.receiveBytes(conn, rsize, data_timeout)
                else:
                    print("Get invalid cmd %d while receiving content, abort" % (frame["tcp_cmd"]))
        except SystemExit:
            raise SystemExit
        except DataTimeoutException as e:
            # deliver it to caller since it timed out
            raise e
        except Exception as e:
            print(e)
        return (data, data_len)

    def sendContent(self, conn, data_len, data=None):
        send_pack = self.tcp.pack(tcp_cmd=self.tcp.TCP_CMD_CONTENT, content_len=data_len)
        conn.send(send_pack)
        if data_len > 0:
            conn.send(data)

    def sendResult(self, conn, status, msg=None, buf=None):
        result_len = 0
        if buf:
            buf = buf.encode()
            result_len = len(buf)
        send_pack = self.tcp.pack(tcp_cmd=self.tcp.TCP_CMD_RESULT, result_len=result_len, result_msg=msg, result_status=status)
        conn.send(send_pack)
        if buf:
            to_send_byte = 0
            sent_byte = to_send_byte
            # if result is very long, send left content in MTU raw data
            while sent_byte < result_len:
                to_send_byte = min(sent_byte + self.tcp.TCP_MTU, result_len)
                send_buf = buf[sent_byte:to_send_byte]
                self.sendContent(conn, to_send_byte - sent_byte, send_buf)
                sent_byte = to_send_byte
            else:
                self.sendContent(conn, 0)

    def receiveResult(self, conn, data_timeout=0):
        frame = dict()
        result = bytes()
        received_len = 0

        try:
            buf = self.receiveBytes(conn, self.frame_size, data_timeout)
            if buf:
                frame = self.tcp.unpack(buf)
                if frame["tcp_cmd"] == self.tcp.TCP_CMD_RESULT:
                    # There is a content_len=0 after all pack received
                    while frame["result_len"] > 0 and received_len <= frame["result_len"]:
                        data, rsize = self.receiveContent(conn, data_timeout)
                        if data:
                            received_len += rsize
                            result += data
                        else:
                            break
                else:
                    print("Get invalid cmd %d while receiving content, abort" % (frame["tcp_cmd"]))
        except SystemExit:
            raise SystemExit
        except DataTimeoutException as e:
            # deliver it to caller for timeout issue
            raise e
        except Exception as e:
            print(e)
        return (frame, result.decode())

    def execute(self, cmd, **params):
        """
        cmd: the cmd to execute
        **powershell: if True, use powershell to run the cmd
        **timeout: timeout in seconds, raise TimeoutError
        if no result after this time
        """
        if self.enabled is False:
            return None
        conn = None
        ret = None

        data_timeout = 0
        if "data_timeout" in params.keys():
            data_timeout = params["data_timeout"]

        # if powershell is true, use powershell shell to run the command
        if "powershell" in params.keys() and params["powershell"] is True:
            parsed_cmd = cmd.translate(str.maketrans({"\"": r"\"", "\\": r"\\"}))
            cmd = f'powershell.exe "{parsed_cmd}"'

        try:
            conn = self.open()
            send_pack = self.tcp.pack(tcp_cmd=self.tcp.TCP_CMD_EXECUTE, exec_cmd=cmd)
            conn.send(send_pack)
            result, ret = self.receiveResult(conn, data_timeout)
            self.sendResult(conn, self.tcp.TCP_RESULT_OK)
        except SystemExit:
            raise SystemExit
        except Exception as e:
            print(e)
        if conn is not None:
            conn.close()
        else:
            print("Unexpected TCP behaviour. No connection to close. cmd '%s' failed." % cmd)
            return None
        if ret is not None:
            return ret.strip()
        else:
            print("Unexpected channel behaviour. Machine might be unresponsive or an exception occured. cmd '%s' failed." % cmd)
            return None

    def upload(self, src, dst, **params):
        if not os.path.exists(src):
            return None
        if os.path.isdir(src):
            path, dirname = os.path.split(src)
            for parent, dirnames, filenames in os.walk(src):
                for filename in filenames:
                    self.uploadFile(src=os.path.join(parent, filename), dst=dst + "/" + os.path.relpath(os.path.join(parent, filename), src))
        elif os.path.isfile(src):
            self.uploadFile(src=src, dst=dst)

    def uploadFile(self, src, dst, **params):
        ret = False
        fp = None
        if self.enabled is False:
            return ret
        try:
            src = os.path.normpath(src)
            if not os.path.isfile(src):
                return ret
            src_size = os.stat(src).st_size
            conn = self.open()
            send_pack = self.tcp.pack(tcp_cmd=self.tcp.TCP_CMD_UPLOAD, upload_path=dst, upload_size=src_size)
            conn.send(send_pack)
            result, buf = self.receiveResult(conn)
            if "result_status" not in result.keys() or result["result_status"] != self.tcp.TCP_RESULT_OK:
                print(result["result_msg"])
                conn.close()
                return ret
            fp = open(src, 'rb')
            rsize = 0
            sent_byte = rsize
            # if result is very long, send left content in MTU raw data
            while sent_byte < src_size:
                rsize = min(self.tcp.TCP_MTU, src_size-sent_byte)
                sdata = fp.read(rsize)
                self.sendContent(conn, rsize, sdata)
                sent_byte += rsize
            else:
                self.sendContent(conn, 0)
                result, buf = self.receiveResult(conn)
                if result["result_status"] != self.tcp.TCP_RESULT_OK:
                    print(result["result_msg"])
                else:
                    ret = True
            conn.close()
        except SystemExit:
            raise SystemExit
        except Exception as e:
            print(e)
        if fp is not None:
            fp.close()
        return ret

    def download(self, src, dst, **params):
        ret = False
        fp = None
        if self.enabled is False:
            return ret
        try:
            dst = os.path.normpath(dst)
            conn = self.open()
            send_pack = self.tcp.pack(tcp_cmd=self.tcp.TCP_CMD_DOWNLOAD, download_path=src)
            conn.send(send_pack)
            result, buf = self.receiveResult(conn)
            if result["result_status"] != self.tcp.TCP_RESULT_OK:
                print(result["result_msg"])
                return ret
            src_size = int(result["result_msg"])

            received_len = 0
            fp = open(dst, 'wb+')
            # There is a content_len=0 after all pack received
            while received_len <= src_size:
                data, rsize = self.receiveContent(conn)
                if data:
                    received_len += rsize
                    fp.write(data)
                else:
                    break
            self.sendResult(conn, self.tcp.TCP_RESULT_OK)
            conn.close()
        except SystemExit:
            raise SystemExit
        except Exception as e:
            print(e)
        if fp is not None:
            fp.close()
        return ret

    def close(self, **param):
        pass
