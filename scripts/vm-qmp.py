#!/usr/bin/env python3
"""Send a diagnostic QMP command to the development VM's local socket."""
import json
import socket
import sys

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
    connection.settimeout(10)
    connection.connect("/tmp/wayfire-studio-qmp.sock")
    stream = connection.makefile("rwb")
    json.loads(stream.readline())
    for command in [{"execute": "qmp_capabilities"}, json.loads(sys.argv[1])]:
        stream.write(json.dumps(command).encode() + b"\n")
        stream.flush()
        while True:
            response = json.loads(stream.readline())
            if "return" in response or "error" in response:
                print(json.dumps(response))
                break
