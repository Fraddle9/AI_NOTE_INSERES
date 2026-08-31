import asyncio
import json
import os
import time
from pathlib import Path
from typing import Optional

import google.generativeai as genai

from enums import (
    GORUSME_DURUMU_DEGERLERI,
    SUREC_TIPI_DEGERLERI,
    URUN_KODU_DEGERLERI,
    SurecTipi,
    en_yakin_urun_adi,
    metinden_katalog_urunleri,
    surec_tipi_esnek_normalize,
    surec_tipi_metinden_algila,
    urun_adi_coz,
    urunleri_filtrele,
)

GECERSIZ_YANIT = "Sunucudan geçersiz veya boş yanıt alındı"


def _env_dosyasini_yukle() -> None:
    dosya = Path(__file__).with_name(".env")
    if not dosya.exists():
        return
    for satir in dosya.read_text(encoding="utf-8").splitlines():
        satir = satir.strip()
        if not satir or satir.startswith("#") or "=" not in satir:
            continue
        anahtar, _, deger = satir.partition("=")
        os.environ.setdefault(anahtar.strip(), deger.strip().strip("\"'"))


_env_dosyasini_yukle()

# NOT: Bu, konuşmayı metne çeviren model DEĞİLDİR (o iş artık Flutter'da
# `speech_to_text` ile cihaz üstünde yapılıyor). Bu sadece CRM analizini
# (kurum/ürün/durum çıkarımı) yapan Gemini metin modelidir.
GEMINI_ANALIZ_MODELI = "gemini-3.6-flash (Google Generative AI - CRM metin analizi, transkripsiyon değil)"
_DEFAULT_MODEL_CHAIN = "gemini-3.6-flash,gemini-3.5-flash,gemini-3.0-flash"
GEMINI_MODEL_CANDIDATES = [
    m.strip()
    for m in os.getenv("GEMINI_MODEL_CANDIDATES", _DEFAULT_MODEL_CHAIN).split(",")
    if m.strip()
]
GEMINI_MODEL_ID = GEMINI_MODEL_CANDIDATES[0] if GEMINI_MODEL_CANDIDATES else "gemini-3.6-flash"
GEMINI_REQUEST_TIMEOUT_SEC = float(os.getenv("GEMINI_ANALIZ_TIMEOUT_SEC", "90"))

_analiz_model_cache: dict[tuple[str, bool], genai.GenerativeModel] = {}


def _gemini_api_key() -> str:
    for anahtar in ("GOOGLE_API_KEY", "GEMINI_API_KEY"):
        deger = (os.getenv(anahtar) or "").strip()
        if deger:
            return deger
    raise RuntimeError(
        "GOOGLE_API_KEY veya GEMINI_API_KEY tanımlı değil. "
        ".env dosyasına ekleyin (bkz. .env.example)."
    )


genai.configure(api_key=_gemini_api_key())

ZERO_INFERENCE_KURALI = (
    "SEN BİR VERİ ÇIKARIM (EXTRACTION) ASİSTANISIN. "
    "Görevin metni yorumlamak, tamamlamak, genişletmek veya yeni bilgi UYDURMAK DEĞİLDİR; "
    "sadece metinde ZATEN VAR OLANI JSON formatında dışarı aktarmaktır. "
    "METİNDE OLMAYAN HİÇBİR DETAYI (kurum, tarih, durum, görev vb.) JSON'A EKLEYEMEZSİN. "
    "Tahmin etme, çıkarım yapma, katalogdan rastgele/alakasız ürün ekleme YASAKTIR. "
    "Do not infer new facts. Do not hallucinate unrelated details. "
    "TEK İSTİSNA — ÜRÜN ADI FONETİK DÜZELTME: Ses tanıma (STT) kaynaklı fonetik/yazım "
    "hatalarını KURAL 1'de anlatıldığı gibi sistemde kayıtlı ürün kataloğuna göre "
    "düzeltmen GEREKİR; bu bir 'uydurma' değil, ZORUNLU bir normalizasyondur."
)

PIRI_URUN_AYRIMI = (
    "DİKKAT: 'Piri AI' ile 'Piri Keşif Aracı' BİRBİRİNDEN TAMAMEN AYRI iki üründür; "
    "birini diğeriyle KARIŞTIRMA ve otomatik olarak ikisini birden ekleme. "
    "Metinde (veya onun fonetik/bozuk halinde, ör. 'piri ey ay', 'pire ai') sadece "
    "'Piri AI' geçiyorsa SADECE 'Piri AI' yaz; 'Piri Keşif Aracı' EKLEME. "
    "Metinde (veya onun fonetik/bozuk halinde, ör. 'pdk şef', 'piri keşif') sadece "
    "'Piri Keşif Aracı' geçiyorsa SADECE 'Piri Keşif Aracı' yaz; 'Piri AI' EKLEME. "
    "Her iki ürün de açıkça (veya fonetik olarak) geçiyorsa ikisini de ekleyebilirsin. "
    "İkisinden de hiç iz yoksa hiçbirini ekleme."
)

