import pyrfc, json, pathlib, yaml, re

# Load config
cfg = yaml.safe_load(open('scan_config.yaml'))
out = pathlib.Path(cfg['output_dir'])
out.mkdir(exist_ok=True)

# Pre-scan filter: strip credentials before writing to disk
CRED_RE = re.compile(
    r'(password|passwd|pwd|secret|apikey)\s*=\s*[\'\"][^\'\"]+[\'\"]', re.I)

# Open read-only RFC connection
conn = pyrfc.Connection(
    ashost=cfg['sap']['host'],   sysnr=cfg['sap']['sysnr'],
    client=cfg['sap']['client'], user=cfg['sap']['user'],
    passwd=cfg['sap']['password'])

def save_object(name, obj_type, source, meta):
    source_clean = CRED_RE.sub('[REDACTED]', source)
    (out / f'{name}.abap').write_text(source_clean, encoding='utf-8')
    (out / f'{name}.json').write_text(json.dumps(meta, indent=2), encoding='utf-8')

# --- Extract Programs (PROG) ---
progs = conn.call('RPY_DIRECTORY_FINISH', OBJECT_TYPE='PROG', GENERIC_NAME='Z*')
for obj in progs['TADIR']:
    try:
        r = conn.call('RPY_PROGRAM_READ', PROG_NAME=obj['OBJ_NAME'])
        src = '\n'.join(l['LINE'] for l in r['SOURCE'])
        save_object(obj['OBJ_NAME'], 'PROG', src, {
            'name': obj['OBJ_NAME'], 'type': 'PROG',
            'package': obj.get('DEVCLASS',''), 'changed': obj.get('LDATE','')})
    except Exception as e:
        print(f'  SKIP {obj["OBJ_NAME"]}: {e}')

# --- Extract Function Modules (FUGR) ---
fugs = conn.call('RPY_DIRECTORY_FINISH', OBJECT_TYPE='FUGR', GENERIC_NAME='Z*')
for obj in fugs['TADIR']:
    try:
        r = conn.call('RPY_FUNCTIONMODULE_READ', FUNCNAME=obj['OBJ_NAME'])
        src = '\n'.join(l['LINE'] for l in r.get('SOURCE',[]))
        save_object(obj['OBJ_NAME'], 'FUGR', src, {
            'name': obj['OBJ_NAME'], 'type': 'FM',
            'package': obj.get('DEVCLASS',''), 'changed': obj.get('LDATE','')})
    except Exception as e:
        print(f'  SKIP {obj["OBJ_NAME"]}: {e}')

print(f'Done. {len(list(out.glob("*.abap")))} objects saved to {out}/')
