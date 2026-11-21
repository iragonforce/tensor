#!/usr/bin/env python3
# Serve the existing host-control endpoint using its configured private authentication. See control-server.py(1) for source and integration details.
"""Authenticated, fixed-action REST controls. No arbitrary command execution."""

if __name__ == "__main__":
    import sys as _ops_sys
    if _ops_sys.argv[1:] == ["--help"]:
        print('Serve the existing host-control endpoint using its configured private authentication.\nUsage: control-server.py \n\nSource: hosts/tensor/files/usr/local/lib/tensor-control/control-server.py in ~/ops\nSee man control-server.py for the existing call sites and argument handling.')
        raise SystemExit(0)
import hmac,http.server,json,os,pathlib,socket,subprocess,sys
C=json.loads((pathlib.Path(os.environ['CREDENTIALS_DIRECTORY'])/'control.json').read_text())
BASE=pathlib.Path('/home/iragonforce/.local/share/tensor-control')
def call(args):
    r=subprocess.run(args,capture_output=True,text=True,timeout=30)
    if r.returncode:raise RuntimeError('Control action failed; check service journal')
    return r.stdout
def state(kind):
    if kind=='power':
        try:
            with socket.create_connection(('192.168.1.3',22),timeout=2):return 'ON'
        except OSError:return 'OFF'
    if kind=='rgb':
        p=pathlib.Path('/home/iragonforce/.local/state/tensor-control/rgb-state.json')
        return json.loads(p.read_text()).get('state','OFF') if p.exists() else 'OFF'
    if kind=='fans':
        import urllib.request
        d=json.load(urllib.request.urlopen('http://127.0.0.1:27003/api/devices/',timeout=5))
        profiles=[]
        for v in d.get('devices',{}).values():
            x=v.get('GetDevice',{})
            if not isinstance(x,dict) or not x.get('userProfiles'):continue
            default=x['userProfiles']['default']
            for key,ch in x.get('devices',{}).items():
                label=default.get('Labels',{}).get(key,ch.get('label',''))
                protected=ch.get('description')=='AIO' or 'AIO' in label.upper() or default.get('SpeedProfiles',{}).get(key,'').lower()=='aio'
                if ch.get('HasSpeed') and not protected:profiles.append(ch.get('profile'))
        return 'ON' if profiles and all(p=='Off' for p in profiles) else 'OFF'
    if kind=='monitors':
        import importlib.util
        spec=importlib.util.spec_from_file_location('desktop',BASE/'tensor-desktop.py');d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
        return 'ON' if any(m.get('dpmsStatus') for m in json.loads(d.hypr('-j','monitors'))) else 'OFF'
    raise ValueError('Unknown control')
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,fmt,*args):pass
    def do_GET(self):self.handle_request(False)
    def do_POST(self):self.handle_request(True)
    def handle_request(self,mutate):
        if self.client_address[0] not in ['192.168.4.2','192.168.1.2','192.168.1.4','127.0.0.1','192.168.4.254']:self.send_error(403);return
        if not hmac.compare_digest(self.headers.get('Authorization',''),'Bearer '+C['token']):self.send_error(401);return
        kind=self.path.removeprefix('/state/')
        allowed=['power'] if C['role']=='nexus' else ['rgb','fans','monitors']
        if not self.path.startswith('/state/') or kind not in allowed:self.send_error(404);return
        try:
            if mutate:
                size=int(self.headers.get('Content-Length','0'))
                if not 0<size<=256:raise ValueError('Invalid body length')
                data=json.loads(self.rfile.read(size));value=data.get('state')
                if value not in ['ON','OFF']:raise ValueError('Invalid state')
                if kind=='power':call(['/usr/local/bin/tensor','on' if value=='ON' else 'off'])
                elif kind=='rgb':
                    color=data.get('rgb')
                    if color is not None:
                        if not isinstance(color,list) or len(color)!=3 or any(type(v)!=int or not 0<=v<=255 for v in color):raise ValueError('Invalid RGB')
                        args=['color',*[str(v) for v in color]] if value=='ON' else ['off']
                    else:args=['on' if value=='ON' else 'off']
                    call([str(BASE/'venv/bin/python'),str(BASE/'tensor-rgb.py'),*args])
                elif kind=='fans':call([str(BASE/'venv/bin/python'),str(BASE/'tensor-rgb.py'),'fans-off' if value=='ON' else 'fans-on'])
                elif kind=='monitors':call(['/home/iragonforce/.local/bin/monitors','on' if value=='ON' else 'off'])
            body=json.dumps({'state':state(kind)}).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
        except Exception as e:
            print('Control error:',type(e).__name__,flush=True);self.send_error(503,'Control unavailable')
http.server.HTTPServer((C['bind'],8769),Handler).serve_forever()
