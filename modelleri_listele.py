import os
from pathlib import Path

import google.generativeai as genai


def _env_yukle() -> None:
    dosya = Path(__file__).with_name(".env")
    if not dosya.exists():
        return
    for satir in dosya.read_text(encoding="utf-8").splitlines():
        satir = satir.strip()
        if not satir or satir.startswith("#") or "=" not in satir:
            continue
        anahtar, _, deger = satir.partition("=")
        os.environ.setdefault(anahtar.strip(), deger.strip().strip("\"'"))


_env_yukle()
_api_key = (os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY") or "").strip()
if not _api_key:
    raise SystemExit("GOOGLE_API_KEY veya GEMINI_API_KEY tanımlı değil.")
genai.configure(api_key=_api_key)

for m in genai.list_models():
    if "generateContent" in m.supported_generation_methods:
        print(m.name)
