import json
import random
from datetime import timedelta
from faker import Faker

fake = Faker("tr_TR")

SATIR_SAYISI = 1000
DOSYA_ADI = "sentetik_egitim_verisi.jsonl"

KURUM_TURLERI = ["UNIVERSITE", "KURUM", "OZEL"]
URUN_KODLARI = ["PIRI", "PIRI_AI", "CHATBOT"]
EGITIM_TURLERI = ["ONLINE", "YUZYUZE", "BELIRSIZ"]
DURUMLAR = ["OLUMLU", "BEKLEMEDE", "OLUMSUZ", "TALEP_EDILMEDI"]

AY_ADLARI = [
    "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
    "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
]

URUN_ADLARI = {
    "PIRI": "Piri Keşif Aracı",
    "PIRI_AI": "Piri AI",
    "CHATBOT": "Chatbot",
}

DURUM_IFADELERI = {
    "OLUMLU": [
        "olumlu bir dönüş aldık",
        "teklifi kabul etti",
        "işbirliğine sıcak baktılar",
        "anlaşma sağlandı",
        "olumlu yanıt verdi",
    ],
    "BEKLEMEDE": [
        "henüz kesin bir karar vermedi",
        "yanıtı bekleniyor",
        "değerlendirme sürecinde",
        "netleşmiş bir cevap yok",
        "kararını bekliyoruz",
    ],
    "OLUMSUZ": [
        "olumsuz yanıt verdi",
        "teklifi reddetti",
        "ilgilenmediğini belirtti",
        "görüşme sonuçsuz kaldı",
    ],
    "TALEP_EDILMEDI": [
        "herhangi bir talepte bulunmadı",
        "eğitim talep etmedi",
        "konuyla ilgilenmediğini iletti",
        "şu ana kadar bir talep gelmedi",
    ],
}

DURUM_OZET = {
    "OLUMLU": "olumlu",
    "BEKLEMEDE": "beklemede",
    "OLUMSUZ": "olumsuz",
    "TALEP_EDILMEDI": "talep edilmedi",
}

EGITIM_IFADELERI = {
    "ONLINE": ["online olarak", "çevrimiçi şekilde", "uzaktan eğitim formatında"],
    "YUZYUZE": ["yüz yüze", "kampüste bizzat", "fiziksel ortamda"],
    "BELIRSIZ": [
        "hangi formatta olacağını netleştirmeden",
        "format konusunda karar vermeden",
        "online mı yüz yüze mi olacağını belirtmeden",
    ],
}

EGITIM_OZET = {
    "ONLINE": "online",
    "YUZYUZE": "yüz yüze",
    "BELIRSIZ": "belirsiz",
}

SISTEM_MESAJLARI = [
    "Sen bir CRM görüşme notu analiz asistanısın. Sana verilen ham görüşme metnini analiz ederek kurum_adi, kurum_türü, urun_kodu, baslangic_tarihi, bitis_tarihi, egitim_turu, durum ve not_icerigi alanlarını içeren geçerli bir JSON üret. Metinde yer almayan tarih ve ürün bilgisi için null, egitim_turu için BELIRSIZ, durum için TALEP_EDILMEDI değerini kullan.",
    "Rolün, eğitim kurumlarıyla yapılan görüşme kayıtlarını yapılandırılmış veriye dönüştürmek. Verilen metni oku ve kurum_adi, kurum_türü (UNIVERSITE, KURUM, OZEL), urun_kodu (PIRI, PIRI_AI, CHATBOT), urun_adi, baslangic_tarihi, bitis_tarihi, egitim_turu (ONLINE, YUZYUZE, BELIRSIZ), durum (OLUMLU, BEKLEMEDE, OLUMSUZ, TALEP_EDILMEDI) ve not_icerigi alanlarını içeren bir JSON nesnesi döndür. Piri AI ile Piri Keşif Aracı tamamen farklı ürünlerdir; birbirine çevirme.",
    "Sen bir veri çıkarım asistanısın. Kullanıcının paylaştığı ham görüşme metnini incele ve belirtilen şemaya uygun JSON üret: kurum_adi, kurum_türü, urun_kodu, baslangic_tarihi, bitis_tarihi, egitim_turu, durum, not_icerigi. Metinde geçmeyen bilgiler için uygun boş ya da belirsiz değerleri kullan.",
]


