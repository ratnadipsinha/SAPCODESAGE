from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, TaskType
from trl import SFTTrainer
import torch

MODEL_ID = "meta-llama/Meta-Llama-3-8B-Instruct"

# Load base model in 4-bit NF4 quantisation (QLoRA)
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",          # NF4 = best quality at 4-bit
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True)     # double quantisation saves ~0.4 GB more

model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID, quantization_config=bnb_config, device_map="auto")
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

# Attach LoRA adapters — only these small matrices will be trained
lora_config = LoraConfig(
    r=16,                               # rank — controls adapter capacity
    lora_alpha=32,                      # scale factor
    target_modules=["q_proj","k_proj","v_proj","o_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type=TaskType.CAUSAL_LM)
model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# Output: trainable params: 13,631,488 || all params: 8,044,093,440 (0.17%)

# Train
trainer = SFTTrainer(
    model=model, tokenizer=tokenizer,
    train_dataset=dataset,              # loaded from training_data.jsonl
    dataset_text_field="text",
    max_seq_length=2048,
    args=TrainingArguments(
        output_dir="./lora-adapter",
        num_train_epochs=3,
        per_device_train_batch_size=4,
        gradient_accumulation_steps=4,
        learning_rate=2e-4,
        fp16=True,
        save_strategy="epoch",
        logging_steps=50))
trainer.train()
trainer.save_model("./lora-adapter")   # saves ~50 MB LoRA adapter