GOREV_SISTEM_KURALI = (
    "DİKKAT — GÖREVLER KESİNLİKLE BİR DİZİ (ARRAY OF OBJECTS) OLMALI, TEK BİR METİN DEĞİL: "
    "gorevler alanı HER ZAMAN, her biri {\"task\": \"...\"} şeklinde bir NESNE olan öğelerden "
    "oluşan bir JSON dizisidir. Örnek: [{\"task\": \"Piri AI abonelik iptali yapılacak\"}, "
    "{\"task\": \"Piri Keşif Aracı için online eğitim planlanacak\"}]. "
    "BİR GÖRÜŞMEDEN BİRDEN FAZLA GÖREV ÇIKABİLİR: kullanıcının metnindeki aksiyon gerektiren "
    "TÜM durumları (iptal, toplantı, mail atma, eğitim planlama, deneme başlatma vb.) TEK TEK, "
    "hiçbirini atlamadan, ayrı birer {\"task\": ...} öğesi olarak listeye ekle — sadece ilk "
    "geçen aksiyonla YETİNME. "
    "gorevler dizisine asla toplantı notunun tamamını veya uzun paragraf özetlerini yazma. "
    "Metnin içinden sadece net aksiyon cümlelerini cımbızla; her 'task' değeri kısa ve tek bir "
    "aksiyonu ifade etmelidir. Görevler 10-15 kelimeyi geçmeyecek şekilde, emir kipi veya "
    "gelecek zaman formatında kısa ve öz olmalıdır "
    "(Örn: '1 Eylül'de 1 aylık deneme sürümü başlatılacak', "
    "'Gelecek hafta yerleşkede yüz yüze eğitim verilecek'). "
    "Görev metnine, görüşmede adı geçmeyen ürün isimleri EKLEME. Aksiyon yoksa boş dizi ([]) "
    "döndür, asla uydurma bir görev ekleme."
)

KARMA_DURUM_KURALI = (
    "KURAL 3 — GÖRÜŞME DURUMU VE 'KARMA' (MIXED) TESPİTİ: durum alanına SADECE şu dört "
    "değerden BİRİNİ yaz: 'Olumlu', 'Olumsuz', 'Karma', 'Beklemede'. Eğer metinde bir ürün "
    "için olumlu, başka bir ürün için olumsuz bir durum varsa VEYA genel olarak hem iyi hem "
    "kötü geribildirimler içeriyorsa Görüşme Durumu'nu KESİNLİKLE 'Karma' olarak seç — bunu "
    "asla 'Olumlu' veya 'Olumsuz'a yuvarlama. ÖRNEK: 'Piri AI'dan memnun değiller, aboneliği "
    "iptal etmek istiyorlar. Ama Piri Keşif Aracı'nı beğendiler, online eğitim istediler.' "
    "-> durum='Karma' (Piri AI için olumsuz, Piri Keşif Aracı için olumlu sinyal aynı anda var). "
    "Metin SADECE olumlu sinyaller içeriyorsa 'Olumlu', SADECE olumsuz sinyaller içeriyorsa "
    "'Olumsuz' yaz; henüz bir sonuç/karar belli değilse 'Beklemede' yaz. "
    "Ayrıca kullanıcının metnindeki TÜM aksiyon gerektiren durumları (iptal, toplantı, mail "
    "atma, eğitim planlama vb.) eksiksiz bir şekilde ayrıştırarak görevler (tasks) listesine "
    "ayrı ayrı maddeler olarak ekle (bkz. GÖREV KURALI)."
)

SUREC_TIPI_KURALI = (
    "KURAL 2 — SÜREÇ TİPİ ALGILAMA (ÇOK SIKI UYGULA): surec_tipi alanına SADECE şu üç "
    "değerden BİRİNİ yaz: 'Abonelik', 'Deneme', 'Hiçbiri'. "
    "Kullanıcının metninde 'abonelik', 'abone', 'satın alma', 'lisanslama', 'kontrat', "
    "'sözleşme' gibi kelimeler GEÇİYORSA VEYA bu yönde bir tarih/niyet belirtiliyorsa "
    "(ÖNEMLİ: '30 Ağustos'ta abonelik başlatacağım', 'gelecek ay abone olacağız', "
    "'ay sonunda satın alma yapılacak' gibi GELECEK ZAMANLI / PLANLANMIŞ ifadeler DAHİL) "
    "surec_tipi KESİNLİKLE 'Abonelik' OLMALIDIR. İşlemin henüz gerçekleşmemiş, ileri bir "
    "tarihte planlanmış olması bu kararı ASLA DEĞİŞTİRMEZ — planlanan/niyet edilen bir "
    "abonelik de 'Abonelik' sayılır, 'Hiçbiri' YAZMA. "
    "'deneme', 'demo', 'test', 'trial', 'deneme sürümü/erişimi', 'pilot' gibi ifadeler "
    "geçiyorsa (ve abonelik ifadesi yoksa) surec_tipi 'Deneme' OLMALIDIR. "
    "surec_tipi'ni SADECE HER İKİSİYLE de (abonelik VEYA deneme) ilgili hiçbir kelime/niyet "
    "geçmiyorsa, ya da yalnızca genel bir toplantı/tanışma söz konusuysa 'Hiçbiri' seç. "
    "Başka bir değer (ör. 'Deneme Erişimi', 'trial', 'yok', 'Planlanan Abonelik') YAZMA — "
    "üç değerden birini birebir kullan. "
    "ÇOK ÖNEMLİ — OLUMSUZLUK (NEGATİF NİYET) İSTİSNASI: 'abone', 'satın alma', 'deneme' "
    "gibi kelimeler metinde geçse BİLE, eğer bu kelime OLUMSUZ bir fiille kullanılıyorsa "
    "(ör. 'satın ALMAYACAKLAR', 'abone OLMAK İSTEMİYORLAR', 'hiçbirini almayacaklarmış', "
    "'ilgilenmediler', 'vazgeçtiler', 'reddettiler', 'almadılar') BU KESİNLİKLE 'Abonelik' "
    "veya 'Deneme' SAYILMAZ — ret/olumsuz niyet ifade eden bu tür cümlelerde surec_tipi "
    "'Hiçbiri' OLMALIDIR. Kelimenin GEÇMESİ yetmez, cümlenin OLUMLU bir niyet/eylem ifade "
    "etmesi GEREKİR. ÖRNEK: 'Ürünlerin hiçbirini almayacaklarmış' -> surec_tipi='Hiçbiri' "
    "(ASLA 'Abonelik' değil, çünkü cümle bir RET ifade ediyor)."
)

