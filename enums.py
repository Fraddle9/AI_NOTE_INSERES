"""Backend için katı (strict) Enum tanımları ve doğrulama yardımcıları.

Bu modül; AI (Gemini) çıktısının doğrulanması, veritabanına yazılmadan önce
geçersiz değerlerin sessizce filtrelenmesi ve web/mobile (Flutter) tarafındaki
dropdown/etiket listeleriyle BİREBİR aynı sözlüğün kullanılması için TEK
KAYNAK (single source of truth) olarak kullanılır.

Neden veritabanı kolonları hâlâ String/JSON?
    `products` tablosu `/api/urunler` (POST) üzerinden çalışma zamanında
    genişletilebilir (bkz. main.urun_ekle). Bu yüzden ürün kataloğu için
    DB kolonunu native bir SQL ENUM'a çevirmek, hem bu genişletilebilirliği
    kırar hem de üretimdeki (production) satırlarda enum dışı eski/serbest
    veri varsa okurken hataya yol açabilir. Bunun yerine: (1) burada katı bir
    Enum/varsayılan katalog tanımlanır, (2) gerçek doğrulama/filtreleme bu
    Enum İLE BİRLİKTE veritabanındaki güncel aktif ürün listesini (dinamik
    katalog) kullanır — böylece mevcut çalışan yapı ve genişletilebilirlik
    bozulmadan katı doğrulama sağlanır.
"""

from difflib import SequenceMatcher
from enum import Enum
from typing import Iterable, Optional


class SurecTipi(str, Enum):
    """Bir görüşme/analiz kaydının süreç tipi.

    AI çıktısı ve UI (web/mobile) bu üç değerin dışına ASLA çıkamaz.
    """

    DENEME = "Deneme"
    ABONELIK = "Abonelik"
    HICBIRI = "Hiçbiri"


class GorusmeDurumu(str, Enum):
    """Bir görüşme/analiz kaydının genel sonuç durumu.

    AI çıktısı ve UI (web/mobile) bu dört değerin dışına ASLA çıkamaz.
    'KARMA', metinde en az bir ürün/konu için OLUMLU, başka bir ürün/konu
    için OLUMSUZ bir sinyal geçtiğinde YA DA görüşme genel olarak hem iyi
    hem kötü geri bildirim içerdiğinde (ör. bir üründen memnun değiller ama
    başka bir ürünle ilgilendiler) kullanılır.
    """

    OLUMLU = "Olumlu"
    OLUMSUZ = "Olumsuz"
    KARMA = "Karma"
    BEKLEMEDE = "Beklemede"


class UrunKodu(str, Enum):
    """`products.code` ile birebir eşleşen katı (varsayılan) ürün kodları."""

    PIRI = "PIRI"
    PIRI_AI = "PIRI_AI"
    CHATBOT = "CHATBOT"


class UrunAdi(str, Enum):
    """`products.name` ile birebir eşleşen katı (varsayılan) ürün adları.

    AI'nın `ilgilenilen_urunler` / `urun_adi` alanlarında üretebileceği
    TEK GEÇERLİ (varsayılan) değerler bunlardır. Yeni ürün admin panelinden
    `/api/urunler` ile de eklenebilir.
    """

    PIRI = "Piri Keşif Aracı"
    PIRI_AI = "Piri AI"
    CHATBOT = "Chatbot"


SUREC_TIPI_DEGERLERI: list = [e.value for e in SurecTipi]
GORUSME_DURUMU_DEGERLERI: list = [e.value for e in GorusmeDurumu]

