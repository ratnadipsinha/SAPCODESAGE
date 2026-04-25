from docx import Document
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

doc = Document('CodeSage_Proposal.docx')

# Find the 'Code Listings' paragraph to insert before it
target_para = None
for para in doc.paragraphs:
    if 'Code Listings' in para.text and para.style.name == 'Heading 1':
        target_para = para
        break

if not target_para:
    print("ERROR: Could not find 'Code Listings' paragraph")
    exit(1)

def insert_para_before(target, style_name, text):
    new_para = OxmlElement('w:p')
    pPr = OxmlElement('w:pPr')
    pStyle = OxmlElement('w:pStyle')
    pStyle.set(qn('w:val'), style_name)
    pPr.append(pStyle)
    new_para.append(pPr)
    if text:
        r = OxmlElement('w:r')
        t = OxmlElement('w:t')
        t.set(qn('xml:space'), 'preserve')
        t.text = text
        r.append(t)
        new_para.append(r)
    target._element.addprevious(new_para)

def insert_table_before(target, headers, rows_data):
    tbl = OxmlElement('w:tbl')
    tblPr = OxmlElement('w:tblPr')
    tblStyle = OxmlElement('w:tblStyle')
    tblStyle.set(qn('w:val'), 'TableGrid')
    tblPr.append(tblStyle)
    tblW = OxmlElement('w:tblW')
    tblW.set(qn('w:w'), '5000')
    tblW.set(qn('w:type'), 'pct')
    tblPr.append(tblW)
    tbl.append(tblPr)

    def make_cell(text, bold=False):
        tc = OxmlElement('w:tc')
        p = OxmlElement('w:p')
        r = OxmlElement('w:r')
        if bold:
            rPr = OxmlElement('w:rPr')
            b = OxmlElement('w:b')
            rPr.append(b)
            r.append(rPr)
        t = OxmlElement('w:t')
        t.set(qn('xml:space'), 'preserve')
        t.text = text
        r.append(t)
        p.append(r)
        tc.append(p)
        return tc

    tr = OxmlElement('w:tr')
    for h in headers:
        tr.append(make_cell(h, bold=True))
    tbl.append(tr)

    for row in rows_data:
        tr = OxmlElement('w:tr')
        for cell in row:
            tr.append(make_cell(cell))
        tbl.append(tr)

    target._element.addprevious(tbl)

# Page break
pb_para = OxmlElement('w:p')
pb_r = OxmlElement('w:r')
pb_br = OxmlElement('w:br')
pb_br.set(qn('w:type'), 'page')
pb_r.append(pb_br)
pb_para.append(pb_r)
target_para._element.addprevious(pb_para)

# Chapter title
insert_para_before(target_para, 'Heading1', 'Alternative Deployment \u2014 SAP AI Core with BYOM')

# Overview
insert_para_before(target_para, 'Heading2', 'Overview')
insert_para_before(target_para, 'Normal',
    'SAP AI Core offers a Bring Your Own Model (BYOM) capability that allows organisations to deploy popular '
    'open-source LLMs \u2014 including LLaMA 3, Phi3, Mistral, and Mixtral \u2014 on SAP\u2019s managed cloud '
    'infrastructure. This chapter describes how CodeSage could be adapted to use this deployment model instead '
    'of the default fully on-premise Ollama approach, and what the trade-offs of that decision are.')

# Why not Joule
insert_para_before(target_para, 'Heading2', 'Why SAP Joule Cannot Replace CodeSage')
insert_para_before(target_para, 'Normal',
    'SAP Joule is trained on generic SAP knowledge \u2014 standard BAPIs, S/4HANA documentation, and SAP best '
    'practices. It has no awareness of your organisation\u2019s Z-programs, your naming conventions, your custom '
    'function modules, or how your team structures code. Joule cannot be fine-tuned on your codebase, it sends '
    'every query to SAP\u2019s cloud, and it carries ongoing per-user subscription costs. CodeSage addresses all '
    'three of these limitations. The BYOM approach described in this chapter retains the fine-tuning advantage '
    'while trading the fully offline model for SAP-managed cloud inference.')

# Model choices
insert_para_before(target_para, 'Heading2', 'Supported Model Choices for BYOM Fine-Tuning')
insert_para_before(target_para, 'Normal',
    'Instead of CodeLlama-7B-Instruct, the following SAP AI Core BYOM-supported models can be fine-tuned on '
    'your ABAP codebase using the identical QLoRA training pipeline described in Phase 3:')

