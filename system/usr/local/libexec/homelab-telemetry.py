#!/usr/bin/env python3
# Collect existing host component telemetry for its configured monitoring consumer. See homelab-telemetry.py(1) for source and integration details.
"""Read hardware/Docker telemetry and publish MQTT discovery; no control commands."""

if __name__ == "__main__":
    import sys as _ops_sys
    if _ops_sys.argv[1:] == ["--help"]:
        print('Collect existing host component telemetry for its configured monitoring consumer.\nUsage: homelab-telemetry.py \n\nSource: hosts/tensor/files/usr/local/libexec/telemetry.py in ~/ops\nSee man homelab-telemetry.py for the existing call sites and argument handling.')
        raise SystemExit(0)
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import threading
import time
import urllib.request
import paho.mqtt.client as mqtt

HOST = os.uname().nodename.split('.')[0]
assert HOST in ['nexus', 'tensor']
ROOT = Path('/var/lib/homelab-telemetry')
ROOT.mkdir(mode=0o700, exist_ok=True)
STATE = ROOT / 'energy.json'
saved = json.loads(STATE.read_text()) if STATE.exists() else {}
energy = saved.get('energy', {'cpu': 0.0, 'gpu': 0.0})
expected = set(saved.get('expected_containers', []))
stop = threading.Event()
connected = threading.Event()
remote = {}
announced = set()
last_cpu = None
last_gpu = None
last_stat = None
last_time = None
topic = 'homelab/hosts/' + HOST
client = mqtt.Client(client_id='homelab-telemetry-' + HOST)
client.will_set(topic + '/availability', 'offline', qos=1, retain=True)
client.reconnect_delay_set(min_delay=1, max_delay=30)

def atomic(path, text, mode=0o600):
    tmp = path.with_name(path.name + '.new')
    tmp.write_text(text)
    tmp.chmod(mode)
    os.replace(tmp, path)

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        announced.clear()
        connected.set()
        client.publish(topic + '/availability', 'online', qos=1, retain=True)
        if HOST == 'nexus':
            client.subscribe('homelab/hosts/tensor/state')

def on_disconnect(client, userdata, rc):
    connected.clear()

def on_message(client, userdata, message):
    try:
        d = json.loads(message.payload)
        if isinstance(d, dict) and d.get('host') == 'tensor' and abs(time.time() - float(d['timestamp'])) < 120:
            remote['tensor'] = d
    except (ValueError, KeyError, TypeError):
        pass

client.on_connect = on_connect
client.on_disconnect = on_disconnect
client.on_message = on_message
client.connect_async('192.168.4.4', 1883, keepalive=30)
client.loop_start()

def discovery(kind, key, name, field=None, unit=None, cls=None, state_class=None, template=None):
    uid = 'homelab_' + HOST + '_' + key
    if uid in announced or not connected.is_set():
        return
    config = {'name': name, 'unique_id': uid, 'default_entity_id': kind + '.' + HOST + '_' + key,
              'state_topic': topic + '/state', 'availability_topic': topic + '/availability',
              'expire_after': 90,
              'device': {'identifiers': ['homelab_monitor_' + HOST], 'name': HOST.title() + ' Monitoring',
                         'manufacturer': 'Homelab', 'model': 'Hardware and Docker telemetry'}}
    if field:
        config['value_template'] = '{{ value_json.' + field + ' }}'
    if template:
        config['value_template'] = template
    if unit:
        config['unit_of_measurement'] = unit
    if cls:
        config['device_class'] = cls
    if state_class:
        config['state_class'] = state_class
    if kind == 'binary_sensor':
        config.update(payload_on='ON', payload_off='OFF')
    client.publish('homeassistant/' + kind + '/' + uid + '/config', json.dumps(config), qos=1, retain=True)
    announced.add(uid)

def read_cpu():
    for p in Path('/sys/class/powercap').glob('*'):
        try:
            if (p / 'name').read_text().strip().startswith('package'):
                return float((p / 'energy_uj').read_text()), float((p / 'max_energy_range_uj').read_text())
        except OSError:
            pass
    return None