URUN_YAKALAMA_KURALI = (
    "KURAL 1 — ÜRÜN EŞLEŞTİRME SÖZLÜĞÜ (FONETİK DÜZELTME ZORUNLUDUR): "
    "Kullanıcının konuşma metninde ses tanıma (speech-to-text) kaynaklı FONETİK/YAZIM "
    "HATALARI olabilir (ör. 'Piri AI' yerine metne 'piri ey ay', 'Piri Keşif Aracı' yerine "
    "'pdk şef' veya 'piri keşif' gibi bozuk/eksik telaffuzlar düşebilir). "
    "SADECE aşağıda 'KATALOG' başlığı altında listelenen, sistemde KAYITLI ürünleri "
    "ilgilenilen_urunler / urun_adi alanına yazabilirsin. Bunların DIŞINDA ASLA yeni, "
    "kataloğa hiç benzemeyen bir ürün adı UYDURMA. "
    "Metindeki bozuk/fonetik ifadeyi KATALOGDAKİ EN YAKIN ürünle EŞLEŞTİR ve alana o "
    "ürünün KATALOGDAKİ DOĞRU/KANONİK adını yaz — metindeki bozuk haliyle DEĞİL. "
    "ÇOK ÖNEMLİ — BİRDEN FAZLA ÜRÜN: Görüşmede TEK bir ürün olabileceği gibi AYNI ANDA "
    "BİRDEN FAZLA (2, 3 veya daha fazla) farklı ürün de geçebilir. Metni BAŞTAN SONA "
    "TARA ve bahsi geçen (doğru ya da fonetik/bozuk haliyle) KATALOGDAKİ HER ürünü "
    "ilgilenilen_urunler dizisine ekle — SADECE metinde İLK bahsedilen/duyduğun ürünle "
    "YETİNME, konuşmanın devamında geçen diğer ürünleri de GÖZ ARDI ETME. "
    "ÖRNEK 1 — Metin: '...piri ey ay için deneme erişimi istediler...' "
    "DOĞRU: ilgilenilen_urunler=['Piri AI'], urun_adi='Piri AI' " 
    "(metindeki 'piri ey ay' KOPYALANMAZ, kataloğun doğru adıyla değiştirilir). "
    "ÖRNEK 2 — Metin: '...pdk şef kataloğunu görmek istiyorlar...' "
    "DOĞRU: ilgilenilen_urunler=['Piri Keşif Aracı'], urun_adi='Piri Keşif Aracı'. "
    "ÖRNEK 3 — Metin: 'Kurumla tanışma toplantısı yapıldı.' (hiçbir ürüne gönderme yok) "
    "DOĞRU: ilgilenilen_urunler=[], urun_adi=null, urun_kodu=null. "
    "ÖRNEK 4 — Metin: '...bulut tabanlı yeni bir CRM aracına bakıyorlar...' (kataloğa HİÇ "
    "benzemiyor) DOĞRU: ilgilenilen_urunler=[], urun_adi=null (bu isim UYDURULMAZ, katalogda "
    "yok diye boş bırakılır). "
    "ÖRNEK 5 — Metin: '...hem piri ey ay hem de chatbot ile ilgilendiler, "
    "ayrıca keşif aracını da merak ediyorlar...' (metinde ÜÇ farklı ürün geçiyor) "
    "DOĞRU: ilgilenilen_urunler=['Piri AI', 'Chatbot', "
    "'Piri Keşif Aracı'] (ÜÇÜNÜ DE ekle, sadece ilkini değil). "
    "ÖRNEK 6 — Metin: '...Piri AI'dan memnun değiller, aboneliği iptal etmek istiyorlar. Ama "
    "Piri Keşif Aracı'nı beğendiler, online eğitim istediler.' (birinci ürün OLUMSUZ bağlamda, "
    "ikinci ürün OLUMLU bağlamda geçiyor ama İKİSİ DE aynı görüşmede bahsi geçen üründür) "
    "DOĞRU: ilgilenilen_urunler=['Piri AI', 'Piri Keşif Aracı'] (bir ürün için OLUMSUZ bir "
    "geribildirim geçmesi, o ürünün listeden ÇIKARILMASI/ATLANMASI anlamına GELMEZ — olumlu ya "
    "da olumsuz her bağlamda adı geçen HER ürün listeye eklenir). "
    "urun_adi yalnızca ilgilenilen_urunler'deki ilk (kataloğa eşleşmiş) addır; liste boşsa null "
    "(NOT: urun_adi tek bir alan olsa da, ilgilenilen_urunler dizisi metindeki TÜM eşleşen "
    "ürünleri içermelidir — urun_adi'nin tekil olması, listeyi tek ürünle sınırlama SEBEBI DEĞİLDİR). "
    "urun_kodu yalnızca eşleştirdiğin ürünün katalogdaki kodudur; eşleşme yoksa null. "
    "SON KONTROL (JSON'u döndürmeden ÖNCE mutlaka yap): KATALOG listesindeki HER ürünü tek tek "
    "gözden geçir ve 'bu ürünün adı (doğru ya da fonetik/bozuk haliyle) bu metinde geçiyor mu?' "
    "diye sor; cevap EVET olan HER ürünü ilgilenilen_urunler dizisine eklediğinden emin ol. "
    "Metinde 2 veya daha fazla ürün adı geçiyorsa dizide de 2 veya daha fazla öğe OLMALIDIR — "
    "sadece 1 öğe ile cevap verip diğerini atlamak KABUL EDİLEMEZ bir hatadır. "
    "Katalogda olan ama metinde (doğru ya da fonetik/bozuk haliyle) hiç değinilmeyen bir "
    "ürünü ASLA listeye ekleme — eşleştirme sadece metinde GERÇEKTEN bahsi geçen bir "
    "ifade için yapılır, katalogdan rastgele ürün seçmek değildir."
)

