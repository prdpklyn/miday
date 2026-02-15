import json
import torch
from datasets import Dataset
from peft import LoraConfig, get_peft_model
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from trl import SFTTrainer


def load_examples(path):
    records = []
    with open(path, "r", encoding="utf-8") as file:
        for line in file:
            records.append(json.loads(line))
    return records


def format_example(example):
    return {
        "text": (
            "<|developer|>You are a model that can do function calling with the following functions</s>\n"
            f"<|user|>{example['input']}</s>\n"
            f"<|assistant|>{example['output']}</s>"
        )
    }


def main():
    model_id = "google/functiongemma-270m-it"
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    model = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype="bfloat16", device_map="auto")
    lora_config = LoraConfig(
        r=16,
        lora_alpha=32,
        lora_dropout=0.05,
        target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
        task_type="CAUSAL_LM",
    )
    model = get_peft_model(model, lora_config)
    examples = load_examples("training_data.jsonl")
    dataset = Dataset.from_list(examples).map(format_example)
    training_args = TrainingArguments(
        output_dir="./functiongemma-myday",
        num_train_epochs=3,
        per_device_train_batch_size=4,
        gradient_accumulation_steps=4,
        learning_rate=2e-4,
        warmup_steps=100,
        logging_steps=10,
        save_steps=100,
        bf16=True,
    )
    trainer = SFTTrainer(
        model=model,
        train_dataset=dataset,
        args=training_args,
        tokenizer=tokenizer,
        dataset_text_field="text",
        max_seq_length=512,
    )
    trainer.train()
    model.save_pretrained("./functiongemma-myday-finetuned")
    tokenizer.save_pretrained("./functiongemma-myday-finetuned")


if __name__ == "__main__":
    main()
