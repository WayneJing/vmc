import struct
import json

PACK_STR_FRAME = "!ii1400s"


class VatsTCPProtocol:
    # TCP commands

    TCP_CMD_EXECUTE = 0
    TCP_CMD_UPLOAD = 1
    TCP_CMD_DOWNLOAD = 2
    TCP_CMD_RESULT = 3
    TCP_CMD_CONTENT = 4

    TCP_CMD_MAX = 5

    TCP_CMD_UNKNOWN = 255
    # Result status
    TCP_RESULT_OK = 0
    TCP_RESULT_FAIL = 1
    # TCP setting
    TCP_MTU = 1500
    TCP_TIMEOUT = 3600

    def __init__(self):
        pass

    def unpack_frame(self, buf):
        ret = dict()
        ret["tcp_cmd"], ret["tcp_len"], ret["buf"] = struct.unpack(PACK_STR_FRAME, buf)
        ret["buf"] = ret["buf"].decode().strip("\00")
        return ret

    def unpack_buf(self, buf):
        ret = json.loads(buf)
        return ret

    def unpack(self, cmdbuf):
        ret = dict()
        ret = self.unpack_frame(cmdbuf)

        if ret["tcp_cmd"] in range(0, 5):
            ret = dict(ret, **self.unpack_buf(ret["buf"]))
        else:
            ret["tcp_cmd"] = self.TCP_CMD_UNKNOWN
        return ret

    def pack_frame(self, tcp_cmd, tcp_len, buf, async_val=False):
        return struct.pack(PACK_STR_FRAME, tcp_cmd, tcp_len, buf)

    def pack_execution(self, **params):
        data = {
            "exec_cmd": params["exec_cmd"]
        }
        return json.dumps(data)

    def pack_uploadhead(self, **params):
        data = {
            "upload_path": params["upload_path"],
            "upload_size": params["upload_size"],
        }
        return json.dumps(data)

    def pack_downloadhead(self, **params):
        data = {
            "download_path": params["download_path"]
        }
        return json.dumps(data)

    def pack_result(self, **params):
        data = {
            "result_status": params["result_status"],
            "result_len": params["result_len"],
            "result_msg": params["result_msg"]
        }
        return json.dumps(data)

    def pack_content(self, **params):
        data = {
            "content_len": params["content_len"]
        }
        return json.dumps(data)

    def pack(self, **params):
        if params["tcp_cmd"] == self.TCP_CMD_EXECUTE:
            buf = self.pack_execution(**params)
        elif params["tcp_cmd"] == self.TCP_CMD_UPLOAD:
            buf = self.pack_uploadhead(**params)
        elif params["tcp_cmd"] == self.TCP_CMD_DOWNLOAD:
            buf = self.pack_downloadhead(**params)
        elif params["tcp_cmd"] == self.TCP_CMD_RESULT:
            buf = self.pack_result(**params)
        elif params["tcp_cmd"] == self.TCP_CMD_CONTENT:
            buf = self.pack_content(**params)
        else:
            params["tcp_cmd"] = self.TCP_CMD_UNKNOWN
            buf = ""
        buf = buf.encode()
        tcp_len = len(buf)
        package = self.pack_frame(params["tcp_cmd"], tcp_len, buf)
        return package

    def get_framesize(self):
        return struct.calcsize(PACK_STR_FRAME)