def tarih_metni(tarih):
    return f"{tarih.day} {AY_ADLARI[tarih.month - 1]} {tarih.year}"


def rastgele_tarih_araligi():
    baslangic = fake.date_between(start_date="-2y", end_date="+8M")
    sure_gun = random.randint(10, 300)
    bitis = baslangic + timedelta(days=sure_gun)
    return baslangic, bitis


def kurum_adi_uret(kurum_turu):
    if kurum_turu == "UNIVERSITE":
        return random.choice([
            f"{fake.city()} Üniversitesi",
            f"{fake.last_name()} Üniversitesi",
            f"{fake.city()} Teknik Üniversitesi",
        ])
    if kurum_turu == "KURUM":
        return random.choice([
            f"{fake.city()} İl Milli Eğitim Müdürlüğü",
            f"{fake.city()} Halk Eğitim Merkezi",
            f"{fake.city()} Bilim ve Teknoloji Merkezi",
            f"{fake.city()} Gençlik ve Spor İl Müdürlüğü",
        ])
    return random.choice([
        f"{fake.company()} A.Ş.",
        f"{fake.company()} Koleji",
        f"{fake.company()} Eğitim Kurumları",
        f"{fake.last_name()} Özel Okulları",
    ])


def sablon_1(ctx):
    metin = (
        f"{ctx['kurum_adi']} ile yaptığımız görüşmede {ctx['urun_adi']} eğitiminin "
        f"{ctx['baslangic_metin']} tarihinde başlayıp {ctx['bitis_metin']} tarihinde biteceği, "
        f"{ctx['egitim_ifade']} işleneceği konuşuldu, kurum {ctx['durum_ifade']}."
    )
    return metin, {"urun_kodu", "baslangic_tarihi", "bitis_tarihi", "egitim_turu", "durum"}


def sablon_2(ctx):
    metin = (
        f"{ctx['kurum_adi']} yetkilisiyle telefonda konuştuk, {ctx['urun_adi']} için "
        f"{ctx['baslangic_metin']} ile {ctx['bitis_metin']} tarihleri arasında {ctx['egitim_ifade']} "
        f"bir program istiyorlar, kendileri {ctx['durum_ifade']}."
    )
    return metin, {"urun_kodu", "baslangic_tarihi", "bitis_tarihi", "egitim_turu", "durum"}


def sablon_3(ctx):
    metin = (
        f"Görüşme özeti: {ctx['kurum_adi']}, {ctx['urun_adi']} ürünümüze {ctx['baslangic_metin']} "
        f"tarihinde başlamak istiyor, {ctx['bitis_metin']} tarihinde tamamlanması öngörülüyor, "
        f"eğitim {ctx['egitim_ifade']} verilecek, sonuç olarak {ctx['durum_ifade']}."
    )
    return metin, {"urun_kodu", "baslangic_tarihi", "bitis_tarihi", "egitim_turu", "durum"}


def sablon_4(ctx):
    metin = (
        f"Aradı bugün {ctx['kurum_adi']} yetkilisi, {ctx['urun_adi']} eğitimini {ctx['egitim_ifade']} "
        f"almak istediklerini, {ctx['baslangic_metin']} ile {ctx['bitis_metin']} arasında "
        f"planladıklarını söyledi, {ctx['durum_ifade']} kendileri."
    )
    return metin, {"urun_kodu", "baslangic_tarihi", "bitis_tarihi", "egitim_turu", "durum"}


def sablon_5(ctx):
    metin = (
        f"Görüştük {ctx['kurum_adi']} ile, {ctx['baslangic_metin']} tarihinde başlaması planlanan "
        f"{ctx['urun_adi']} eğitimi için, {ctx['bitis_metin']} tarihinde bitecek, "
        f"{ctx['egitim_ifade']} yapılacak, {ctx['durum_ifade']} açıkçası."
    )
    return metin, {"urun_kodu", "baslangic_tarihi", "bitis_tarihi", "egitim_turu", "durum"}


def sablon_6(ctx):
    metin = (
        f"{ctx['kurum_adi']} ile konuştuk, {ctx['urun_adi']} eğitimine {ctx['baslangic_metin']} "
        f"tarihinde başlamak istiyorlar, {ctx['egitim_ifade']} olacak, {ctx['durum_ifade']}."
    )
    return metin, {"urun_kodu", "baslangic_tarihi", "egitim_turu", "durum"}