# code -> (name, description). product_seed.INSERES_PRODUCTS bunu kullanır
# (tek kaynak / single source of truth), böylece iki liste birbirinden
# sapamaz (drift).
VARSAYILAN_URUN_KATALOGU: list = [
    {
        "code": UrunKodu.PIRI.value,
        "name": UrunAdi.PIRI.value,
        "description": (
            "Yapay zekâ destekli kurumsal keşif aracı; veri tabanları, "
            "kütüphane kataloğu ve tez merkezlerini tarar."
        ),
    },
    {
        "code": UrunKodu.PIRI_AI.value,
        "name": UrunAdi.PIRI_AI.value,
        "description": "Piri Keşif Aracı'ndan tamamen ayrı yapay zekâ ürünü.",
    },
    {
        "code": UrunKodu.CHATBOT.value,
        "name": UrunAdi.CHATBOT.value,
        "description": "Kurumsal sohbet botu.",
    },
]

URUN_ADI_DEGERLERI: list = [u["name"] for u in VARSAYILAN_URUN_KATALOGU]
URUN_KODU_DEGERLERI: list = [u["code"] for u in VARSAYILAN_URUN_KATALOGU]


def _anahtar(deger) -> str:
    """Karşılaştırma için harf/rakam dışını atar (büyük/küçük harf ve boşluk farkını yok sayar)."""
    return "".join(ch for ch in str(deger or "").casefold() if ch.isalnum())


def gecerli_surec_tipi_mi(deger) -> bool:
    return str(deger or "").strip() in SUREC_TIPI_DEGERLERI


def surec_tipi_veya_varsayilan(deger, varsayilan: str = SurecTipi.HICBIRI.value) -> str:
    d = str(deger or "").strip()
    return d if d in SUREC_TIPI_DEGERLERI else varsayilan


def surec_tipi_esnek_normalize(deger, varsayilan: str = SurecTipi.HICBIRI.value) -> str:
    """Serbest/STT metnini üç kanonik süreç tipinden birine indirger.

    Büyük/küçük harf ve 'deneme erişimi' / 'trial' gibi eş anlamlılar kabul edilir.
    Tam eşleşme yoksa `varsayilan` (genelde Hiçbiri) döner.
    """
    d = str(deger or "").strip()
    if d in SUREC_TIPI_DEGERLERI:
        return d
    dl = d.casefold()
    if any(k in dl for k in ("deneme", "demo", "trial", "pilot")):
        return SurecTipi.DENEME.value
    if any(k in dl for k in ("abone", "satın", "satin", "lisans", "kontrat", "sözleşme", "sozlesme")):
        return SurecTipi.ABONELIK.value
    if "test" in dl and "istatistik" not in dl:
        return SurecTipi.DENEME.value
    return varsayilan


_SUREC_TIPI_ANAHTAR_KELIMELERI = {
    SurecTipi.ABONELIK.value: (
        "abone", "satın", "satin", "lisans", "kontrat", "sözleşme", "sozlesme", "satış", "satis",
    ),
    SurecTipi.DENEME.value: ("deneme", "demo", "trial", "pilot"),
}

# Türkçede olumsuzluk çoğunlukla anahtar kelimenin KENDİSİNDE değil, aynı
# cümledeki bir FİİLİN ekinde/ekiyle taşınır (ör. "satın ALMAYACAKLAR",
# "abone OLMAK İSTEMİYORLAR", "hiçbirini almayacaklarmış"). Bu yüzden basit
# bir "anahtar kelime metinde geçiyor mu" kontrolü olumsuz cümlelerde de
# yanlışlıkla pozitif (ör. "Abonelik") sonuç üretir. Aşağıdaki ipuçları hem
# yaygın olumsuz fiil ekentilerini (-mA + zaman eki) hem de sık kullanılan
# olumsuzluk sözcüklerini kapsar.
_OLUMSUZLUK_IPUCLARI = (
    "değil", " yok", "istemi", "istemed", "olmay", "olmad", "almay", "almad",
    "vermey", "vermed", "yapmay", "yapmad", "etmey", "etmed", "geçmey", "geçmed",
    "başlamay", "başlamad", "vazgeç", "iptal", "reddet", "kabul etme", "kabul etmi",
    "ilgilenmi", "ilgilenmed", "hiçbirini", "hiçbirine", "mıyor", "miyor", "muyor",
    "müyor", "mayacak", "meyecek", "madı", "medi", "mazlar", "mezler",
)

