import chromadb, requests

def embed(text):
    r = requests.post("http://localhost:11434/api/embeddings",
                      json={"model": "nomic-embed-text", "prompt": text})
    return r.json()["embedding"]

db  = chromadb.PersistentClient(path="./chromadb_store")
col = db.get_collection("function_modules")
print(f"function_modules: {col.count()} chunks indexed")

# Semantic search test
results = col.query(
    query_embeddings=[embed("validate vendor payment terms")],
    n_results=3)

print("\nTop 3 matches for 'validate vendor payment terms':")
for doc_text, meta in zip(results["documents"][0], results["metadatas"][0]):
    print(f"  [{meta['object']}]  {doc_text[:80]}...")