insert_table_before(target_para,
    headers=['Model', 'Suitability for ABAP', 'Assessment'],
    rows_data=[
        ['LLaMA 3 (8B or 70B)', 'Best overall \u2014 strongest reasoning and code understanding', 'Recommended'],
        ['Mistral 7B', 'Good balance of speed and response quality', 'Good alternative'],
        ['Mixtral 8x7B', 'Most capable but requires more GPU memory during training', 'High capability'],
        ['Phi3', 'Smallest and fastest \u2014 weaker on complex ABAP logic', 'Lightweight option'],
    ]
)
insert_para_before(target_para, 'Normal', '')

# Pipeline changes
insert_para_before(target_para, 'Heading2', 'What Changes in the CodeSage Pipeline')

insert_para_before(target_para, 'Heading3', 'Phase 3 \u2014 Fine-Tuning (Model Swap Only)')
insert_para_before(target_para, 'Normal',
    'The training data generation pipeline remains identical \u2014 Claude API still generates ABAP Q&A pairs, '
    'and QLoRA still fine-tunes the model. The only change is the base model: replace CodeLlama-7B-Instruct '
    'with your chosen BYOM-supported model (LLaMA 3 recommended).')

insert_para_before(target_para, 'Heading3', 'Post-Training \u2014 Packaging for SAP AI Core')
insert_para_before(target_para, 'Normal',
    'After fine-tuning, two additional steps are required before the model can be deployed on SAP AI Core:')
insert_para_before(target_para, 'Normal',
    '1.  Merge the LoRA adapter into the base model weights to produce a single standalone model file.')
insert_para_before(target_para, 'Normal',
    '2.  Package the merged model into a Docker container using vLLM or Text Generation Inference (TGI) '
    'serving format, as required by SAP AI Core.')

insert_para_before(target_para, 'Heading3', 'Phase 4 \u2014 Runtime Query (Endpoint Change)')
insert_para_before(target_para, 'Normal',
    'The RAG pipeline (ChromaDB vector search) continues to run locally and unchanged. The only modification '
    'to Phase 4 is in inference.py: the Ollama local endpoint (localhost:11434) is replaced with the '
    'SAP AI Core API endpoint. Retrieved context and developer queries are sent to SAP AI Core for inference '
    'rather than to a local model server.')

# Trade-off analysis
insert_para_before(target_para, 'Heading2', 'Trade-Off Analysis')
insert_para_before(target_para, 'Normal',
    'The following table summarises what is gained and lost by moving from the default on-premise Ollama '
    'deployment to SAP AI Core BYOM:')

insert_table_before(target_para,
    headers=['Capability', 'On-Premise Ollama (Default)', 'SAP AI Core BYOM'],
    rows_data=[
        ['Code stays fully on-premise', 'Yes', 'No \u2014 queries go to SAP cloud'],
        ['Zero ongoing inference cost', 'Yes', 'No \u2014 SAP AI Core per-inference billing'],
        ['Fully offline operation', 'Yes', 'No'],
        ['Enterprise-grade scalability', 'Manual server setup required', 'SAP-managed infrastructure'],
        ['Native SAP BTP integration', 'Additional work required', 'Native'],
        ['Local GPU for inference', 'Required', 'Not required'],
        ['Multi-user deployment', 'Requires a central server', 'Built-in'],
        ['Setup complexity', 'Low (Ollama is simple)', 'Higher (Docker, vLLM packaging)'],
        ['Model quality', 'CodeLlama-7B (code-specialised)', 'LLaMA 3 / Mistral (stronger general + code)'],
    ]
)
insert_para_before(target_para, 'Normal', '')

# Recommendation
insert_para_before(target_para, 'Heading2', 'Recommendation')
insert_para_before(target_para, 'Normal',
    'The SAP AI Core BYOM approach is the right choice for organisations that are already committed to SAP BTP, '
    'have security policies that permit developer queries to flow to SAP\u2019s cloud infrastructure, and want '
    'enterprise-grade scalability without managing their own inference server.')
insert_para_before(target_para, 'Normal',
    'The default on-premise Ollama approach remains the correct choice for organisations where data sovereignty '
    'is a hard requirement \u2014 where no ABAP source code or query content can leave the organisation\u2019s '
    'own network under any circumstances.')
insert_para_before(target_para, 'Normal',
    'In both cases, the fine-tuning pipeline (Phases 1\u20133) is identical. The deployment target (Phase 4) '
    'is the only architectural decision point between the two approaches.')

doc.save('CodeSage_Proposal.docx')
print('Chapter added successfully.')
