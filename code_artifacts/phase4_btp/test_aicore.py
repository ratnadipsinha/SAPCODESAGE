import requests, os

# Get a token using client credentials
token_url     = "https://<your-token-url>/oauth/token"
client_id     = "<your-client-id>"
client_secret = "<your-client-secret>"

token_resp = requests.post(token_url,
    data={"grant_type": "client_credentials"},
    auth=(client_id, client_secret))
token = token_resp.json()["access_token"]
print("Token OK")

# Call the inference endpoint
ai_core_url   = "https://<your-ai-core-url>"
deployment_id = "<your-deployment-id>"

response = requests.post(
    f"{ai_core_url}/v2/inference/deployments/{deployment_id}/chat/completions",
    headers={
        "Authorization":    f"Bearer {token}",
        "Content-Type":     "application/json",
        "AI-Resource-Group":"default"},
    json={
        "model":     "codesage-llama3",
        "messages":  [{"role": "user", "content": "What is ABAP?"}],
        "max_tokens": 200})

print("Status:", response.status_code)
print("Answer:", response.json()["choices"][0]["message"]["content"])
# Expected: Status: 200  Answer: ABAP stands for Advanced Business Application ...
