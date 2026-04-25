import requests, json

r = requests.post("http://localhost:11434/api/embeddings",
                  json={"model": "nomic-embed-text", "prompt": "hello SAP"})
vec = r.json()["embedding"]
print(f"Embedding OK: {len(vec)} dimensions, first value = {vec[0]:.4f}")
# Expected: Embedding OK: 768 dimensions, first value = 0.0231
