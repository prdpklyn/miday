import os
import torch
import ai_edge_torch
from transformers import AutoModelForCausalLM


def main():
    model = AutoModelForCausalLM.from_pretrained("./functiongemma-myday-finetuned", torch_dtype=torch.float32)
    sample_input = torch.randint(0, 32000, (1, 512))
    edge_model = ai_edge_torch.convert(model, sample_args=(sample_input,))
    edge_model = ai_edge_torch.quantize(edge_model, quant_config=ai_edge_torch.QuantConfig.DYNAMIC_INT8)
    output_path = "./functiongemma-270m-finetuned.tflite"
    edge_model.export(output_path)
    size_mb = os.path.getsize(output_path) / 1024 / 1024
    print(f"Model size: {size_mb:.1f} MB")


if __name__ == "__main__":
    main()
