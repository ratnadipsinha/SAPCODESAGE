import pathlib, json, re
from dataclasses import dataclass

@dataclass
class Chunk:
    text: str
    object_name: str
    chunk_type: str   # FORM | METHOD | FUNCTION | CLASS_DEF | BODY
    collection: str   # which ChromaDB collection this belongs to

FORM_RE     = re.compile(r'^FORM\s+(\w+)', re.M | re.I)
METHOD_RE   = re.compile(r'^\s*METHOD\s+(\w+)', re.M | re.I)
ENDFORM_RE  = re.compile(r'^ENDFORM', re.M | re.I)
ENDMETHOD_RE= re.compile(r'^\s*ENDMETHOD', re.M | re.I)

def chunk_abap(abap_path: pathlib.Path, meta: dict) -> list[Chunk]:
    src   = abap_path.read_text(encoding='utf-8')
    lines = src.splitlines()
    name  = meta['name']
    typ   = meta['type']     # PROG, FM, CLAS, etc.
    chunks = []

    if typ == 'FM':
        # Function module — whole file is one chunk
        collection = 'function_modules'
        chunks.append(Chunk(src, name, 'FUNCTION', collection))

    elif typ == 'CLAS':
        # Split on METHOD / ENDMETHOD boundaries
        collection = 'abap_classes'
        buf, mname = [], None
        for line in lines:
            m = METHOD_RE.match(line)
            if m:
                mname = m.group(1); buf = [line]
            elif ENDMETHOD_RE.match(line) and mname:
                buf.append(line)
                chunks.append(Chunk('\n'.join(buf), f'{name}.{mname}', 'METHOD', collection))
                mname = None; buf = []
            elif mname:
                buf.append(line)
        if not chunks:   # class definition only — add whole file
            chunks.append(Chunk(src, name, 'CLASS_DEF', collection))

    else:
        # Program — split on FORM / ENDFORM boundaries
        collection = 'abap_programs'
        buf, fname = [], None
        for line in lines:
            m = FORM_RE.match(line)
            if m:
                fname = m.group(1); buf = [line]
            elif ENDFORM_RE.match(line) and fname:
                buf.append(line)
                chunks.append(Chunk('\n'.join(buf), f'{name}.{fname}', 'FORM', collection))
                fname = None; buf = []
            elif fname:
                buf.append(line)
        # Add body (lines outside any FORM) as one chunk
        chunks.append(Chunk(src[:3000], name, 'BODY', collection))

    return [c for c in chunks if len(c.text.strip()) > 50]  # skip empty stubs

if __name__ == '__main__':
    abap_dir = pathlib.Path('../phase1_extract/abap_files')
    all_chunks = []
    for abap_file in abap_dir.glob('*.abap'):
        meta_file = abap_file.with_suffix('.json')
        meta = json.loads(meta_file.read_text()) if meta_file.exists() else {'name': abap_file.stem, 'type': 'PROG'}
        all_chunks.extend(chunk_abap(abap_file, meta))
    print(f'Total chunks: {len(all_chunks)}')