# KRİTİK KURAL: Kullanıcının söylediği asıl cümleler (speech_to_text ham metni)
# hiçbir zaman özetlenmez, kısaltılmaz veya yeniden yazılmaz. Gemini SADECE bu
# ham metnin içinden yapılandırılmış alanları (kurum, ürün, durum, görevler vb.)
# çıkarmak için kullanılır. Bu yüzden JSON şemasında metni tekrar üreten/özetleyen
# bir alan (ör. eski "not_icerigi") artık İSTENMİYOR — asıl transkript backend'de
# her zaman kullanıcının orijinal metni (`ham_metin`) olarak saklanır ve gösterilir.
TRANSKRIPT_DEGISTIRME_YASAGI = (
    "ÇOK ÖNEMLİ KURAL: Aşağıdaki 'Görüşme Metni' kullanıcının kendi ağzından çıkan, birebir "
    "kaydedilmesi gereken orijinal transkripttir. Bu metni ASLA özetleme, kısaltma, yeniden "
    "yazma, yorumlama veya parafraze etme. Görevin SADECE bu metnin içinden istenen alanları "
    "(kurum adı, ürün, durum, görevler, tarihler vb.) ayıklamaktır. JSON çıktına metnin "
    "tamamını veya özetini yeniden yazan hiçbir alan ekleme; sistem asıl metni zaten kendi "
    "kaydından (kullanıcının orijinal girdisinden) alacaktır. "
    + ZERO_INFERENCE_KURALI
)

ANALIZ_RESPONSE_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "kurum_adi": {"type": "STRING"},
        "kurum_türü": {"type": "STRING"},
        "ilgilenilen_urunler": {"type": "ARRAY", "items": {"type": "STRING"}},
        "urun_kodu": {"type": "STRING", "nullable": True},
        "urun_adi": {"type": "STRING", "nullable": True},
        "surec_tipi": {"type": "STRING", "enum": SUREC_TIPI_DEGERLERI},
        "baslangic_tarihi": {"type": "STRING", "nullable": True},
        "bitis_tarihi": {"type": "STRING", "nullable": True},
        "egitim_turu": {"type": "STRING", "nullable": True},
        "durum": {"type": "STRING", "enum": GORUSME_DURUMU_DEGERLERI},
        "aksiyon_adimi": {"type": "STRING", "nullable": True},
        "gelecek_gorusme_tarihi": {"type": "STRING", "nullable": True},
        "gorevler": {
            "type": "ARRAY",
            "items": {
                "type": "OBJECT",
                "properties": {"task": {"type": "STRING"}},
                "required": ["task"],
            },
        },
    },
    "required": ["ilgilenilen_urunler", "surec_tipi", "durum", "gorevler"],
}

ANALIZ_SYSTEM_INSTRUCTION = (
    f"{ZERO_INFERENCE_KURALI}\n\n{TRANSKRIPT_DEGISTIRME_YASAGI}\n\n"
    f"{URUN_YAKALAMA_KURALI}\n\n{PIRI_URUN_AYRIMI}\n\n"
    f"{SUREC_TIPI_KURALI}\n\n{KARMA_DURUM_KURALI}\n\n{GOREV_SISTEM_KURALI}\n\n"
    "ÇIKTI: Yalnızca geçerli JSON döndür. Metinde olmayan alan ekleme. "
    "JSON şeması response_schema ile tanımlıdır; ek açıklama yazma."
)