_CUMLE_SINIRLARI = ".!?;\n,"


def _cumleyi_bul(metin: str, konum: int) -> str:
    """Verilen konumu (karakter index'i) içeren cümleyi (noktalama sınırlı) döndürür."""
    baslangic = konum
    while baslangic > 0 and metin[baslangic - 1] not in _CUMLE_SINIRLARI:
        baslangic -= 1
    bitis = konum
    while bitis < len(metin) and metin[bitis] not in _CUMLE_SINIRLARI:
        bitis += 1
    return metin[baslangic:bitis]


def _olumsuz_baglamda_mi(cumle: str) -> bool:
    c = cumle.casefold()
    return any(ipucu in c for ipucu in _OLUMSUZLUK_IPUCLARI)


def _anahtar_konumlari(metin_fold: str, anahtarlar) -> list:
    konumlar = []
    for k in anahtarlar:
        start = 0
        while True:
            idx = metin_fold.find(k, start)
            if idx == -1:
                break
            konumlar.append((idx, len(k)))
            start = idx + len(k)
    return konumlar


_OLUMSUZLUK_PENCERE = 48


def _yerel_pencere(metin: str, konum: int, anahtar_uzunluk: int, yaricap: int = _OLUMSUZLUK_PENCERE) -> str:
    """Noktalamasız STT metninde tüm kaydı tek cümle sanmamak için anahtar kelimenin yakın çevresini alır."""
    bas = max(0, konum - yaricap)
    bit = min(len(metin), konum + max(anahtar_uzunluk, 1) + yaricap)
    return metin[bas:bit]


def surec_tipi_metinden_algila(ham_metin) -> Optional[str]:
    """Ham metindeki açık niyet/anahtar kelimelerden süreç tipini algılar.

    Bu, AI'nın (yanlışlıkla) 'Hiçbiri' döndürdüğü ama metinde açıkça bir
    abonelik/deneme niyeti geçen durumlar için SON SAVUNMA HATTIDIR (ör.
    '30 Ağustos'ta abonelik başlatacağım' gibi GELECEK ZAMANLI ama net
    ifadeler). Metinde hiçbir ipucu yoksa None döner (çağıran taraf mevcut
    değeri korur).

    ÖNEMLİ — OLUMSUZLUK KONTROLÜ: Bir anahtar kelime (ör. 'satın', 'abone')
    geçse bile, o kelimenin BULUNDUĞU YEREL PENCEREDE bir olumsuzluk ipucu
    (ör. 'almayacaklar', 'istemiyorlar', 'hiçbirini') varsa bu OLUMLU bir
    sinyal SAYILMAZ. Pencere kullanılmasının nedeni: uzun, noktalamasız STT
    metinlerinde 'karar yok' gibi ilgisiz bir ifade tüm kaydı tek cümle
    sayıp 'deneme'yi yanlışlıkla elemesin.
    """
    ham = str(ham_metin or "")
    d = ham.casefold()

    def _olumlu_sinyal_var_mi(anahtarlar) -> bool:
        for konum, uzunluk in _anahtar_konumlari(d, anahtarlar):
            parca = _yerel_pencere(ham, konum, uzunluk)
            if not _olumsuz_baglamda_mi(parca):
                return True
        return False

    if _olumlu_sinyal_var_mi(_SUREC_TIPI_ANAHTAR_KELIMELERI[SurecTipi.ABONELIK.value]):
        return SurecTipi.ABONELIK.value
    if _olumlu_sinyal_var_mi(_SUREC_TIPI_ANAHTAR_KELIMELERI[SurecTipi.DENEME.value]):
        return SurecTipi.DENEME.value
    if "test" in d and "istatistik" not in d:
        test_konumlari = _anahtar_konumlari(d, ("test",))
        if any(not _olumsuz_baglamda_mi(_yerel_pencere(ham, k, u)) for k, u in test_konumlari):
            return SurecTipi.DENEME.value
    return None


