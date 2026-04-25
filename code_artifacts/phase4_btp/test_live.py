import requests

# Step 1: Get an OAuth2 access token from XSUAA
#   Find these values in BTP Cockpit -> Instances -> codesage-xsuaa -> Service Keys
xsuaa_url     = "https://<your-subdomain>.authentication.<region>.hana.ondemand.com"
client_id     = "<xsuaa-client-id>"
client_secret = "<xsuaa-client-secret>"

token_resp = requests.post(
    f"{xsuaa_url}/oauth/token",
    data={"grant_type": "client_credentials"},
    auth=(client_id, client_secret))
token = token_resp.json()["access_token"]
print("Token obtained OK")

# Step 2: Call the live CodeSage Agent on BTP
agent_url = "https://codesage-agent-<id>.cfapps.<region>.hana.ondemand.com"

response = requests.post(
    f"{agent_url}/codesage/query",
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type":  "application/json"},
    json={"question": "Do we have a function module for vendor payment term validation?"})

print("HTTP Status:", response.status_code)
data = response.json()
print("Answer:",      data["answer"][:200])
print("Sources:",     data["sources"])
print("Latency ms:",  data["latency_ms"])
# Expected:
# HTTP Status: 200
# Answer: Yes — Z_VALIDATE_VENDOR_PAYTERMS checks vendor payment terms against T052...
# Sources: [{'object_name': 'Z_VALIDATE_VENDOR_PAYTERMS', 'chunk_type': 'FUNCTION'}]
# Latency ms: 2841