def _analiz_generation_config() -> dict:
    # Thinking modellerinde (3.5/3.6) max_output_tokens düşünme + çıktıyı paylaşır;
    # 2048 kesilmiş JSON üretiyordu. thinking_budget=0 çıktıya yer bırakır.
    return {
        "response_mime_type": "application/json",
        "response_schema": ANALIZ_RESPONSE_SCHEMA,
        "temperature": 0.1,
        "max_output_tokens": 8192,
        "thinking_config": {"thinking_budget": 0},
    }


def _json_only_generation_config() -> dict:
    return {
        "response_mime_type": "application/json",
        "temperature": 0.1,
        "max_output_tokens": 8192,
        "thinking_config": {"thinking_budget": 0},
    }


def _gemini_request_options() -> dict:
    return {"timeout": GEMINI_REQUEST_TIMEOUT_SEC}


def _analiz_modeli_al(model_id: str, schema_ile: bool = False) -> genai.GenerativeModel:
    cache_key = (model_id, schema_ile)
    if cache_key not in _analiz_model_cache:
        generation_config = (
            _analiz_generation_config() if schema_ile else _json_only_generation_config()
        )
        try:
            _analiz_model_cache[cache_key] = genai.GenerativeModel(
                model_id,
                system_instruction=ANALIZ_SYSTEM_INSTRUCTION,
                generation_config=generation_config,
            )
        except Exception as cfg_err:
            print(f"[ai_service] thinking_config reddedildi ({cfg_err}); sade config kullanılıyor")
            sade = dict(generation_config)
            sade.pop("thinking_config", None)
            _analiz_model_cache[cache_key] = genai.GenerativeModel(
                model_id,
                system_instruction=ANALIZ_SYSTEM_INSTRUCTION,
                generation_config=sade,
            )
    return _analiz_model_cache[cache_key]


def _katalog_satirlari(urun_kodlari) -> tuple[str, str]:
    katalog = urun_kodlari or URUN_KODU_DEGERLERI
    if katalog and isinstance(katalog[0], dict):
        satirlar = "\n".join(
            f"- {u.get('name') or u.get('code')} ({u.get('code')})" for u in katalog
        )
        kod_listesi = ", ".join((u.get("code") or "") for u in katalog if u.get("code"))
    else:
        satirlar = "\n".join(f"- {k}" for k in katalog)
        kod_listesi = ", ".join(str(k) for k in katalog)
    return satirlar, kod_listesi


def _analiz_promptu_olustur(ham_metin: str, urun_kodlari) -> str:
    """Kurallar system_instruction'da; kullanıcı prompt'u kısa tutulur (daha az token)."""
    katalog_satirlari, kod_listesi = _katalog_satirlari(urun_kodlari)
    return f"""Aşağıdaki müşteri görüşmesi metnini analiz et.
Metnin TAMAMINI oku (ilk cümleden son cümleye). Başta geçen ürünleri veya
süreç tipi (deneme / abonelik) ifadelerini atlama.
SADECE geçerli JSON döndür (şema system tarafında tanımlı). Metinde olmayan bilgi ekleme.

JSON alanları:
- kurum_adi, kurum_türü (UNIVERSITE|SIRKET|null)
- ilgilenilen_urunler (katalogdaki kanonik adlar), urun_kodu, urun_adi
- surec_tipi: Deneme | Abonelik | Hiçbiri
- baslangic_tarihi, bitis_tarihi, gelecek_gorusme_tarihi (YYYY-MM-DD veya null)
- egitim_turu, durum (Olumlu|Olumsuz|Karma|Beklemede), aksiyon_adimi
- gorevler: [{{"task": "kısa aksiyon"}}] — birden fazla aksiyon varsa hepsini ayrı ekle

KATALOG — ilgilenilen_urunler için SADECE bunlar (kodlar: {kod_listesi}):
{katalog_satirlari}

Görüşme Metni:
\"\"\"{ham_metin}\"\"\"
"""


def _gemini_yanit_metni(response) -> Optional[str]:
    """Gemini yanıtından metni güvenli çıkarır (`response.text` ValueError verebilir)."""
    if response is None:
        return None
    try:
        metin = response.text
        if metin and str(metin).strip():
            return str(metin)
    except Exception as exc:
        print(f"[ai_service] response.text erişim hatası: {exc}")
    try:
        for cand in (getattr(response, "candidates", None) or []):
            content = getattr(cand, "content", None)
            if not content:
                continue
            parcalar = []
            for part in (getattr(content, "parts", None) or []):
                txt = getattr(part, "text", None)
                if txt and str(txt).strip():
                    parcalar.append(str(txt))
            if parcalar:
                return "".join(parcalar)
    except Exception as exc:
        print(f"[ai_service] candidates parse hatası: {exc}")
    return None