def read_gpu():
    values = []
    for p in Path('/sys/class/hwmon').glob('*'):
        try:
            if (p / 'name').read_text().strip() == 'amdgpu':
                values.extend(float(f.read_text()) / 1e6 for f in p.glob('power*_average'))
        except OSError:
            pass
    if not values and HOST == 'tensor':
        r = subprocess.run(['nvidia-smi', '--query-gpu=power.draw', '--format=csv,noheader,nounits'], capture_output=True, text=True, timeout=5)
        for line in r.stdout.splitlines():
            try:
                values.append(float(line))
            except ValueError:
                pass
    return sum(values) if values else None

def docker_state():
    if not Path('/usr/bin/docker').exists():
        return {}
    r = subprocess.run(['docker', 'ps', '-a', '--format', '{{json .}}'], capture_output=True, text=True, timeout=8)
    if r.returncode:
        return {}
    rows = [json.loads(s) for s in r.stdout.splitlines() if s]
    current = {r['Names']: r for r in rows}
    expected.update(n for n, r in current.items() if r['State'] == 'running')
    metrics = {}
    r = subprocess.run(['docker', 'stats', '--no-stream', '--format', '{{json .}}'], capture_output=True, text=True, timeout=8)
    for line in r.stdout.splitlines():
        try:
            d = json.loads(line)
            metrics[d['Name']] = (float(d['CPUPerc'].rstrip('%')), float(d['MemPerc'].rstrip('%')))
        except (ValueError, KeyError):
            pass
    for name in sorted(expected):
        r = current.get(name, {})
        cpu, mem = metrics.get(name, (0.0, 0.0))
        running = r.get('State') == 'running'
        yield name, {'running': running, 'problem': not running or '(unhealthy)' in r.get('Status', ''),
                     'cpu_percent': cpu, 'memory_percent': mem}

def prom_write(data):
    if HOST != 'nexus':
        return
    all_hosts = {**remote, 'nexus': data}
    lines = []
    for host, d in all_hosts.items():
        active = time.time() - d.get('timestamp', 0) < 70
        lines.append(f'homelab_telemetry_active{{host="{host}"}} {int(active)}')
        lines.append(f'homelab_telemetry_sample_unixtime{{host="{host}"}} {d.get("timestamp", 0)}')
        for component in ['cpu', 'gpu', 'component']:
            for suffix, metric in [('power_w', 'homelab_hardware_power_watts'), ('energy_kwh', 'homelab_hardware_energy_kwh_total')]:
                value = d.get(component + '_' + suffix)
                if isinstance(value, (int, float)) and math.isfinite(value):
                    lines.append(f'{metric}{{host="{host}",component="{component}"}} {value}')
        for key in ['cpu_usage_percent', 'memory_usage_percent', 'docker_running_count', 'docker_problem_count']:
            if key in d:
                lines.append(f'homelab_{key}{{host="{host}"}} {d[key]}')
        for name, c in d.get('containers', {}).items():
            if not re.fullmatch('[A-Za-z0-9_.-]+', name):
                continue
            for key in ['running', 'problem', 'cpu_percent', 'memory_percent']:
                lines.append(f'homelab_container_{key}{{host="{host}",container={json.dumps(name)}}} {float(c[key])}')
    directory = Path('/srv/containers/data/node-exporter/textfile')
    if directory.is_dir():
        atomic(directory / 'homelab-telemetry.prom', '\n'.join(lines) + '\n', 0o644)

def announce(d):
    for component, label in [('cpu', 'CPU Package'), ('gpu', 'GPU'), ('component', 'Measured CPU and GPU')]:
        for suffix, unit, cls, state_class in [('power_w', 'W', 'power', 'measurement'), ('energy_kwh', 'kWh', 'energy', 'total_increasing')]:
            field = component + '_' + suffix
            if field in d:
                discovery('sensor', field, label + (' Power' if cls == 'power' else ' Energy'), field, unit, cls, state_class)
    for field, label, unit in [('cpu_usage_percent', 'CPU Usage', '%'), ('memory_usage_percent', 'Memory Usage', '%'),
                                ('docker_running_count', 'Docker Running Containers', None), ('docker_problem_count', 'Docker Problem Containers', None)]:
        if field in d:
            discovery('sensor', field, label, field, unit, state_class='measurement')
    discovery('binary_sensor', 'online', 'Online', template='ON', cls='connectivity')
    discovery('binary_sensor', 'docker_problem', 'Docker Problem', template="{{ 'ON' if value_json.docker_problem_count > 0 else 'OFF' }}", cls='problem')
    if 'grafana_available' in d:
        discovery('binary_sensor', 'grafana_available', 'Grafana Available', template="{{ 'ON' if value_json.grafana_available else 'OFF' }}", cls='connectivity')
    for name in d['containers']:
        slug = re.sub('[^a-z0-9_]', '_', name.lower())
        prefix = "value_json.containers['" + name + "']"
        for flag, label, cls in [('running', 'Running', 'running'), ('problem', 'Problem', 'problem')]:
            discovery('binary_sensor', 'docker_' + slug + '_' + flag, 'Docker ' + name + ' ' + label,
                      template="{{ 'ON' if " + prefix + '.' + flag + " else 'OFF' }}", cls=cls)
        for field, label in [('cpu_percent', 'CPU Usage'), ('memory_percent', 'Memory Usage')]:
            discovery('sensor', 'docker_' + slug + '_' + field, 'Docker ' + name + ' ' + label,
                      template='{{ ' + prefix + '.' + field + ' }}', unit='%', state_class='measurement')

