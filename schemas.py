from datetime import date
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, field_validator

from enums import GorusmeDurumu, SurecTipi, en_yakin_urun_adi, urun_adi_coz, urunleri_filtrele


def _eposta_normalize(deger) -> Optional[str]:
    if deger is None:
        return None
    metin = str(deger).strip()
    return metin or None


# ─── Kimlik Doğrulama (Auth) Şemaları ─────────────────────────────────────────

class LoginRequest(BaseModel):
    """Kullanıcı giriş isteği."""
    kullanici_adi: str
    sifre: str


class Token(BaseModel):
    """Başarılı giriş sonrası dönen JWT token yanıtı."""
    access_token: str
    token_type: str = "bearer"
    kullanici_adi: str
    ad_soyad: Optional[str] = None
    role: str = "user"
    id: Optional[int] = None
    company_id: Optional[int] = None


class TokenData(BaseModel):
    """JWT payload içindeki kullanıcı verisi."""
    kullanici_adi: Optional[str] = None


class UserCreate(BaseModel):
    """Admin panelinde yeni personel eklemek için kullanılır."""
    kullanici_adi: str
    sifre: str
    email: str
    ad_soyad: Optional[str] = None
    role: str = "user"
    company_id: Optional[int] = None

    @field_validator("email", mode="before")
    @classmethod
    def _email_temizle(cls, deger):
        return _eposta_normalize(deger)

    @field_validator("email")
    @classmethod
    def _email_format(cls, deger):
        if not deger:
            raise ValueError("E-posta adresi zorunludur.")
        if "@" not in deger or "." not in deger.split("@")[-1]:
            raise ValueError("Geçerli bir e-posta adresi girin.")
        return deger.lower()


class UserRegister(BaseModel):
    """Özgür kayıt — herkes kendi hesabını açabilir; rol her zaman 'user'."""
    kullanici_adi: str
    sifre: str
    ad_soyad: Optional[str] = None
    email: Optional[str] = None

    @field_validator("email", mode="before")
    @classmethod
    def _email_temizle(cls, deger):
        return _eposta_normalize(deger)


class SifreDegistir(BaseModel):
    """Oturum açmış kullanıcının kendi şifresini güncellemesi."""
    mevcut_sifre: str
    yeni_sifre: str

    @field_validator("yeni_sifre")
    @classmethod
    def _yeni_sifre_uzunluk(cls, deger):
        if not deger or len(deger) < 4:
            raise ValueError("Yeni şifre en az 4 karakter olmalıdır.")
        return deger


class ProfilGuncelle(BaseModel):
    """Oturum açmış kullanıcının görünen adını güncellemesi (kullanıcı adı sabit)."""
    ad_soyad: str

    @field_validator("ad_soyad")
    @classmethod
    def _ad_soyad_dogrula(cls, deger):
        ad = (deger or "").strip()
        if not ad:
            raise ValueError("Ad soyad boş olamaz.")
        if len(ad) > 255:
            raise ValueError("Ad soyad en fazla 255 karakter olabilir.")
        return ad


class UserOut(BaseModel):
    """Kullanıcı bilgisi — şifre_hash HİÇBİR ZAMAN döndürülmez."""
    id: int
    kullanici_adi: str
    ad_soyad: Optional[str] = None
    role: str
    company_id: Optional[int] = None
    email: Optional[str] = None
    created_at: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class CompanyCreate(BaseModel):
    name: str


class CompanyOut(BaseModel):
    id: int
    name: str
    created_at: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)




class KurumGuncelle(BaseModel):
    yeni_ad: Optional[str] = None
    yeni_tip: Optional[str] = None


class InstitutionCreate(BaseModel):
    name: str
    type: Optional[str] = "UNIVERSITE"


class AIParsedData(BaseModel):
    kurum_adi: str
    urun_kodu: str
    durum: str
    abonelik_tipi: Optional[str] = None
    baslangic_tarihi: Optional[date] = None
    bitis_tarihi: Optional[date] = None
    egitim_tipi: str
    aksiyon_notu: str
    genel_not: str
    ham_ses_metni: str


class HamMetinIstek(BaseModel):
    metin: str


class AnalyzeTextRequest(BaseModel):
    """speech_to_text ile cihazda üretilen nihai canlı transkript metni.

    Ses dosyası artık backend'e hiç gönderilmiyor; Flutter yalnızca bu metni yollar.
    """

    text: str


