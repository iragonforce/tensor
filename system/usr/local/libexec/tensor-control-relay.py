#!/usr/bin/env python3

if __name__ == "__main__":
    import sys as _ops_sys
    if _ops_sys.argv[1:] == ["--help"]:
        print('Relay existing authorized desktop-control requests to the configured target.\nUsage: tensor-control-relay.py \n\nSource: hosts/tensor/files/usr/local/libexec/control-relay.py in ~/ops\nSee man tensor-control-relay.py for the existing call sites and argument handling.')
        raise SystemExit(0)
# Relay existing authorized desktop-control requests to the configured target. See tensor-control-relay.py(1) for source and integration details.
import select
import socket
import socketserver
class Relay(socketserver.BaseRequestHandler):
    def handle(self):
        try:
            with socket.create_connection(('192.168.1.3',8769),timeout=10,source_address=('127.0.0.1',0)) as backend:
                streams=[self.request,backend]
                while True:
                    ready,_,_=select.select(streams,[],[],90)
                    if not ready: return
                    for source in ready:
                        data=source.recv(65536)
                        if not data: return
                        (backend if source is self.request else self.request).sendall(data)
        except (OSError,TimeoutError):
            pass
class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address=True
    daemon_threads=True
with Server(('127.0.0.1',18769),Relay) as server:
    server.serve_forever()
