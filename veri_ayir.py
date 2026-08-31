import os

VERI_KLASORU = "veri"
TRAIN_DOSYASI = os.path.join(VERI_KLASORU, "train.jsonl")
VALID_DOSYASI = os.path.join(VERI_KLASORU, "valid.jsonl")
DOGRULAMA_SATIR_SAYISI = 100

with open(TRAIN_DOSYASI, "r", encoding="utf-8") as dosya:
    satirlar = dosya.readlines()

egitim_satirlari = satirlar[:-DOGRULAMA_SATIR_SAYISI]
dogrulama_satirlari = satirlar[-DOGRULAMA_SATIR_SAYISI:]

with open(TRAIN_DOSYASI, "w", encoding="utf-8") as dosya:
    dosya.writelines(egitim_satirlari)

with open(VALID_DOSYASI, "w", encoding="utf-8") as dosya:
    dosya.writelines(dogrulama_satirlari)