class GorevOgesi(BaseModel):
    """Görüşmeden çıkarılan TEK bir aksiyon görevi.

    `AIAnalysisResult.gorevler` artık düz bir string listesi DEĞİL, her biri
    kendi objesi olan bir öğe listesidir (ör. `{"task": "..."}`). Bu sayede
    bir görüşmeden çıkan BİRDEN FAZLA görev her zaman ayrı birer madde
    olarak modellenir ve ileride görev başına ek alan (ör. tarih, öncelik)
    eklenmesi mevcut yapıyı bozmadan mümkün olur.
    """

    model_config = ConfigDict(extra="ignore")

    task: str

    @field_validator("task", mode="before")
    @classmethod
    def _bos_olmasin(cls, deger):
        return str(deger or "").strip()


class AIAnalysisResult(BaseModel):
    """Gemini'den dönen ham JSON'ın katı (strict) Pydantic doğrulama katmanı.

    Bu katman veritabanına kaydetmeden ÖNCE uygulanır ve iki kritik hatayı
    hedefler:

    1. surec_tipi SADECE `enums.SurecTipi` değerlerinden biri olabilir; aksi
       bir değer gelirse ValidationError FIRLATMAK yerine sessizce 'Hiçbiri'ya
       düşürülür (sistemi çökertmeden güvenli varsayılan).
    2. ilgilenilen_urunler / urun_adi, sistemde kayıtlı ürün kataloğuyla
       (fonetik/STT yazım farkları dahil, ör. 'piri ey ay' -> 'Piri AI')
       eşleştirilir; katalogda hiç karşılığı olmayan (AI'nın uydurduğu)
       değerler ValidationError vermeden otomatik olarak listeden düşürülür.

    `katalog` (DB'deki aktif ürün listesi) çağıran taraftan
    `model_validate(veri, context={"katalog": katalog})` ile geçirilir; bu
    sayede `/api/urunler` ile sonradan eklenen ürünler de doğru şekilde
    kabul edilir (mevcut genişletilebilir yapı bozulmaz). Context verilmezse
    `enums.VARSAYILAN_URUN_KATALOGU` kullanılır.
    """

    model_config = ConfigDict(extra="ignore", use_enum_values=True)

    kurum_adi: Optional[str] = None
    kurum_türü: Optional[str] = None
    ilgilenilen_urunler: List[str] = []
    urun_kodu: Optional[str] = None
    urun_adi: Optional[str] = None
    surec_tipi: SurecTipi = SurecTipi.HICBIRI
    baslangic_tarihi: Optional[str] = None
    bitis_tarihi: Optional[str] = None
    egitim_turu: Optional[str] = None
    durum: Optional[str] = None
    aksiyon_adimi: Optional[str] = None
    gelecek_gorusme_tarihi: Optional[str] = None
    gorevler: List[GorevOgesi] = []

    @field_validator("durum", mode="before")
    @classmethod
    def _durum_guvenli(cls, deger):
        """`durum` alanını 'Olumlu' / 'Olumsuz' / 'Karma' / 'Beklemede' dörtlüsüne

        indirger (mevcut `surec_tipi` doğrulamasıyla aynı "güvenli varsayılana
        düş, ValidationError fırlatma" felsefesi). Metinde bir ürün/konu için
        olumlu, başka biri için olumsuz sinyal varsa ya da genel olarak karışık
        geribildirim geçiyorsa AI zaten 'Karma' döndürmelidir; burada sadece
        serbest metin varyasyonları (büyük/küçük harf, 'mixed' vb.) kanonik
        değere normalize edilir. Tanınmayan bir değer gelirse ValidationError
        FIRLATILMAZ, olduğu gibi (strip edilmiş) bırakılır.
        """
        d = str(deger or "").strip()
        if not d:
            return None
        dl = d.casefold()
        if "karma" in dl or "mixed" in dl:
            return GorusmeDurumu.KARMA.value
        if "olumsuz" in dl:
            return GorusmeDurumu.OLUMSUZ.value
        if "olumlu" in dl:
            return GorusmeDurumu.OLUMLU.value
        if "bekle" in dl:
            return GorusmeDurumu.BEKLEMEDE.value
        return d

    @field_validator("gorevler", mode="before")
    @classmethod
    def _gorevler_normalize(cls, deger):
        """`gorevler` alanını KESİNLİKLE bir obje listesine (array) indirger.

        AI'nın tek bir metin veya düz string listesi döndürdüğü ESKİ format
        geriye dönük uyumluluk için hâlâ kabul edilir (her öğe otomatik olarak
        `{"task": "..."}` objesine çevrilir), ama sonuç HER ZAMAN bir liste
        olur — bir görüşmeden çıkan birden fazla görev asla tek bir metne
        sıkıştırılmaz.
        """
        if deger is None:
            return []
        if isinstance(deger, str):
            deger = [p.strip() for p in deger.replace("\n", ";").split(";") if p.strip()]
        if not isinstance(deger, list):
            return []
        normalize_edilmis = []
        for item in deger:
            if isinstance(item, dict):
                metin = (
                    item.get("task")
                    or item.get("gorev")
                    or item.get("baslik")
                    or item.get("aksiyon")
                    or ""
                )
            else:
                metin = item
            metin = str(metin or "").strip()
            if metin:
                normalize_edilmis.append({"task": metin})
        return normalize_edilmis

    @field_validator("surec_tipi", mode="before")
    @classmethod
    def _surec_tipi_guvenli(cls, deger):
        from enums import surec_tipi_esnek_normalize

        return surec_tipi_esnek_normalize(deger)

    @field_validator("ilgilenilen_urunler", mode="before")
    @classmethod
    def _urunleri_dogrula(cls, deger, info):
        katalog = (info.context or {}).get("katalog") if info.context else None
        return urunleri_filtrele(deger, katalog)

    @field_validator("urun_adi", mode="before")
    @classmethod
    def _urun_adi_dogrula(cls, deger, info):
        if not deger:
            return None
        katalog = (info.context or {}).get("katalog") if info.context else None
        return urun_adi_coz(deger, katalog) or en_yakin_urun_adi(deger, katalog)

    @field_validator("urun_kodu", mode="before")
    @classmethod
    def _urun_kodu_dogrula(cls, deger, info):
        if not deger:
            return None
        katalog = (info.context or {}).get("katalog") if info.context else None
        kaynak = list(katalog) if katalog else None
        if not kaynak:
            from enums import VARSAYILAN_URUN_KATALOGU

            kaynak = VARSAYILAN_URUN_KATALOGU
        kodlar = {
            str(u.get("code") or "").casefold()
            for u in kaynak
            if isinstance(u, dict) and u.get("code")
        }
        return deger if str(deger).casefold() in kodlar else None


