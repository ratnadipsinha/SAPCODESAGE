from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel

print("Loading base model in full precision for merge...")
base = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Meta-Llama-3-8B-Instruct",
    torch_dtype="auto", device_map="cpu")   # CPU merge is fine — one-time op

tokenizer = AutoTokenizer.from_pretrained("meta-llama/Meta-Llama-3-8B-Instruct")

print("Applying LoRA adapter...")
model = PeftModel.from_pretrained(base, "./lora-adapter/")

print("Merging and unloading LoRA weights into base...")
merged = model.merge_and_unload()           # adapter deltas added into base weights

print("Saving merged model...")
merged.save_pretrained("./merged_model/")   # ~16 GB folder (full bf16 weights)
tokenizer.save_pretrained("./merged_model/")
print("Merge complete. ./merged_model/ is ready to package.")