def _katalog_anahtar_haritasi(katalog: Optional[Iterable]) -> dict:
    """{normalize edilmiş ad/kod: kanonik ad} sözlüğü üretir.

    `katalog` verilmezse (ör. DB erişimi olmayan bağlam) VARSAYILAN_URUN_KATALOGU kullanılır.
    `katalog`, `{"code":..., "name":...}` sözlük listesi ya da düz string listesi olabilir.
    """
    kaynak = list(katalog) if katalog else VARSAYILAN_URUN_KATALOGU
    harita: dict = {}
    for giris in kaynak:
        if isinstance(giris, dict):
            ad = giris.get("name") or giris.get("code")
            kod = giris.get("code")
        else:
            ad, kod = str(giris), None
        if ad:
            harita[_anahtar(ad)] = ad
        if kod:
            harita.setdefault(_anahtar(kod), ad or kod)
    return harita


def urun_adi_coz(deger, katalog: Optional[Iterable] = None) -> Optional[str]:
    """Case/boşluk farkını yok sayarak katalogdaki KANONİK ürün adını döndürür; yoksa None."""
    if not deger:
        return None
    return _katalog_anahtar_haritasi(katalog).get(_anahtar(deger))


def en_yakin_urun_adi(deger, katalog: Optional[Iterable] = None, esik: float = 0.62) -> Optional[str]:
    """Fonetik/STT kaynaklı yazım farkı olan bir ürün adını en yakın katalog ürününe eşler.

    Örn: 'piri ey ay' -> 'Piri AI', 'pdk şef' -> 'Piri Keşif Aracı'.
    Hiçbir ürüne yeterince benzemiyorsa None döner; böylece AI'nın uydurduğu,
    kataloğa hiç benzemeyen ürün adları elenmiş olur (halüsinasyon engeli).
    """
    tam = urun_adi_coz(deger, katalog)
    if tam:
        return tam
    anahtar = _anahtar(deger)
    if not anahtar:
        return None
    harita = _katalog_anahtar_haritasi(katalog)
    en_iyi_ad, en_iyi_skor = None, 0.0
    for aday_anahtar, kanonik_ad in harita.items():
        skor = SequenceMatcher(None, anahtar, aday_anahtar).ratio()
        if skor > en_iyi_skor:
            en_iyi_skor, en_iyi_ad = skor, kanonik_ad
    return en_iyi_ad if en_iyi_skor >= esik else None


def urunleri_filtrele(adlar, katalog: Optional[Iterable] = None, fuzzy: bool = True) -> list:
    """Katalogda karşılığı olmayan ürün adlarını sessizce eler (ValidationError FIRLATMAZ).

    - `fuzzy=True` iken fonetik/yazım farkı olan adlar (ör. 'piri ey ay') en
      yakın katalog ürününe otomatik eşlenir (ör. 'Piri AI').
    - Hiçbir ürüne (tam ya da fonetik olarak) benzemeyen adlar listeden
      düşürülür — bu, AI'nın kendi kendine uydurduğu ürünlerin veritabanına
      kaydedilmesini engeller.
    """
    if not adlar:
        return []
    if isinstance(adlar, str):
        adlar = [p.strip() for p in adlar.replace(";", ",").split(",") if p.strip()]
    if not isinstance(adlar, (list, tuple)):
        return []
    sonuc: list = []
    gorulen: set = set()
    for ad in adlar:
        ad = str(ad or "").strip()
        if not ad or ad.lower() in ("null", "none", "-", "yok"):
            continue
        kanonik = urun_adi_coz(ad, katalog)
        if not kanonik and fuzzy:
            kanonik = en_yakin_urun_adi(ad, katalog)
        if not kanonik:
            continue
        anahtar = kanonik.casefold()
        if anahtar in gorulen:
            continue
        gorulen.add(anahtar)
        sonuc.append(kanonik)
    return sonuc