class ProductCreate(BaseModel):
    code: Optional[str] = None
    name: str
    is_active: Optional[bool] = True
    company_id: Optional[int] = None


class AnalysisManualCreate(BaseModel):
    kurum_adi: str
    urun_kodu: Optional[str] = None
    urun_adi: Optional[str] = None
    durum: Optional[str] = "Beklemede"
    surec_tipi: Optional[str] = "Hiçbiri"
    abonelik_tipi: Optional[str] = None
    ilgilenilen_urunler: Optional[list] = None
    not_icerigi: Optional[str] = None
    kurum_turu: Optional[str] = "UNIVERSITE"


class AnalysisManualUpdate(BaseModel):
    kurum_adi: Optional[str] = None
    urun_kodu: Optional[str] = None
    urun_adi: Optional[str] = None
    durum: Optional[str] = None
    surec_tipi: Optional[str] = None
    abonelik_tipi: Optional[str] = None
    ilgilenilen_urunler: Optional[list] = None
    not_icerigi: Optional[str] = None
    kurum_turu: Optional[str] = None


class TaskCreate(BaseModel):
    """Manuel veya görüşmeye bağlı görev. gorusme_id / analysis_id isteğe bağlıdır."""
    baslik: Optional[str] = None
    description: Optional[str] = None
    due_date: Optional[date] = None
    kurum_adi: Optional[str] = None
    gorusme_id: Optional[int] = None
    analysis_id: Optional[int] = None
    meeting_id: Optional[int] = None
    # Admin oluştururken personel atayabilir; yoksa oluşturan kullanıcıya atanır.
    assigned_user_id: Optional[int] = None
    # Personele atamada zorunlu: çalışan, bu ürünün şirketinden olmalı.
    urun_id: Optional[int] = None

    @field_validator("due_date", mode="before")
    @classmethod
    def bos_tarih(cls, v):
        if v is None or v == "":
            return None
        return v

    @field_validator("assigned_user_id", "urun_id", mode="before")
    @classmethod
    def bos_sayi(cls, v):
        if v is None or v == "":
            return None
        return v

    def baslik_al(self) -> str:
        return ((self.baslik or self.description) or "").strip()

    def gorusme_id_al(self) -> Optional[int]:
        return self.analysis_id or self.gorusme_id or self.meeting_id


class TaskUpdate(BaseModel):
    baslik: Optional[str] = None
    kurum_adi: Optional[str] = None
    tamamlandi: Optional[bool] = None


class TaskAssign(BaseModel):
    """Admin görev ataması — yalnızca assigned_user_id."""
    assigned_user_id: int


class BildirimOut(BaseModel):
    id: int
    title: str
    body: Optional[str] = None
    actor_name: Optional[str] = None
    task_id: Optional[int] = None
    kind: str = "gorev_atama"
    is_read: bool = False
    created_at: Optional[str] = None


class CihazTokenIn(BaseModel):
    """Mobil uygulamanın FCM kayıt jetonu."""
    token: str
    platform: Optional[str] = "android"