async def _gemini_generate_async(
    model: genai.GenerativeModel,
    prompt: str,
    model_id: str = GEMINI_MODEL_ID,
):
    t0 = time.monotonic()
    print(
        f"[ai_service] AI isteği başladı (model={model_id}, "
        f"timeout={GEMINI_REQUEST_TIMEOUT_SEC:.0f}s)..."
    )
    try:
        response = await asyncio.wait_for(
            model.generate_content_async(
                prompt,
                request_options=_gemini_request_options(),
            ),
            timeout=GEMINI_REQUEST_TIMEOUT_SEC + 5,
        )
    except asyncio.TimeoutError as exc:
        sure = time.monotonic() - t0
        print(f"[ai_service] AI isteği zaman aşımına uğradı. Süre: {sure:.2f} saniye")
        raise ValueError("Gemini API zaman aşımına uğradı") from exc
    except Exception as exc:
        sure = time.monotonic() - t0
        print(f"[ai_service] AI isteği hata ile bitti. Süre: {sure:.2f} saniye — {exc}")
        if "thinking_config" in str(exc) or "Unknown field" in str(exc):
            print("[ai_service] thinking_config desteklenmiyor; cache temizlenip sade config deneniyor")
            _analiz_model_cache.clear()
            sade_model = genai.GenerativeModel(
                model_id,
                system_instruction=ANALIZ_SYSTEM_INSTRUCTION,
                generation_config={
                    "response_mime_type": "application/json",
                    "temperature": 0.1,
                    "max_output_tokens": 8192,
                },
            )
            response = await asyncio.wait_for(
                sade_model.generate_content_async(
                    prompt,
                    request_options=_gemini_request_options(),
                ),
                timeout=GEMINI_REQUEST_TIMEOUT_SEC + 5,
            )
            sure = time.monotonic() - t0
            print(f"[ai_service] AI isteği bitti. Süre: {sure:.2f} saniye")
            return response
        raise
    sure = time.monotonic() - t0
    print(f"[ai_service] AI isteği bitti. Süre: {sure:.2f} saniye")
    return response


async def _gemini_analiz_dene(
    prompt: str,
    ham_metin: str,
    katalog,
    model_id: str,
    schema_ile: bool,
) -> dict:
    model = _analiz_modeli_al(model_id, schema_ile=schema_ile)
    response = await _gemini_generate_async(model, prompt, model_id=model_id)
    ham_cevap = _gemini_yanit_metni(response)
    if not ham_cevap or not str(ham_cevap).strip():
        raise ValueError(f"{model_id}: boş yanıt")
    return _analiz_sonucunu_isle(ham_metin, ham_cevap, katalog)


def _analiz_deneme_plani():
    """JSON-only, ardından birincil modelde şema. 404 modeller atlanır."""
    plan = []
    for model_id in GEMINI_MODEL_CANDIDATES:
        plan.append((model_id, False))
    if GEMINI_MODEL_CANDIDATES:
        plan.append((GEMINI_MODEL_CANDIDATES[0], True))
    return plan


def _run_async(coro):
    try:
        asyncio.get_running_loop()
    except RuntimeError:
        return asyncio.run(coro)
    raise RuntimeError(
        "Senkron metni_yapilandir() async bağlamda çağrılamaz; "
        "metni_yapilandir_async() kullanın."
    )


def _analiz_sonucunu_isle(ham_metin: str, ham_cevap, katalog) -> dict:
    sonuc = _guvenli_json(ham_cevap)
    sonuc.pop("not_icerigi", None)

    surec_tipi = surec_tipi_esnek_normalize(sonuc.get("surec_tipi") or sonuc.get("abonelik_tipi"))
    if surec_tipi == SurecTipi.HICBIRI.value:
        algilanan = surec_tipi_metinden_algila(ham_metin)
        if algilanan:
            surec_tipi = algilanan
    sonuc["surec_tipi"] = surec_tipi
    sonuc["abonelik_tipi"] = surec_tipi

    urunler = _ilgilenilen_urunler_normalize(
        sonuc.get("ilgilenilen_urunler"),
        sonuc.get("urun_adi"),
    )
    urunler = _urunleri_dogrula(urunler, katalog)
    gorulen = {u.casefold() for u in urunler}
    for ad in metinden_katalog_urunleri(ham_metin, katalog):
        if ad.casefold() not in gorulen:
            urunler.append(ad)
            gorulen.add(ad.casefold())
    sonuc["ilgilenilen_urunler"] = urunler
    sonuc["urun_adi"] = urunler[0] if urunler else None
    if not urunler:
        sonuc["urun_kodu"] = None
    return sonuc