_TR_KATLA = str.maketrans({
    "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u",
    "â": "a", "î": "i", "û": "u",
    "Ç": "c", "Ğ": "g", "İ": "i", "I": "i", "Ö": "o", "Ş": "s", "Ü": "u",
})

# Kod -> STT/fonetik takma adlar. Kısa ve çakışan kökler (ör. yalnız 'piri') YOK;
# aksi halde 'Piri AI' geçen metin 'Piri Keşif Aracı'yı da işaretlerdi.
_STT_URUN_TAKMA = {
    "PIRI_AI": ("piri ai", "piri aı", "pire ai", "piri ey ay", "piriay"),
    "PIRI": ("piri keşif", "piri kesif", "keşif aracı", "kesif araci", "pdk şef", "pdk sef"),
    "CHATBOT": ("chatbot", "chat bot", "sohbet botu", "chat-bot"),
}


def _katla(s: str) -> str:
    return str(s or "").translate(_TR_KATLA).casefold()


def _alnum_katla(s: str) -> str:
    return "".join(ch for ch in _katla(s) if ch.isalnum())


def _ipucu_metinde_mi(katlamali_metin: str, alnum_metin: str, ipucu: str) -> bool:
    ipucu = str(ipucu or "").strip()
    if not ipucu:
        return False
    k = _katla(ipucu)
    a = _alnum_katla(ipucu)
    if " " in k:
        return (len(k) >= 5 and k in katlamali_metin) or (len(a) >= 6 and a in alnum_metin)
    if len(a) < 6:
        return False
    return k in katlamali_metin or a in alnum_metin


def _urun_arama_ipuclari(ad: str, kod: str) -> list:
    ipuclari = []
    if ad:
        ipuclari.append(ad)
        kelimeler = [w for w in _katla(ad).split() if w]
        if len(kelimeler) >= 2:
            ipuclari.append(" ".join(kelimeler[:2]))
        elif kelimeler and len(kelimeler[0]) >= 6:
            ipuclari.append(kelimeler[0])
    if kod:
        takmalar = _STT_URUN_TAKMA.get(str(kod).strip().upper()) or ()
        ipuclari.extend(takmalar)
        if len(_alnum_katla(kod)) >= 6:
            ipuclari.append(kod)
    temiz = []
    gorulen = set()
    for ipucu in ipuclari:
        anahtar = _alnum_katla(ipucu)
        if not anahtar or anahtar in gorulen:
            continue
        gorulen.add(anahtar)
        temiz.append(ipucu)
    return temiz


def metinden_katalog_urunleri(metin, katalog: Optional[Iterable] = None) -> list:
    """Ham görüşme metninde geçen katalog ürünlerini (fonetik/STT farkı dahil) döndürür.

    Tam ad, ilk iki kelime ('piri ai', 'piri kesif', 'chat bot') ve bilinen
    STT takma adları aranır. Yalnız 'piri'
    gibi kısa kökler kullanılmaz; Piri AI ile Piri Keşif Aracı karışmaz.
    """
    ham = str(metin or "").strip()
    if not ham:
        return []
    katlamali = _katla(ham)
    alnum = _alnum_katla(ham)
    kaynak = list(katalog) if katalog else VARSAYILAN_URUN_KATALOGU
    bulunan = []
    gorulen = set()
    for giris in kaynak:
        if isinstance(giris, dict):
            ad = str(giris.get("name") or "").strip()
            kod = str(giris.get("code") or "").strip()
        else:
            ad, kod = str(giris).strip(), ""
        etiket = ad or kod
        if not etiket:
            continue
        anahtar = etiket.casefold()
        if anahtar in gorulen:
            continue
        for ipucu in _urun_arama_ipuclari(ad, kod):
            if _ipucu_metinde_mi(katlamali, alnum, ipucu):
                bulunan.append(etiket)
                gorulen.add(anahtar)
                break
    return bulunan
