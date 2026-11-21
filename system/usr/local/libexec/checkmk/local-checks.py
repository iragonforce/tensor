#!/usr/bin/env python3
# Produce the existing host-specific Checkmk local checks. See local-checks.py(1) for source and integration details.
"""Checkmk local checks. Never render environment, tokens, prompts or command args."""

if __name__ == "__main__":
    import sys as _ops_sys
    if _ops_sys.argv[1:] == ["--help"]:
        print('Produce the existing host-specific Checkmk local checks.\nUsage: local-checks.py \n\nSource: hosts/tensor/files/usr/local/libexec/checkmk/local-checks.py in ~/ops\nSee man local-checks.py for the existing call sites and argument handling.')
        raise SystemExit(0)
import json,os,pathlib,shutil,subprocess,time
def run(args,timeout=15):
    try:return subprocess.run(args,capture_output=True,text=True,timeout=timeout)
    except (OSError,subprocess.TimeoutExpired):return None
def emit(state,name,metrics,text):print(f'{state} "{name}" {metrics or "-"} {text}')
host=os.uname().nodename.split('.')[0];home=pathlib.Path('/Users/iragonforce' if host=='qubit' else '/home/iragonforce')
ps=run(['ps','-ax','-o','comm=']);processes=ps.stdout.splitlines() if ps else []
codex_paths=[home/'.npm-global/bin/codex',pathlib.Path('/opt/homebrew/bin/codex'),home/'.local/bin/codex']
installed=bool(shutil.which('codex')) or any(p.exists() for p in codex_paths)
active=sum(1 for p in processes if pathlib.Path(p.strip()).name.lower()=='codex' or '/Codex.app/' in p)
newest=max((p.stat().st_mtime for p in (home/'.codex/sessions').rglob('*.jsonl')),default=0)
age=int(time.time()-newest) if newest else 0
emit(0,'AI Codex activity',f'processes={active}|session_age={age}s',f'installed={str(installed).lower()}, processes={active}; session metadata only, idle is normal')
if shutil.which('systemctl'):
    result=run(['systemctl','--failed','--no-legend','--plain']);failed=[l.split()[0] for l in result.stdout.splitlines() if l.strip()] if result else []
    emit(1 if failed else 0,'Systemd failed units',f'failed={len(failed)}',', '.join(failed) if failed else 'No failed system units')
if shutil.which('zpool'):
    result=run(['zpool','list','-H','-o','name,health,capacity'])
    if result and result.returncode==0:
        for l in result.stdout.splitlines():
            name,health,capacity=l.split();percent=int(capacity.strip('%'))
            emit(2 if health!='ONLINE' else (1 if percent>=80 else 0),'ZFS '+name,f'capacity={percent}%;80;90',f'{health}; capacity {percent}%')
if host=='nexus':
    names=run(['docker','ps','-aq']);containers=[]
    if names and names.returncode==0 and names.stdout.strip():
        result=run(['docker','inspect']+names.stdout.split(),25)
        if result and result.returncode==0:containers=json.loads(result.stdout)
    emit(0 if containers else 2,'Docker engine',f'containers={len(containers)}','Docker API available' if containers else 'Docker API unavailable or no containers')
    stats=run(['docker','stats','--no-stream','--format','{{json .}}'],25);usage={}
    if stats and stats.returncode==0:
        for line in stats.stdout.splitlines():
            try:
                d=json.loads(line);usage[d['Name']]=float(d['CPUPerc'].strip('%'))
            except (ValueError,KeyError):pass
    for c in containers:
        name=c['Name'].lstrip('/');s=c['State'];health=s.get('Health',{}).get('Status','not-defined');state=s['Status']
        code=2 if state!='running' or health=='unhealthy' else (1 if health=='starting' else 0)
        emit(code,'Docker '+name,f'cpu={usage.get(name,0)}%|restarts={c["RestartCount"]}|running={int(state=="running")}',f'state={state}, health={health}')
    root=pathlib.Path('/srv/containers/data/hermes/data');config=root/'config.yaml'
    try:
        auth=json.loads((root/'auth.json').read_text());pool=auth.get('credential_pool',{})
        providers=auth.get('providers',{});configured=bool(providers.get('openai-codex')) or bool(pool.get('openai-codex'))
        env=(root/'.env').read_text() if (root/'.env').exists() else ''
        configured=configured or any(l.startswith('OPENAI_API_KEY=') and l.split('=',1)[1].strip().strip('"\'') for l in env.splitlines())
        emit(0 if configured else 1,'AI Hermes OpenAI credentials','configured='+str(int(configured)), 'Credential material present; inference untested' if configured else 'Awaiting OpenAI API key or ChatGPT login; run hermes-login')
    except (OSError,ValueError):emit(1,'AI Hermes OpenAI credentials','configured=0','Awaiting OpenAI setup; run hermes-login')