def sablon_7(ctx):
    metin = (
        f"{ctx['kurum_adi']} yetkilisi aradı, {ctx['urun_adi']} eğitiminin {ctx['bitis_metin']} "
        f"tarihine kadar tamamlanmasını istiyorlar, {ctx['egitim_ifade']} düşünüyorlar, "
        f"{ctx['durum_ifade']}."
    )
    return metin, {"urun_kodu", "bitis_tarihi", "egitim_turu", "durum"}


def sablon_8(ctx):
    metin = (
        f"{ctx['kurum_adi']} ile görüşüldü, {ctx['urun_adi']} eğitimi {ctx['egitim_ifade']} "
        f"verilecek, kurum {ctx['durum_ifade']}, tarih henüz netleşmedi."
    )
    return metin, {"urun_kodu", "egitim_turu", "durum"}


def sablon_9(ctx):
    metin = (
        f"{ctx['kurum_adi']} yetkilisiyle görüştük, {ctx['baslangic_metin']} tarihinde başlayıp "
        f"{ctx['bitis_metin']} tarihinde bitecek bir eğitim istiyorlar, {ctx['egitim_ifade']} "
        f"olacak şekilde, {ctx['durum_ifade']}."
    )
    return metin, {"baslangic_tarihi", "bitis_tarihi", "egitim_turu", "durum"}


def sablon_10(ctx):
    metin = (
        f"{ctx['kurum_adi']} ile {ctx['urun_adi']} konusunda konuşuldu, {ctx['baslangic_metin']} "
        f"ile {ctx['bitis_metin']} arasında yapılması planlanıyor, {ctx['durum_ifade']}."
    )
    return metin, {"urun_kodu", "baslangic_tarihi", "bitis_tarihi", "durum"}


def sablon_11(ctx):
    metin = (
        f"{ctx['kurum_adi']} yetkilisi {ctx['urun_adi']} eğitimini {ctx['baslangic_metin']} ile "
        f"{ctx['bitis_metin']} tarihleri arasında {ctx['egitim_ifade']} almak istediklerini iletti."
    )
    return metin, {"urun_kodu", "baslangic_tarihi", "bitis_tarihi", "egitim_turu"}


def sablon_12(ctx):
    metin = f"{ctx['kurum_adi']} arandı, {ctx['durum_ifade']}, detaylar netleşmedi."
    return metin, {"durum"}


def sablon_13(ctx):
    metin = f"{ctx['kurum_adi']} yetkilisi {ctx['urun_adi']} hakkında bilgi istedi, başka bir şey konuşulmadı."
    return metin, {"urun_kodu"}


def sablon_14(ctx):
    metin = (
        f"Söylediler {ctx['kurum_adi']} yetkilileri, {ctx['urun_adi']} eğitimini {ctx['egitim_ifade']} "
        f"almak istediklerini, {ctx['durum_ifade']} bu konuda."
    )
    return metin, {"urun_kodu", "egitim_turu", "durum"}


def sablon_15(ctx):
    metin = (
        f"Değerlendirdi {ctx['kurum_adi']} tarafı teklifimizi, {ctx['baslangic_metin']} tarihinde "
        f"başlaması gereken eğitim için, {ctx['durum_ifade']} sonuçta."
    )
    return metin, {"baslangic_tarihi", "durum"}


def sablon_16(ctx):
    metin = f"Aldık bugün {ctx['kurum_adi']} yetkililerinden bir haber, {ctx['durum_ifade']}."
    return metin, {"durum"}


def sablon_17(ctx):
    metin = f"{ctx['kurum_adi']} - {ctx['urun_adi']} - {ctx['baslangic_metin']} başlangıçlı - {ctx['durum_ifade']}."
    return metin, {"urun_kodu", "baslangic_tarihi", "durum"}


def sablon_18(ctx):
    metin = (
        f"{ctx['kurum_adi']} ile görüşüldü ama eğitim formatı konusunda net bir şey söylemediler, "
        f"{ctx['egitim_ifade']}, {ctx['durum_ifade']}."
    )
    return metin, {"egitim_turu", "durum"}