async def metni_yapilandir_async(ham_metin: str, urun_kodlari: Optional[list] = None):
    """Async CRM metin analizi — Gemini generate_content_async kullanır."""
    t_toplam = time.monotonic()
    print(
        f"[ai_service] CRM analizi — modeller: {', '.join(GEMINI_MODEL_CANDIDATES)} "
        f"(timeout={GEMINI_REQUEST_TIMEOUT_SEC:.0f}s)"
    )
    katalog = urun_kodlari or URUN_KODU_DEGERLERI

    t_prompt = time.monotonic()
    prompt = _analiz_promptu_olustur(ham_metin, katalog)
    print(
        f"[ai_service] Prompt hazırlandı ({time.monotonic() - t_prompt:.3f} sn, "
        f"{len(prompt)} karakter)"
    )

    son_hatalar: list[str] = []
    try:
        for model_id, schema_ile in _analiz_deneme_plani():
            etiket = f"{model_id}{'+schema' if schema_ile else ''}"
            try:
                print(f"[ai_service] Deneme: {etiket}")
                sonuc = await _gemini_analiz_dene(
                    prompt, ham_metin, katalog, model_id, schema_ile
                )
                print(
                    f"[ai_service] Başarılı model: {etiket} "
                    f"(toplam {time.monotonic() - t_toplam:.2f} sn)"
                )
                return sonuc
            except ValueError as exc:
                son_hatalar.append(f"{etiket}: {exc}")
                print(f"[ai_service] {etiket} başarısız — {exc}")
            except Exception as exc:
                msg = f"{type(exc).__name__}: {exc}"
                son_hatalar.append(f"{etiket}: {msg}")
                print(f"[ai_service] {etiket} hata — {msg}")
                if "429" in msg or "quota" in msg.lower() or "ResourceExhausted" in msg:
                    raise
                if "404" in msg or "not found" in msg.lower() or "no longer available" in msg.lower():
                    continue

        ozet = "; ".join(son_hatalar[-5:]) if son_hatalar else "bilinmeyen hata"
        print(f"[ai_service] Tüm Gemini denemeleri başarısız: {ozet}")
        raise ValueError(GECERSIZ_YANIT)
    except ValueError:
        raise
    except json.JSONDecodeError:
        raise ValueError(GECERSIZ_YANIT)
    except Exception as e:
        msg = str(e)
        print(f"[ai_service] metni_yapilandir beklenmeyen hata: {type(e).__name__}: {msg}")
        if "429" in msg or "quota" in msg.lower() or "ResourceExhausted" in msg:
            raise
        raise ValueError(GECERSIZ_YANIT) from e


def metni_yapilandir(ham_metin: str, urun_kodlari: Optional[list] = None):
    """Senkron sarmalayıcı (geriye dönük uyumluluk)."""
    return _run_async(metni_yapilandir_async(ham_metin, urun_kodlari))


def _surec_tipi_normalize(deger) -> str:
    return surec_tipi_esnek_normalize(deger)


def _ilgilenilen_urunler_normalize(deger, urun_adi=None) -> list:
    adlar = []
    if isinstance(deger, str):
        deger = [p.strip() for p in deger.replace(";", ",").split(",") if p.strip()]
    if isinstance(deger, list):
        for item in deger:
            ad = str(item or "").strip()
            if ad and ad.lower() not in ("null", "none", "-", "yok"):
                adlar.append(ad)
    ekstra = str(urun_adi or "").strip()
    if ekstra and ekstra.lower() not in ("null", "none", "-", "yok"):
        adlar.insert(0, ekstra)
    temiz = []
    gorulen = set()
    for ad in adlar:
        anahtar = ad.casefold()
        if anahtar in gorulen:
            continue
        gorulen.add(anahtar)
        temiz.append(ad)
    return temiz


def _urunleri_dogrula(adlar: list, katalog) -> list:
    """AI'nın çıkardığı ürün adlarını sistemde kayıtlı kataloga göre doğrular.

    ÖNEMLİ: Bu fonksiyon artık ham metinde BİREBİR geçip geçmediğine bakan eski
    (literal substring) kontrolün YERİNE geçer. O eski kontrol, fonetik STT
    hatalarını (ör. 'piri ey ay') düzeltip kataloğun doğru adını ('Piri AI')
    yazdığımızda bu doğru adı 'ham metinde yok' diye YANLIŞLIKLA elerdi — bu da
    tam olarak çözülmesi istenen halüsinasyon hatasının kaynağıydı.

    Yeni davranış: katalogda (tam veya fonetik olarak) karşılığı olmayan
    hiçbir ad veritabanına yazılmaz (gerçek halüsinasyon/uydurma engeli),
    katalogla eşleşen adlar ise KANONİK adlarıyla (doğru yazımla) döner.
    """
    kalanlar = urunleri_filtrele(adlar, katalog, fuzzy=True)
    for ad in (adlar or []):
        ad_str = str(ad or "").strip()
        if ad_str and not (urun_adi_coz(ad_str, katalog) or en_yakin_urun_adi(ad_str, katalog)):
            print(f"[ai_service] Halüsinasyon engellendi: {ad_str!r} katalogda karşılığı yok, atıldı.")
    return kalanlar


def _kesik_json_tamamla(metin: str) -> str:
    """Thinking modellerinin kestiği JSON'u kapatır (ör. '...baslangic_tarihi: nul')."""
    s = metin.strip()
    if s.startswith("```"):
        s = s.strip("`")
        if s.lower().startswith("json"):
            s = s[4:].lstrip()
    ilk = s.find("{")
    if ilk < 0:
        return s
    s = s[ilk:]

    # Kesilmiş literal: nul / nu / n, tru / tr / t, fals / fal / fa / f
    kuyruk = s.rstrip()
    for tam, kesikler in (
        ("null", ("nul", "nu", "n")),
        ("true", ("tru", "tr", "t")),
        ("false", ("fals", "fal", "fa", "f")),
    ):
        for kesik in kesikler:
            if kuyruk.endswith(kesik) and not kuyruk.endswith(tam):
                onceki = kuyruk[: -len(kesik)].rstrip()
                if onceki.endswith(":") or onceki.endswith("[") or onceki.endswith(","):
                    s = onceki + " " + tam
                    break
        else:
            continue
        break

    s = s.rstrip()
    if s.endswith(","):
        s = s[:-1].rstrip()

    # Açık string varsa kapat
    in_str = False
    escape = False
    for ch in s:
        if in_str:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
    if in_str:
        s += '"'

    acik_nesne = 0
    acik_dizi = 0
    in_str = False
    escape = False
    for ch in s:
        if in_str:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
        elif ch == "{":
            acik_nesne += 1
        elif ch == "}":
            acik_nesne = max(0, acik_nesne - 1)
        elif ch == "[":
            acik_dizi += 1
        elif ch == "]":
            acik_dizi = max(0, acik_dizi - 1)
    s += "]" * acik_dizi
    s += "}" * acik_nesne
    return s


