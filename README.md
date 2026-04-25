# CodeSage for SAP

**AI-powered ABAP code knowledge platform** — find, understand, and generate custom ABAP code using a fine-tuned LLM trained on your organisation's own codebase.

> "Do we have a function module for vendor payment term validation?"
> → *Yes — `Z_VALIDATE_VENDOR_PAYTERMS` checks vendor payment terms against T052. Here is the relevant logic...*

---

## What It Does

SAP organisations accumulate thousands of custom ABAP objects over decades. Developers waste hours searching SE80, reading legacy code, and re-implementing logic that already exists. CodeSage fixes that.

Ask a plain-English question. Get a precise, cited answer — sourced directly from your organisation's own Z*/Y* codebase — in under 3 seconds.

---

## Architecture — 4 Phases

```
┌─────────────────────────────────────────────────────────────────┐
│  Phase 1          Phase 2          Phase 3          Phase 4     │
│  Scan & Extract → Index & Embed → Fine-Tune BYOM → Runtime BTP  │
│  pyrfc / RFC      ChromaDB         QLoRA LLaMA-3   SAP BTP CAP  │
│  Z*/Y* objects    nomic-embed      SAP AI Core      Fiori / API  │
└─────────────────────────────────────────────────────────────────┘
```

| Phase | What happens | Key technology |
|-------|-------------|----------------|
| 1 — Scan & Extract | Pulls all custom ABAP source code from SAP via RFC | pyrfc, RPY_PROGRAM_READ |
| 2 — Index & Embed | Chunks code by FORM/METHOD/FUNCTION, embeds into vector DB | ChromaDB, nomic-embed-text (Ollama) |
| 3 — Fine-Tune + BYOM | Trains LLaMA-3 8B on org-specific QA pairs, deploys to SAP AI Core | QLoRA, vLLM, SAP AI Core BYOM |
| 4 — Runtime (BTP) | CAP service answers queries using RAG + fine-tuned model | SAP BTP, CAP, XSUAA |

---

## Repository Structure

```
SAPCODESAGE/
├── code_artifacts/
│   ├── phase1_extract/
│   │   ├── scan_config.yaml          # SAP connection + namespace config
│   │   ├── extractor.py              # RFC extractor — pulls Z*/Y* objects
│   │   ├── test_connection.py        # Verify RFC connection
│   │   └── schedule_monthly.ps1      # Windows scheduled task (monthly refresh)
│   ├── phase2_index/
│   │   ├── chunker.py                # Splits ABAP into FORM/METHOD/FUNCTION chunks
│   │   ├── embedder.py               # Embeds chunks into ChromaDB via Ollama
│   │   ├── test_ollama.py            # Verify nomic-embed model is running
│   │   └── test_search.py            # Verify semantic search results
│   ├── phase3_finetune/
│   │   ├── generate_qa.py            # Generates QA training pairs via Claude API
│   │   ├── finetune_qlora.py         # QLoRA fine-tuning on Kaggle free GPU
│   │   ├── merge_lora.py             # Merges LoRA adapter into base model
│   │   ├── Dockerfile                # vLLM container for SAP AI Core BYOM
│   │   └── serving-template.yaml     # SAP AI Core serving template (GPU config)
│   └── phase4_btp/
│       ├── test_aicore.py            # Test SAP AI Core BYOM inference endpoint
│       └── test_live.py              # End-to-end test of live BTP CodeSage Agent
├── diagram_artifacts/
│   ├── CodeSage_BYOM_Architecture.drawio
│   ├── folder_structure_phase1.png
│   ├── folder_structure_phase2.png
│   ├── folder_structure_phase3.png
│   └── folder_structure_phase4.png
└── sample_codebase_artifacts/
    ├── abap_files/                   # 10 sample ABAP objects with JSON metadata
    └── fm_only/                      # Standalone function module samples
```

---

## Prerequisites

| Requirement | Phase | Notes |
|------------|-------|-------|
| SAP system with RFC access | 1 | Read-only RFC user `CODESAGE_RFC` |
| Python 3.10+ | 1–3 | Virtual environment recommended |
| pyrfc | 1 | Requires SAP NW RFC SDK |
| Ollama + nomic-embed-text | 2 | Free, runs locally |
| ChromaDB | 2 | Local persistent store |
| Anthropic API key | 3 | For QA pair generation |
| Kaggle account (free GPU) | 3 | For QLoRA fine-tuning |
| SAP BTP account | 3–4 | AI Core + Cloud Foundry |
| Docker | 3 | For building vLLM container |

---

## Quick Start

### Phase 1 — Extract ABAP Source Code

```bash
cd code_artifacts/phase1_extract
python -m venv codesage-env
.\codesage-env\Scripts\Activate.ps1
pip install pyrfc pyyaml

# Edit scan_config.yaml with your SAP connection details
# Set SAP_RFC_PASSWORD as an environment variable
python test_connection.py     # verify connection
python extractor.py           # extract all Z*/Y* objects
```

### Phase 2 — Index and Embed

```bash
cd code_artifacts/phase2_index
pip install chromadb requests

# Start Ollama and pull the embedding model
ollama pull nomic-embed-text

python test_ollama.py         # verify Ollama is running
python embedder.py            # chunk + embed all extracted ABAP
python test_search.py         # verify semantic search
```

### Phase 3 — Fine-Tune (Kaggle + SAP AI Core)

```bash
cd code_artifacts/phase3_finetune
pip install anthropic

export ANTHROPIC_API_KEY=sk-ant-...

python generate_qa.py         # generates training_data.jsonl
# Upload finetune_qlora.py to Kaggle notebook (free T4 GPU)
# After training, run merge_lora.py to merge adapter
# Build and push Docker image, then apply serving-template.yaml
```

### Phase 4 — Test Live Endpoint

```bash
cd code_artifacts/phase4_btp
python test_aicore.py         # test AI Core BYOM inference
python test_live.py           # end-to-end BTP agent test
```

---

## Sample Output

```
Question:  Do we have a function module for vendor payment term validation?

Answer:    Yes — Z_VALIDATE_VENDOR_PAYTERMS checks vendor payment terms
           against table T052. It accepts LIFNR (vendor number) and
           ZTERM (payment term key) as importing parameters and raises
           ZCX_BASE_ERROR if the term is not valid for the vendor.

Sources:   Z_VALIDATE_VENDOR_PAYTERMS  (FUNCTION)
           Z_VENDOR_MASTER_READ        (FUNCTION)

Latency:   2,841 ms
```

---

## Security Notes

- SAP RFC credentials are **never** stored in code — use environment variables or BTP Destination Service
- The extractor automatically redacts any credentials found in ABAP source before saving
- ChromaDB runs **on-premise** — no ABAP code leaves your network during indexing
- SAP AI Core BYOM keeps the fine-tuned model within your BTP subaccount

---

## Roadmap

- [ ] Teams / Slack bot integration
- [ ] ABAP code generation endpoint (Claude 4 with tool use)
- [ ] Automatic monthly refresh via SAP AI Core training pipeline
- [ ] Clean Core impact analysis — flag objects incompatible with SAP BTP ABAP

---

## Related

- Architecture diagrams: `diagram_artifacts/`
- SAP Community blog: [CodeSage for SAP — AI-Powered ABAP Knowledge](https://community.sap.com/t5/technology-blogs-by-members/codesage-for-sap-ai-powered-abap-knowledge/ba-p/14118544)

---

*Built by Ratnadip Sinha · SAP Architect & AI Engineer*