def sample():
    global last_cpu, last_gpu, last_time, last_stat
    now = time.time()
    clock = time.monotonic()
    dt = clock - last_time if last_time else None
    d = {'host': HOST, 'timestamp': now}
    cpu = read_cpu()
    if cpu and last_cpu and dt and 0 < dt < 90:
        delta = cpu[0] - last_cpu[0]
        if delta < 0:
            delta += cpu[1]
        if 0 <= delta / 1e6 / dt < 1000:
            d['cpu_power_w'] = round(delta / 1e6 / dt, 3)
            energy['cpu'] += delta / 3.6e12
    gpu = read_gpu()
    if gpu is not None:
        d['gpu_power_w'] = round(gpu, 3)
        if dt and 0 < dt < 90 and last_gpu is not None:
            energy['gpu'] += (gpu + last_gpu) / 2 * dt / 3.6e6
    last_cpu, last_gpu, last_time = cpu, gpu, clock
    if 'cpu_power_w' in d and 'gpu_power_w' in d:
        d['component_power_w'] = round(d['cpu_power_w'] + d['gpu_power_w'], 3)
    d.update(cpu_energy_kwh=energy['cpu'], gpu_energy_kwh=energy['gpu'], component_energy_kwh=sum(energy.values()))
    counts = list(map(int, Path('/proc/stat').read_text().splitlines()[0].split()[1:]))
    total, idle = sum(counts), counts[3] + counts[4]
    if last_stat and total > last_stat[0]:
        d['cpu_usage_percent'] = round(100 * (1 - (idle - last_stat[1]) / (total - last_stat[0])), 2)
    last_stat = total, idle
    mem = {l.split(':')[0]: int(l.split()[1]) for l in Path('/proc/meminfo').read_text().splitlines() if l.startswith(('MemTotal:', 'MemAvailable:'))}
    d['memory_usage_percent'] = round(100 * (1 - mem['MemAvailable'] / mem['MemTotal']), 2)
    d['containers'] = dict(docker_state())
    d['docker_running_count'] = sum(c['running'] for c in d['containers'].values())
    d['docker_problem_count'] = sum(c['problem'] for c in d['containers'].values())
    if HOST == 'nexus':
        try:
            with urllib.request.urlopen('http://172.16.11.42:30037/api/health', timeout=3) as f:
                d['grafana_available'] = f.status == 200 and json.load(f).get('database') == 'ok'
        except Exception:
            d['grafana_available'] = False
    atomic(STATE, json.dumps({'energy': energy, 'expected_containers': sorted(expected)}) + '\n')
    atomic(ROOT / 'latest.json', json.dumps(d) + '\n')
    announce(d)
    if connected.is_set():
        client.publish(topic + '/availability', 'online', retain=True)
        client.publish(topic + '/state', json.dumps(d), qos=1, retain=True)
    prom_write(d)

signal.signal(signal.SIGTERM, lambda *args: stop.set())
signal.signal(signal.SIGINT, lambda *args: stop.set())
try:
    while not stop.is_set():
        try:
            sample()
        except Exception as exc:
            print('Telemetry sample failed: ' + type(exc).__name__, flush=True)
        stop.wait(15)
finally:
    if connected.is_set():
        client.publish(topic + '/availability', 'offline', qos=1, retain=True).wait_for_publish(timeout=2)
    client.disconnect()
    client.loop_stop()