def sablon_19(ctx):
    metin = (
        f"Bugün {ctx['kurum_adi']} tarafından arandık, {ctx['urun_adi']} eğitimini {ctx['egitim_ifade']} "
        f"istiyorlarmış, {ctx['baslangic_metin']} ile {ctx['bitis_metin']} arası düşünüyorlar, "
        f"{ctx['durum_ifade']} gibi görünüyor."
    )
    return metin, {"urun_kodu", "baslangic_tarihi", "bitis_tarihi", "egitim_turu", "durum"}


def sablon_20(ctx):
    metin = (
        f"Planlanıyor {ctx['kurum_adi']} için {ctx['urun_adi']} eğitimi, {ctx['baslangic_metin']} "
        f"tarihinde başlayacak şekilde, {ctx['egitim_ifade']}."
    )
    return metin, {"urun_kodu", "baslangic_tarihi", "egitim_turu"}


SABLONLAR = [
    sablon_1, sablon_2, sablon_3, sablon_4, sablon_5,
    sablon_6, sablon_7, sablon_8, sablon_9, sablon_10,
    sablon_11, sablon_12, sablon_13, sablon_14, sablon_15,
    sablon_16, sablon_17, sablon_18, sablon_19, sablon_20,
]


def ozet_olustur(kayit, alanlar):
    parcalar = [f"{kayit['kurum_adi']} ile görüşüldü."]

    if "urun_kodu" in alanlar:
        parcalar.append(f"{URUN_ADLARI[kayit['urun_kodu']]} eğitimi gündeme geldi.")

    if "baslangic_tarihi" in alanlar and "bitis_tarihi" in alanlar:
        parcalar.append(
            f"Eğitim {kayit['baslangic_tarihi']} - {kayit['bitis_tarihi']} tarihleri arasında planlanıyor."
        )
    elif "baslangic_tarihi" in alanlar:
        parcalar.append(f"Eğitim {kayit['baslangic_tarihi']} tarihinde başlayacak.")
    elif "bitis_tarihi" in alanlar:
        parcalar.append(f"Eğitim {kayit['bitis_tarihi']} tarihine kadar sürecek.")

    if "egitim_turu" in alanlar:
        parcalar.append(f"Eğitim {EGITIM_OZET[kayit['egitim_turu']]} formatta yürütülecek.")

    parcalar.append(f"Görüşme sonucu: {DURUM_OZET[kayit['durum']]}.")

    return " ".join(parcalar)


def satir_uret():
    kurum_turu = random.choice(KURUM_TURLERI)
    kurum_adi = kurum_adi_uret(kurum_turu)
    urun_kodu = random.choice(URUN_KODLARI)
    baslangic, bitis = rastgele_tarih_araligi()
    egitim_turu = random.choice(EGITIM_TURLERI)
    durum = random.choice(DURUMLAR)

    ctx = {
        "kurum_adi": kurum_adi,
        "urun_adi": URUN_ADLARI[urun_kodu],
        "baslangic_metin": tarih_metni(baslangic),
        "bitis_metin": tarih_metni(bitis),
        "egitim_ifade": random.choice(EGITIM_IFADELERI[egitim_turu]),
        "durum_ifade": random.choice(DURUM_IFADELERI[durum]),
    }

    sablon = random.choice(SABLONLAR)
    gorusme_metni, alanlar = sablon(ctx)

    kayit = {
        "kurum_adi": kurum_adi,
        "kurum_türü": kurum_turu,
        "urun_kodu": urun_kodu if "urun_kodu" in alanlar else None,
        "baslangic_tarihi": baslangic.isoformat() if "baslangic_tarihi" in alanlar else None,
        "bitis_tarihi": bitis.isoformat() if "bitis_tarihi" in alanlar else None,
        "egitim_turu": egitim_turu if "egitim_turu" in alanlar else "BELIRSIZ",
        "durum": durum if "durum" in alanlar else "TALEP_EDILMEDI",
    }
    kayit["not_icerigi"] = ozet_olustur(kayit, alanlar)

    return {
        "messages": [
            {"role": "system", "content": random.choice(SISTEM_MESAJLARI)},
            {"role": "user", "content": gorusme_metni},
            {"role": "assistant", "content": json.dumps(kayit, ensure_ascii=False)},
        ]
    }


def main():
    with open(DOSYA_ADI, "w", encoding="utf-8") as dosya:
        for _ in range(SATIR_SAYISI):
            satir = satir_uret()
            dosya.write(json.dumps(satir, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