def _guvenli_json(ham_cevap) -> dict:
    """Boş, HTML, kesik veya bozuk metni json.loads ile patlatmadan okur."""
    if ham_cevap is None:
        raise ValueError(GECERSIZ_YANIT)
    if isinstance(ham_cevap, dict):
        return ham_cevap
    metin = str(ham_cevap).strip()
    if not metin:
        print("[ai_service] _guvenli_json: boş yanıt")
        raise ValueError(GECERSIZ_YANIT)
    if metin.lower().startswith("<!doctype") or metin.lower().startswith("<html"):
        print(f"[ai_service] _guvenli_json: HTML yanıt alındı: {metin[:120]!r}")
        raise ValueError(GECERSIZ_YANIT)

    adaylar = [metin]
    tamamlanan = _kesik_json_tamamla(metin)
    if tamamlanan != metin:
        adaylar.append(tamamlanan)

    for aday in adaylar:
        ilk_suslu = aday.find("{")
        son_suslu = aday.rfind("}")
        parca = None
        if ilk_suslu >= 0 and son_suslu > ilk_suslu:
            parca = aday[ilk_suslu : son_suslu + 1]
        elif ilk_suslu >= 0:
            parca = aday[ilk_suslu:]
        if not parca:
            continue
        try:
            data = json.loads(parca)
        except json.JSONDecodeError:
            try:
                data, _ = json.JSONDecoder().raw_decode(parca)
            except json.JSONDecodeError:
                continue
        if isinstance(data, dict):
            if aday is not metin or parca != metin:
                print("[ai_service] Kesik/bozuk JSON tamir edildi.")
            return data

    print(
        f"[ai_service] _guvenli_json: JSON bulunamadı ({len(metin)} karakter), "
        f"önizleme: {metin[:240]!r}"
    )
    raise ValueError(GECERSIZ_YANIT)


def _json_al(ham_cevap: str):
    try:
        return _guvenli_json(ham_cevap)
    except (ValueError, json.JSONDecodeError):
        return {}


def gorevleri_cikar(ham_metin: str):
    """Tek bir görüşme metninden yalnızca kısa aksiyon görevlerini çıkarır."""
    return _run_async(gorevleri_cikar_async(ham_metin))


async def gorevleri_cikar_async(ham_metin: str):
    model_id = GEMINI_MODEL_CANDIDATES[0] if GEMINI_MODEL_CANDIDATES else "gemini-3.6-flash"
    model = genai.GenerativeModel(
        model_id,
        system_instruction=GOREV_SISTEM_KURALI,
        generation_config=_json_only_generation_config(),
    )
    prompt = (
        f"Aşağıdaki görüşme notundan SADECE kısa aksiyon görevlerini çıkar.\n"
        f'JSON: {{ "gorevler": ["kısa aksiyon 1"] }}\n'
        f'Aksiyon yoksa: {{ "gorevler": [] }}\n\n'
        f'Görüşme Metni: """{ham_metin}"""'
    )
    try:
        response = await _gemini_generate_async(model, prompt, model_id=model_id)
        data = _json_al(getattr(response, "text", None) or "")
    except Exception:
        return []
    gorevler = data.get("gorevler") if isinstance(data, dict) else []
    return gorevler if isinstance(gorevler, list) else []


def coklu_nottan_gorevler(not_listesi):
    """Birden fazla DB notu / ses dökümünden kısa görev listesi üretir."""
    return _run_async(coklu_nottan_gorevler_async(not_listesi))


async def coklu_nottan_gorevler_async(not_listesi):
    if not not_listesi:
        return []

    bloklar = []
    for i, n in enumerate(not_listesi, 1):
        etiket = (n.get("etiket") or n.get("kurum_adi") or f"Not {i}").strip()
        icerik = (n.get("icerik") or "").strip()[:6000]
        if not icerik:
            continue
        bloklar.append(f"--- KAYNAK {i} ({etiket}) ---\n{icerik}")

    if not bloklar:
        return []

    model_id = GEMINI_MODEL_CANDIDATES[0] if GEMINI_MODEL_CANDIDATES else "gemini-3.6-flash"
    model = genai.GenerativeModel(
        model_id,
        system_instruction=GOREV_SISTEM_KURALI,
        generation_config=_json_only_generation_config(),
    )
    prompt = (
        "Aşağıdaki görüşme notlarından SADECE kısa aksiyon görevlerini çıkar.\n"
        'JSON: { "gorevler": ["kısa aksiyon 1"] }\n\n'
        f"{chr(10).join(bloklar)}"
    )
    try:
        response = await _gemini_generate_async(model, prompt, model_id=model_id)
        data = _json_al(getattr(response, "text", None) or "")
    except Exception:
        return []
    gorevler = data.get("gorevler") if isinstance(data, dict) else []
    return gorevler if isinstance(gorevler, list) else []