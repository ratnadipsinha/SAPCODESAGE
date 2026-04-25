import chromadb
import requests, json
from chunker import chunk_abap
import pathlib

# ChromaDB client — persistent local store (on-premise, no cloud)
db = chromadb.PersistentClient(path='./chromadb_store')

COLLECTIONS = {
    'abap_programs':    db.get_or_create_collection('abap_programs'),
    'function_modules': db.get_or_create_collection('function_modules'),
    'abap_classes':     db.get_or_create_collection('abap_classes'),
    'documentation':    db.get_or_create_collection('documentation'),
}

def embed(text: str) -> list[float]:
    """Call local nomic-embed-text via Ollama (no cloud, no API key)."""
    r = requests.post('http://localhost:11434/api/embeddings',
                      json={'model': 'nomic-embed-text', 'prompt': text})
    return r.json()['embedding']   # 768-dimensional vector

def store_chunk(chunk, idx: int):
    col = COLLECTIONS[chunk.collection]
    vec = embed(chunk.text[:2000])  # embed first 2000 chars (fits context window)
    col.add(
        ids=[f'{chunk.object_name}_{idx}'],
        embeddings=[vec],
        documents=[chunk.text],
        metadatas=[{'object': chunk.object_name, 'type': chunk.chunk_type}])

# --- Main ---
abap_dir = pathlib.Path('../phase1_extract/abap_files')
for i, abap_file in enumerate(sorted(abap_dir.glob('*.abap'))):
    meta_file = abap_file.with_suffix('.json')
    meta = json.loads(meta_file.read_text()) if meta_file.exists() else {'name': abap_file.stem, 'type': 'PROG'}
    for j, chunk in enumerate(chunk_abap(abap_file, meta)):
        store_chunk(chunk, j)
    if i % 100 == 0:
        print(f'  Indexed {i} files...')

print('ChromaDB indexing complete.')
for name, col in COLLECTIONS.items():
    print(f'  {name}: {col.count()} chunks')
