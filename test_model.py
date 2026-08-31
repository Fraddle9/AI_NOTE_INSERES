from mlx_lm import load, generate

model, tokenizer = load(
    "mlx-community/Meta-Llama-3-8B-Instruct-4bit",
    adapter_path="adapters"
)

prompt = """<|im_start|>system
Sen bir veri çıkarma asistanısın. Gelen metni analiz edip belirtilen JSON şemasında çıktı üretirsin.
<|im_end|>
<|im_start|>user
Bugün Gazi Üniversitesi ile kısa bir görüşme yaptık. PIRI_AI modülünü denemek istiyorlar. 10 Eylül 2026'da başlayıp 10 Ekim'de bitecekmiş. Eğitim online olsun dediler.
<|im_end|>
<|im_start|>assistant
"""

response = generate(model, tokenizer, prompt=prompt, max_tokens=300)
print(response)