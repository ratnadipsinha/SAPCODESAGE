from PIL import Image, ImageDraw, ImageFont

W, H = 900, 620
img = Image.new('RGB', (W, H), '#FAFAFA')
draw = ImageDraw.Draw(img)

try:
    font_title  = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 22)
    font_head   = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 13)
    font_file   = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 12)
    font_small  = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 11)
except:
    font_title = font_head = font_file = font_small = ImageFont.load_default()

BLUE       = '#0A66C2'
DARK_BLUE  = '#004B8A'
GREEN      = '#1B7A1B'
PURPLE     = '#6A1B9A'
ORANGE     = '#E65100'
GREY_BG    = '#F0F4FF'
BORDER     = '#D0D8F0'
TEXT_DARK  = '#1A1A1A'
TEXT_GREY  = '#555555'
WHITE      = '#FFFFFF'

# Title
draw.text((W//2, 28), 'CodeSage for SAP — Code Artifacts', fill=BLUE, font=font_title, anchor='mm')
draw.text((W//2, 54), 'Extracted from CodeSage_modified.docx  ·  Ready to run', fill=TEXT_GREY, font=font_small, anchor='mm')
draw.line([(40, 68), (W-40, 68)], fill=BORDER, width=1)

phases = [
    {
        'label': 'Phase 1 — Scan & Extract',
        'color': BLUE,
        'files': [
            ('scan_config.yaml',     'SAP connection config — host, user, namespaces'),
            ('extractor.py',         'RFC extractor — pulls all Z*/Y* ABAP objects'),
            ('test_connection.py',   'Verify RFC connection before running extractor'),
            ('schedule_monthly.ps1', 'Windows scheduled task — runs monthly at 2 AM'),
        ]
    },
    {
        'label': 'Phase 2 — Index & Embed',
        'color': GREEN,
        'files': [
            ('chunker.py',     'Splits ABAP into FORM / METHOD / FUNCTION chunks'),
            ('embedder.py',    'Embeds chunks into ChromaDB via nomic-embed-text'),
            ('test_ollama.py', 'Verify nomic-embed model is running via Ollama'),
            ('test_search.py', 'Verify semantic search returns correct results'),
        ]
    },
    {
        'label': 'Phase 3 — Fine-Tune + BYOM',
        'color': PURPLE,
        'files': [
            ('generate_qa.py',        'Generate QA pairs from ABAP via Claude API'),
            ('finetune_qlora.py',     'QLoRA fine-tuning of LLaMA-3 on Kaggle GPU'),
            ('merge_lora.py',         'Merge LoRA adapter into base model weights'),
            ('Dockerfile',            'vLLM container for SAP AI Core BYOM deploy'),
            ('serving-template.yaml', 'SAP AI Core serving template — GPU config'),
        ]
    },
    {
        'label': 'Phase 4 — Runtime (SAP BTP)',
        'color': ORANGE,
        'files': [
            ('test_aicore.py', 'Test SAP AI Core BYOM inference endpoint'),
            ('test_live.py',   'End-to-end test of live BTP CodeSage Agent'),
        ]
    },
]

COL_W = (W - 60) // 2
ROW_H = 230
PAD   = 14

positions = [
    (30,  80),
    (30 + COL_W + 10, 80),
    (30,  80 + ROW_H + 10),
    (30 + COL_W + 10, 80 + ROW_H + 10),
]

for phase, (px, py) in zip(phases, positions):
    col   = phase['color']
    files = phase['files']
    box_h = 38 + len(files) * 34 + PAD

    # Card background
    draw.rounded_rectangle([px, py, px+COL_W, py+box_h], radius=8, fill=WHITE, outline=col, width=2)

    # Header bar
    draw.rounded_rectangle([px, py, px+COL_W, py+30], radius=8, fill=col)
    draw.rectangle([px, py+16, px+COL_W, py+30], fill=col)
    draw.text((px+12, py+15), phase['label'], fill=WHITE, font=font_head, anchor='lm')

    # Files
    for i, (fname, desc) in enumerate(files):
        fy = py + 38 + i * 34
        # File row background (alternating)
        if i % 2 == 0:
            draw.rectangle([px+6, fy-2, px+COL_W-6, fy+28], fill='#F5F8FF')
        # File icon + name
        draw.text((px+14, fy+6), '📄', fill=col, font=font_file)
        draw.text((px+36, fy+4), fname, fill=col, font=font_head)
        draw.text((px+36, fy+18), desc, fill=TEXT_GREY, font=font_small)

# Footer
footer_y = H - 32
draw.line([(40, footer_y-8), (W-40, footer_y-8)], fill=BORDER, width=1)
draw.text((W//2, footer_y+4), '15 files  ·  4 phases  ·  All code extracted from CodeSage_modified.docx',
          fill=TEXT_GREY, font=font_small, anchor='mm')

img.save('code_structure.png', dpi=(150, 150))
print('done')
