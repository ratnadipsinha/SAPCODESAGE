# Dockerfile — vLLM OpenAI-compatible server (required by SAP AI Core BYOM)
FROM vllm/vllm-openai:latest

# Copy merged model into the container image
COPY ./merged_model/ /model/

EXPOSE 8080

CMD ["python", "-m", "vllm.entrypoints.openai.api_server", \
     "--model",              "/model", \
     "--port",               "8080", \
     "--served-model-name",  "codesage-llama3", \
     "--max-model-len",      "8192", \
     "--dtype",              "bfloat16"]
