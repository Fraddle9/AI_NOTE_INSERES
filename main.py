import json
import logging
import os
import re
import time
from datetime import date, datetime, time as dtime
from decimal import Decimal
from pathlib import Path
from typing import Optional
from pydantic import ValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse, Response
from fastapi.staticfiles import StaticFiles
from fastapi import FastAPI, Depends, HTTPException, Query, status, BackgroundTasks
from sqlalchemy import and_, func, inspect, or_, text
from sqlalchemy.orm import Session
from sqlalchemy.orm.attributes import flag_modified
import models
import schemas
from database import engine, get_db, Base, ensure_schema
import ai_service
import enums
from product_seed import seed_inseres_products, aktif_urun_katalogu
from auth import get_current_user, sifreyi_hashle, sifreyi_dogrula, kullanici_token_olustur, require_admin
from services.email_service import send_assignment_email, kullanici_eposta_adresi
from services.fcm_service import send_assignment_push
from app.core.config import fcm_ayarlari

GECERSIZ_YANIT = "Sunucudan geçersiz veya boş yanıt alındı"
TRANSKRIPT_MODELI = (
    "Flutter Native STT (speech_to_text paketi, cihaz üstü tanıma) — "
    "ses dosyası backend'e HİÇ gönderilmiyor"
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ainote")

# Ortam: development (varsayılan) | production
# ALLOW_DEMO_SEED=true  → başlangıçta demo kullanıcı/şirket seed (dev için)
# ALLOW_PUBLIC_REGISTER=true → /register açık (varsayılan: kapalı)
# JWT_SECRET_KEY → production'da zorunlu
AINOTE_ENV = os.getenv("AINOTE_ENV", "development").strip().lower()


def _env_bool(anahtar: str, varsayilan: bool) -> bool:
    ham = os.getenv(anahtar)
    if ham is None:
        return varsayilan
    return ham.strip().lower() in ("1", "true", "yes", "on")


ALLOW_DEMO_SEED = _env_bool(
    "ALLOW_DEMO_SEED",
    varsayilan=AINOTE_ENV != "production",
)
ALLOW_PUBLIC_REGISTER = _env_bool("ALLOW_PUBLIC_REGISTER", varsayilan=False)

app = FastAPI(title="GMZ Core API", version="1.0.0")
_cors_raw = (os.getenv("CORS_ORIGINS") or "*").strip()
if _cors_raw == "*":
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    _cors_list = [o.strip() for o in _cors_raw.split(",") if o.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_list or ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.on_event("startup")
def startup_db():
    if AINOTE_ENV == "production" and not (os.getenv("JWT_SECRET_KEY") or "").strip():
        raise RuntimeError("JWT_SECRET_KEY production ortamında tanımlanmalıdır.")
    if not (os.getenv("JWT_SECRET_KEY") or "").strip():
        logger.warning(
            "JWT_SECRET_KEY tanımlı değil; yalnızca geliştirme için geçici anahtar kullanılıyor."
        )
    Base.metadata.create_all(bind=engine)
    ensure_schema()
    db = next(get_db())
    try:
        sirket_id = _seed_varsayilan_sirket(db)
        seed_inseres_products(db, company_id=sirket_id)
        if ALLOW_DEMO_SEED:
            _seed_admin_kullanici(db, sirket_id)
            _seed_satici_kullanici(db, sirket_id)
            _seed_demo_sirket_calisanlari(db, sirket_id)
        else:
            logger.info("Demo kullanıcı seed atlandı (ALLOW_DEMO_SEED=false).")
    finally:
        db.close()
    print(f"Transkript için şu model kullanılıyor: {TRANSKRIPT_MODELI}")
    print("CRM analizi için Gemini (gemini-3.6-flash) kullanılıyor. "
          "/api/analyze-text uç noktası JSON gövdede {'text': '...'} bekler.")


def _seed_varsayilan_sirket(db: Session) -> Optional[int]:
    """Varsayılan şirket 'Inseres' yoksa oluşturur; id döner."""
    mevcut = db.query(models.Company).filter(models.Company.name == "Inseres").first()
    if not mevcut:
        mevcut = models.Company(name="Inseres")
        db.add(mevcut)
        db.commit()
        db.refresh(mevcut)
        print("[Seed] Varsayılan şirket 'Inseres' oluşturuldu.")
    if mevcut.id:
        db.query(models.Product).filter(models.Product.company_id.is_(None)).update(
            {"company_id": mevcut.id}, synchronize_session=False
        )
        db.query(models.User).filter(models.User.company_id.is_(None)).update(
            {"company_id": mevcut.id}, synchronize_session=False
        )
        db.commit()
    return mevcut.id if mevcut else None


def _seed_admin_kullanici(db: Session, sirket_id: Optional[int] = None) -> None:
    """Uygulama ilk başladığında 'admin' kullanıcısı yoksa oluşturur (şifre: 123456, role: admin)."""
    mevcut = db.query(models.User).filter(
        models.User.kullanici_adi == "admin"
    ).first()
    if not mevcut:
        admin = models.User(
            kullanici_adi="admin",
            sifre_hash=sifreyi_hashle("123456"),
            ad_soyad="Admin",
            role="admin",
            company_id=sirket_id,
            email="admin@inseres.com",
        )
        db.add(admin)
        db.commit()
        if ALLOW_DEMO_SEED:
            logger.info("[Seed] 'admin' kullanıcısı oluşturuldu (rol: admin).")
    else:
        guncellendi = False
        if (mevcut.ad_soyad or "").strip() in ("Admin Kullanıcı", ""):
            mevcut.ad_soyad = "Admin"
            guncellendi = True
        if sirket_id and not getattr(mevcut, "company_id", None):
            mevcut.company_id = sirket_id
            guncellendi = True
        if not (getattr(mevcut, "email", None) or "").strip():
            mevcut.email = "admin@inseres.com"
            guncellendi = True
        if guncellendi:
            db.commit()
            logger.info("[Seed] 'admin' kullanıcısı güncellendi.")


def _seed_satici_kullanici(db: Session, sirket_id: Optional[int] = None) -> None:
    """Test için standart kullanıcı 'satici1' yoksa oluşturur (şifre: satici123, role: user)."""
    mevcut = db.query(models.User).filter(
        models.User.kullanici_adi == "satici1"
    ).first()
    if not mevcut:
        satici = models.User(
            kullanici_adi="satici1",
            sifre_hash=sifreyi_hashle("satici123"),
            ad_soyad="Test Satıcı",
            role="user",
            company_id=sirket_id,
            email="satici1@inseres.com",
        )
        db.add(satici)
        db.commit()
        if ALLOW_DEMO_SEED:
            logger.info("[Seed] 'satici1' test kullanıcısı oluşturuldu.")
    else:
        guncellendi = False
        if sirket_id and not getattr(mevcut, "company_id", None):
            mevcut.company_id = sirket_id
            guncellendi = True
        if not (getattr(mevcut, "email", None) or "").strip():
            mevcut.email = "satici1@inseres.com"
            guncellendi = True
        if guncellendi:
            db.commit()
            logger.info("[Seed] 'satici1' kullanıcısı güncellendi.")


def _sirket_getir_veya_olustur(db: Session, ad: str) -> models.Company:
    ad = (ad or "").strip()
    mevcut = db.query(models.Company).filter(models.Company.name == ad).first()
    if mevcut:
        return mevcut
    sirket = models.Company(name=ad)
    db.add(sirket)
    db.commit()
    db.refresh(sirket)
    print(f"[Seed] Şirket oluşturuldu: {ad}")
    return sirket


def _kullanici_yoksa_ekle(
    db: Session,
    *,
    kullanici_adi: str,
    sifre: str,
    ad_soyad: str,
    email: str,
    company_id: Optional[int],
    role: str = "user",
) -> models.User:
    mevcut = db.query(models.User).filter(
        models.User.kullanici_adi == kullanici_adi
    ).first()
    if mevcut:
        guncellendi = False
        if company_id and not getattr(mevcut, "company_id", None):
            mevcut.company_id = company_id
            guncellendi = True
        if email and not (getattr(mevcut, "email", None) or "").strip():
            mevcut.email = email
            guncellendi = True
        if guncellendi:
            db.commit()
        return mevcut
    u = models.User(
        kullanici_adi=kullanici_adi,
        sifre_hash=sifreyi_hashle(sifre),
        ad_soyad=ad_soyad,
        role=role,
        company_id=company_id,
        email=email,
    )
    db.add(u)
    db.commit()
    logger.info("[Seed] Kullanıcı oluşturuldu: %s", kullanici_adi)
    return u


def _urun_sirkete_bagla(db: Session, code: str, name: str, company_id: int) -> models.Product:
    kod = code.strip().upper()
    urun = db.query(models.Product).filter(models.Product.code == kod).first()
    if urun:
        urun.name = name
        urun.is_active = True
        urun.company_id = company_id
    else:
        urun = models.Product(
            code=kod,
            name=name,
            is_active=True,
            company_id=company_id,
        )
        db.add(urun)
    db.commit()
    db.refresh(urun)
    return urun


def _seed_demo_sirket_calisanlari(db: Session, inseres_id: Optional[int]) -> None:
    """Inseres için ek test personeli basar. Başka şirket oluşturulmaz."""
    if not inseres_id:
        return
    for kadi, ad, mail in (
        ("satici2", "Ayşe Demir", "satici2@inseres.com"),
        ("satici3", "Mehmet Kaya", "satici3@inseres.com"),
        ("satici4", "Elif Yıldız", "satici4@inseres.com"),
        ("uzman1", "Can Özkan", "uzman1@inseres.com"),
    ):
        _kullanici_yoksa_ekle(
            db,
            kullanici_adi=kadi,
            sifre="satici123",
            ad_soyad=ad,
            email=mail,
            company_id=inseres_id,
        )
    gamze = _kullanici_yoksa_ekle(
        db,
        kullanici_adi="gamze",
        sifre="gamze123",
        ad_soyad="Gamze",
        email="gamze@inseres.com",
        company_id=inseres_id,
    )
    gamze.ad_soyad = "Gamze"
    gamze.email = "gamze@inseres.com"
    gamze.company_id = inseres_id
    db.commit()

def _is_admin(user: models.User) -> bool:
    return (getattr(user, "role", None) or "user") == "admin"


def _erisim_yok():
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Bu kayda erişim yetkiniz yok.",
    )


def _analiz_erisim_kontrol(analiz: models.Analysis, current_user: models.User) -> None:
    if _is_admin(current_user):
        return
    if analiz.user_id != current_user.id:
        _erisim_yok()


def _gorev_erisim_kontrol(db: Session, gorev: models.Task, current_user: models.User) -> None:
    if _is_admin(current_user):
        return
    if getattr(gorev, "user_id", None) == current_user.id:
        return
    if getattr(gorev, "assigned_user_id", None) == current_user.id:
        return
    if gorev.analysis_id:
        analiz = db.query(models.Analysis).filter(models.Analysis.id == gorev.analysis_id).first()
        if analiz and analiz.user_id == current_user.id:
            return
    _erisim_yok()


def _kullanici_analiz_ids(db: Session, current_user: models.User) -> list:
    return [
        a.id
        for a in db.query(models.Analysis.id)
        .filter(
            models.Analysis.user_id == current_user.id,
            models.Analysis.is_deleted.is_(False),
        )
        .all()
    ]


def _kullanici_kurum_ids(db: Session, current_user: models.User) -> list:
    return [
        r[0]
        for r in db.query(models.Analysis.institution_id)
        .filter(
            models.Analysis.user_id == current_user.id,
            models.Analysis.is_deleted.is_(False),
            models.Analysis.institution_id.isnot(None),
        )
        .distinct()
        .all()
    ]


def _kurum_erisim_kontrol(
    db: Session, kurum_id: Optional[int], current_user: models.User
) -> None:
    """Giriş yapmış her kullanıcı tüm kurumları ve detayını görüntüleyebilir.

    Ekleme / düzenleme / silme ayrı uçlarda `require_admin` ile korunur.
    """
    if current_user is None:
        _erisim_yok()
    if not kurum_id:
        _erisim_yok()


def _gorev_su_an_bende_kosulu(current_user: models.User):
    """Görev şu an bu kullanıcıya aitse True.

    Başkasına atandıysa (assigned_user_id başka biri) görüşmeyi yapan kişide
    kalmaz. Atama yoksa oluşturan (user_id) sahibidir.
    """
    return or_(
        models.Task.assigned_user_id == current_user.id,
        and_(
            models.Task.assigned_user_id.is_(None),
            models.Task.user_id == current_user.id,
        ),
    )


def _aktif_gorev_sayisi(db: Session, current_user: models.User) -> int:
    """Tamamlanmamış görev sayısı — kullanıcı listesiyle aynı kapsam mantığı."""
    sorgu = _aktif(db.query(models.Task), models.Task).filter(
        models.Task.is_done.is_(False)
    )
    if _is_admin(current_user):
        return sorgu.count()
    return sorgu.filter(_gorev_su_an_bende_kosulu(current_user)).count()


def _kullanici_olustur(
    db: Session,
    kullanici_adi: str,
    sifre: str,
    ad_soyad: Optional[str] = None,
    role: str = "user",
    company_id: Optional[int] = None,
    email: Optional[str] = None,
) -> models.User:
    kadi = (kullanici_adi or "").strip()
    if not kadi:
        raise HTTPException(status_code=400, detail="Kullanıcı adı zorunludur.")
    if not sifre or len(sifre) < 4:
        raise HTTPException(status_code=400, detail="Şifre en az 4 karakter olmalıdır.")
    mevcut = db.query(models.User).filter(models.User.kullanici_adi == kadi).first()
    if mevcut:
        raise HTTPException(status_code=409, detail="Bu kullanıcı adı zaten alınmış.")
    rol = role if role in ("admin", "user") else "user"
    eposta = (email or "").strip().lower() or None
    if eposta:
        if "@" not in eposta:
            raise HTTPException(status_code=400, detail="Geçerli bir e-posta adresi girin.")
        ayni_mail = db.query(models.User).filter(models.User.email == eposta).first()
        if ayni_mail:
            raise HTTPException(status_code=409, detail="Bu e-posta adresi zaten kayıtlı.")
    if company_id is not None:
        sirket = db.query(models.Company).filter(models.Company.id == company_id).first()
        if not sirket:
            raise HTTPException(status_code=400, detail="Seçilen şirket bulunamadı.")
    elif company_id is None:
        sirket = db.query(models.Company.id).order_by(models.Company.id.asc()).first()
        company_id = sirket[0] if sirket else None
    yeni = models.User(
        kullanici_adi=kadi,
        sifre_hash=sifreyi_hashle(sifre),
        ad_soyad=(ad_soyad or "").strip() or None,
        role=rol,
        company_id=company_id,
        email=eposta,
    )
    db.add(yeni)
    db.commit()
    db.refresh(yeni)
    return yeni


def _aktif(query, model):
    if hasattr(model, "is_deleted"):
        return query.filter(model.is_deleted.is_(False))
    return query


def _kurum_adi_al(kurum) -> Optional[str]:
    if not kurum:
        return None
    ad = (getattr(kurum, "name", None) or "").strip()
    return ad or None


def _kurum_dict(kurum) -> dict:
    """Kurum nesnesini JSON uyumlu sözlüğe çevirir (FK yok, yalnızca serileştirme)."""
    return {
        "id": kurum.id,
        "kurum_id": kurum.id,
        "name": kurum.name,
        "kurum_adi": kurum.name,
        "type": kurum.type,
        "kurum_turu": kurum.type,
        "created_at": kurum.created_at.isoformat() if getattr(kurum, "created_at", None) else None,
        "eklenme_tarihi": kurum.created_at.isoformat() if getattr(kurum, "created_at", None) else None,
    }


def _urun_adi_coz(db: Session, kod: Optional[str], verilen_ad: Optional[str] = None) -> Optional[str]:
    ad = (verilen_ad or "").strip()
    if ad:
        return ad
    kod = (kod or "").strip()
    if not kod:
        return None
    urun = db.query(models.Product).filter(models.Product.code == kod).first()
    return urun.name if urun else kod


def _durum_normalize(durum: Optional[str]) -> Optional[str]:
    if not durum:
        return durum
    d = durum.strip().lower()
    if "karma" in d or "mixed" in d:
        return "Karma"
    if "olumsuz" in d or d in ("red", "iptal", "pasif"):
        return "Olumsuz"
    if "olumlu" in d or d in ("aktif", "onay", "tam_erisim"):
        return "Olumlu"
    if "bekle" in d:
        return "Beklemede"
    return durum.strip()


def _surec_tipi_normalize(deger: Optional[str]) -> str:
    """Süreç tipini her zaman üç sabit değerden birine indirger:
    'Deneme', 'Abonelik' veya 'Hiçbiri'."""
    return enums.surec_tipi_esnek_normalize(deger)


def _abonelik_tipi_normalize(deger: Optional[str]) -> str:
    """Eski ad; surec_tipi ile aynı üç değeri döndürür."""
    return _surec_tipi_normalize(deger)


def _ilgilenilen_urunler_normalize(deger, urun_adi: Optional[str] = None) -> list:
    adlar = []
    if isinstance(deger, str):
        deger = [p.strip() for p in deger.replace(";", ",").split(",") if p.strip()]
    if isinstance(deger, list):
        for item in deger:
            ad = str(item or "").strip()
            if ad and ad.lower() not in ("null", "none", "-", "yok"):
                adlar.append(ad)
    ekstra = (urun_adi or "").strip()
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


def _katalogdan_urun_yakala(metin: Optional[str], db: Session) -> list:
    if not (metin or "").strip():
        return []
    urunler = (
        db.query(models.Product)
        .filter(models.Product.is_active.is_(True))
        .all()
    )
    katalog = [{"code": u.code, "name": u.name} for u in urunler]
    return enums.metinden_katalog_urunleri(metin, katalog)


def _urun_kodu_esle(db: Session, kod: Optional[str], ad: Optional[str]) -> Optional[str]:
    kod = (kod or "").strip() or None
    if kod:
        urun = db.query(models.Product).filter(models.Product.code == kod).first()
        if urun:
            return urun.code
        kod = None
    ad = (ad or "").strip()
    if not ad:
        return None
    urun = (
        db.query(models.Product)
        .filter(models.Product.is_active.is_(True))
        .filter(models.Product.name.ilike(ad))
        .first()
    )
    if urun:
        return urun.code
    return None


def _analiz_dict(analiz: models.Analysis) -> dict:
    ai = analiz.ai_json if isinstance(analiz.ai_json, dict) else {}
    # KRİTİK: "not_icerigi" (görüşme notu/transkript) HER ZAMAN kullanıcının
    # orijinal ham metnidir (speech_to_text çıktısı ya da manuel giriş).
    # Gemini'nin ürettiği herhangi bir özet/yeniden yazım burada ASLA kullanılmaz.
    not_icerigi = (analiz.ham_metin or "").strip()
    surec = _surec_tipi_normalize(
        getattr(analiz, "surec_tipi", None)
        or analiz.abonelik_tipi
        or ai.get("surec_tipi")
        or ai.get("abonelik_tipi")
    )
    urunler = _ilgilenilen_urunler_normalize(
        getattr(analiz, "ilgilenilen_urunler", None) or ai.get("ilgilenilen_urunler"),
        analiz.urun_adi or ai.get("urun_adi") or analiz.urun_kodu,
    )
    urun_adi = analiz.urun_adi or (urunler[0] if urunler else None) or ai.get("urun_adi") or analiz.urun_kodu
    return {
        "id": analiz.id,
        "user_id": analiz.user_id,
        "kurum_id": analiz.institution_id,
        "kurum_adi": analiz.kurum_adi,
        "urun_kodu": analiz.urun_kodu,
        "urun_adi": urun_adi,
        "ilgilenilen_urunler": urunler,
        "durum": _durum_normalize(analiz.durum) or analiz.durum,
        "surec_tipi": surec,
        "abonelik_tipi": surec,
        "not_icerigi": not_icerigi,
        "kaynak": analiz.kaynak or "ai",
        "tarih": analiz.created_at.isoformat() if analiz.created_at else None,
    }


def _kullanici_etiket_map(db: Session, user_ids) -> dict:
    """id → Ad Soyad (yoksa kullanıcı adı). Toplu sorgu; N+1 yok."""
    ids = [i for i in set(user_ids or []) if i]
    if not ids:
        return {}
    etiketler = {}
    for u in db.query(models.User).filter(models.User.id.in_(ids)).all():
        etiketler[u.id] = (u.ad_soyad or "").strip() or u.kullanici_adi
    return etiketler


def _kullanici_sirket_id(db: Session, user_id: Optional[int]) -> Optional[int]:
    if not user_id:
        return None
    u = db.query(models.User.company_id).filter(models.User.id == user_id).first()
    return u[0] if u else None


def _urun_sirket_id(db: Session, urun_kodu: Optional[str] = None) -> Optional[int]:
    kod = (urun_kodu or "").strip()
    if not kod:
        return None
    p = db.query(models.Product.company_id).filter(models.Product.code == kod).first()
    return p[0] if p else None


def _gorev_sirket_id_coz(db: Session, gorev: models.Task) -> Optional[int]:
    """FK eklemeden görevin şirketini çöz: kayıt → oluşturan → görüşme sahibi."""
    cid = getattr(gorev, "company_id", None)
    if cid:
        return int(cid)
    cid = _kullanici_sirket_id(db, getattr(gorev, "user_id", None))
    if cid:
        return int(cid)
    analiz_id = getattr(gorev, "analysis_id", None)
    if analiz_id:
        row = (
            db.query(models.Analysis.user_id)
            .filter(models.Analysis.id == analiz_id)
            .first()
        )
        if row:
            cid = _kullanici_sirket_id(db, row[0])
            if cid:
                return int(cid)
    cid = _kullanici_sirket_id(db, getattr(gorev, "assigned_user_id", None))
    return int(cid) if cid else None


def _gorev_kisa_dict(db: Session, g: models.Task, etiketler: Optional[dict] = None) -> dict:
    """Görüşme detayındaki AI görev satırı. Yeni FK eklemez."""
    atanan_id = g.assigned_user_id or g.user_id
    ad = None
    if atanan_id:
        ad = (etiketler or {}).get(atanan_id)
    return {
        "id": g.id,
        "baslik": g.title,
        "tamamlandi": bool(g.is_done),
        "kaynak": g.source or "ai",
        "kurum_adi": (getattr(g, "kurum_adi", None) or "").strip() or None,
        "assigned_user_id": atanan_id,
        "assigned_user_name": ad,
        "user_id": g.user_id,
        "company_id": _gorev_sirket_id_coz(db, g),
    }


ATAMA_SIRKET_HATASI = (
    "Bu kullanıcı farklı bir şirkete ait olduğu için bu göreve atanamaz."
)


def _atama_sirket_kontrol(db: Session, gorev: models.Task, hedef: models.User) -> None:
    """Güvenlik duvarı: görev şirketi == atanacak kullanıcının şirketi.

    Farklı şirket veya eksik şirket bilgisinde HTTP 400; veritabanına yazılmaz.
    Yeni FK eklenmez; company_id uygulama katmanında çözülür.
    """
    gorev_sirket = _gorev_sirket_id_coz(db, gorev)
    hedef_sirket = getattr(hedef, "company_id", None)

    if gorev_sirket is not None and getattr(gorev, "company_id", None) is None:
        gorev.company_id = gorev_sirket

    if gorev_sirket is None:
        raise HTTPException(
            status_code=400,
            detail="Bu görevin şirket bilgisi eksik olduğu için atama yapılamaz.",
        )
    if hedef_sirket is None:
        raise HTTPException(status_code=400, detail=ATAMA_SIRKET_HATASI)
    if int(gorev_sirket) != int(hedef_sirket):
        raise HTTPException(status_code=400, detail=ATAMA_SIRKET_HATASI)


def _sirket_ad_haritasi(db: Session, sirket_ids) -> dict:
    ids = [i for i in set(sirket_ids or []) if i]
    if not ids:
        return {}
    return {
        s.id: s.name
        for s in db.query(models.Company).filter(models.Company.id.in_(ids)).all()
    }


def _kullanici_public_dict(u: models.User, sirket_adi: Optional[str] = None) -> dict:
    return {
        "id": u.id,
        "kullanici_adi": u.kullanici_adi,
        "ad_soyad": u.ad_soyad,
        "role": getattr(u, "role", "user") or "user",
        "company_id": getattr(u, "company_id", None),
        "company_name": sirket_adi,
        "email": getattr(u, "email", None),
        "created_at": u.created_at.isoformat() if u.created_at else None,
    }


def _kullanici_adi_al(db: Session, user_id: Optional[int]) -> Optional[str]:
    """user_id → kullanici_adi çözümler; önbelleksiz, sadece admin listesi için."""
    if not user_id:
        return None
    u = db.query(models.User.ad_soyad, models.User.kullanici_adi).filter(
        models.User.id == user_id
    ).first()
    if not u:
        return None
    return (u.ad_soyad or "").strip() or u.kullanici_adi or None


@app.post("/login", response_model=schemas.Token, tags=["auth"])
def login(istek: schemas.LoginRequest, db: Session = Depends(get_db)):
    """
    Kullanıcı girişi. Başarılı olursa JWT Bearer token döner.

    Gövde:
        kullanici_adi: str
        sifre: str
    """
    kullanici = (
        db.query(models.User)
        .filter(models.User.kullanici_adi == istek.kullanici_adi)
        .first()
    )
    if not kullanici or not sifreyi_dogrula(istek.sifre, kullanici.sifre_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Kullanıcı adı veya şifre hatalı",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = kullanici_token_olustur(kullanici)
    return schemas.Token(
        access_token=token,
        token_type="bearer",
        kullanici_adi=kullanici.kullanici_adi,
        ad_soyad=kullanici.ad_soyad,
        role=getattr(kullanici, "role", "user") or "user",
        id=kullanici.id,
        company_id=getattr(kullanici, "company_id", None),
    )


@app.post("/register", response_model=schemas.Token, tags=["auth"])
def register(istek: schemas.UserRegister, db: Session = Depends(get_db)):
    """Özgür kayıt — yalnızca ALLOW_PUBLIC_REGISTER=true iken açıktır."""
    if not ALLOW_PUBLIC_REGISTER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Kayıt kapalıdır. Hesabınızı yöneticinizden isteyin.",
        )
    yeni = _kullanici_olustur(
        db,
        istek.kullanici_adi,
        istek.sifre,
        istek.ad_soyad,
        role="user",
        email=getattr(istek, "email", None),
    )
    token = kullanici_token_olustur(yeni)
    return schemas.Token(
        access_token=token,
        token_type="bearer",
        kullanici_adi=yeni.kullanici_adi,
        ad_soyad=yeni.ad_soyad,
        role=yeni.role or "user",
        id=yeni.id,
        company_id=getattr(yeni, "company_id", None),
    )


@app.get("/api/ben", tags=["auth"])
def beni_getir(current_user: models.User = Depends(get_current_user)):
    """Oturum açmış kullanıcının güncel bilgisi (rol dahil)."""
    return {
        "id": current_user.id,
        "kullanici_adi": current_user.kullanici_adi,
        "ad_soyad": current_user.ad_soyad,
        "role": getattr(current_user, "role", "user") or "user",
        "company_id": getattr(current_user, "company_id", None),
        "email": getattr(current_user, "email", None),
    }


@app.put("/api/profil", tags=["auth"])
def profil_guncelle(
    istek: schemas.ProfilGuncelle,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Oturum açmış kullanıcı kendi görünen adını günceller; kullanıcı adı değişmez."""
    current_user.ad_soyad = istek.ad_soyad
    db.commit()
    db.refresh(current_user)
    return {
        "mesaj": "Profil güncellendi",
        "id": current_user.id,
        "kullanici_adi": current_user.kullanici_adi,
        "ad_soyad": current_user.ad_soyad,
        "role": getattr(current_user, "role", "user") or "user",
        "company_id": getattr(current_user, "company_id", None),
        "email": getattr(current_user, "email", None),
    }


@app.put("/api/sifre", tags=["auth"])
def sifre_degistir(
    istek: schemas.SifreDegistir,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Oturum açmış kullanıcı kendi şifresini günceller; kullanıcı adı değişmez."""
    if not sifreyi_dogrula(istek.mevcut_sifre, current_user.sifre_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mevcut şifre hatalı",
        )
    if istek.mevcut_sifre == istek.yeni_sifre:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Yeni şifre mevcut şifreden farklı olmalıdır",
        )
    current_user.sifre_hash = sifreyi_hashle(istek.yeni_sifre)
    db.commit()
    db.refresh(current_user)
    yeni_token = kullanici_token_olustur(current_user)
    return {
        "mesaj": "Şifreniz başarıyla güncellendi",
        "access_token": yeni_token,
        "token_type": "bearer",
    }


@app.get("/api/auth/ayarlar", tags=["auth"])
def auth_ayarlar():
    """Giriş ekranı için herkese açık kimlik doğrulama ayarları."""
    return {
        "allow_public_register": ALLOW_PUBLIC_REGISTER,
    }


@app.post("/kurumlar/")
def kurum_ekle(
    kurum: schemas.InstitutionCreate,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    yeni_kurum = models.Institution(name=kurum.name, type=kurum.type)
    db.add(yeni_kurum)
    db.commit()
    db.refresh(yeni_kurum)
    
    return {
        "mesaj": "Kurum başarıyla eklendi! 🎉", 
        "kurum_adi": yeni_kurum.name,
        "kurum_id": yeni_kurum.id
    }


@app.get("/api/urunler")
def urunleri_getir(
    db: Session = Depends(get_db),
    _: models.User = Depends(get_current_user),
):
    urunler = (
        db.query(models.Product)
        .filter(models.Product.is_active.is_(True))
        .order_by(models.Product.name.asc())
        .all()
    )
    adlar = _sirket_ad_haritasi(db, [u.company_id for u in urunler])
    return {
        "adet": len(urunler),
        "urunler": [
            {
                "id": u.id,
                "code": u.code,
                "name": u.name,
                "is_active": bool(u.is_active),
                "company_id": u.company_id,
                "company_name": adlar.get(u.company_id),
            }
            for u in urunler
        ],
    }


@app.get("/api/surec-tipleri")
def surec_tipleri_getir():
    """Sabit (katı) süreç tipi listesi — web/mobile bu uç noktadan dinamik

    olarak çeker; böylece dropdown/etiket listeleri backend'deki
    `enums.SurecTipi` ile HER ZAMAN birebir aynı kalır (hardcoded string
    listesi elle senkron tutulmaya çalışılmaz).
    """
    return {"degerler": enums.SUREC_TIPI_DEGERLERI}


@app.get("/api/gorusme-durumlari")
def gorusme_durumlari_getir():
    """Sabit (katı) görüşme durumu listesi (Olumlu/Olumsuz/Karma/Beklemede) —

    web/mobile bu uç noktadan dinamik olarak çeker; böylece dropdown/etiket
    listeleri backend'deki `enums.GorusmeDurumu` ile HER ZAMAN birebir aynı
    kalır (bkz. `/api/surec-tipleri` ile aynı desen).
    """
    return {"degerler": enums.GORUSME_DURUMU_DEGERLERI}


def _urun_kodu_uret(ad: str) -> str:
    tablo = str.maketrans("ÇĞİÖŞÜçğıöşüâêîôûÂÊÎÔÛ", "CGIOSUcgiosuaeiouAEIOU")
    ham = (ad or "").translate(tablo).upper()
    kod = re.sub(r"[^A-Z0-9]+", "_", ham).strip("_")
    return kod[:50] or "URUN"


@app.post("/api/urunler")
def urun_ekle(
    urun: schemas.ProductCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(require_admin),
):
    ad = (urun.name or "").strip()
    if not ad:
        raise HTTPException(status_code=400, detail="Ürün adı zorunludur.")
    kod = (urun.code or "").strip().upper() or _urun_kodu_uret(ad)
    sirket_id = urun.company_id or getattr(current_user, "company_id", None)
    mevcut = db.query(models.Product).filter(models.Product.code == kod).first()
    if mevcut:
        if mevcut.is_active:
            raise HTTPException(status_code=409, detail=f"'{kod}' kodlu ürün zaten var.")
        mevcut.name = ad
        mevcut.is_active = True if urun.is_active is None else urun.is_active
        if sirket_id:
            mevcut.company_id = sirket_id
        db.commit()
        db.refresh(mevcut)
        return {
            "mesaj": "Ürün yeniden etkinleştirildi",
            "urun": {
                "id": mevcut.id,
                "code": mevcut.code,
                "name": mevcut.name,
                "is_active": bool(mevcut.is_active),
                "company_id": mevcut.company_id,
            },
        }
    yeni = models.Product(
        code=kod,
        name=ad,
        is_active=True if urun.is_active is None else urun.is_active,
        company_id=sirket_id,
    )
    db.add(yeni)
    db.commit()
    db.refresh(yeni)
    return {
        "mesaj": "Ürün başarıyla eklendi",
        "urun": {
            "id": yeni.id,
            "code": yeni.code,
            "name": yeni.name,
            "is_active": bool(yeni.is_active),
            "company_id": yeni.company_id,
        },
    }


@app.delete("/api/urunler/{product_id}")
def urun_sil(
    product_id: int,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    """[Admin] Ürünü listeden kaldırır (is_active=False). Geçmiş kayıtlar bozulmaz."""
    urun = db.query(models.Product).filter(models.Product.id == product_id).first()
    if not urun:
        raise HTTPException(status_code=404, detail="Ürün bulunamadı.")
    urun.is_active = False
    db.commit()
    return {"mesaj": f"'{urun.name}' ürünü kaldırıldı.", "id": urun.id}


@app.get("/api/urunler/{product_id}/kullanicilar", tags=["admin"])
def urun_sirket_kullanicilari(
    product_id: int,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    """[Admin] Seçilen ürünün şirketindeki çalışanları döndürür.

    A şirketinin ürünü için yalnızca A şirketinin kullanıcıları gelir;
    B şirketinin çalışanı listelenmez.
    """
    urun = db.query(models.Product).filter(models.Product.id == product_id).first()
    if not urun:
        raise HTTPException(status_code=404, detail="Ürün bulunamadı")
    sirket_id = getattr(urun, "company_id", None)
    if sirket_id is None:
        raise HTTPException(
            status_code=400,
            detail="Bu ürünün şirket bilgisi eksik; çalışan listelenemez.",
        )
    sirket = db.query(models.Company).filter(models.Company.id == sirket_id).first()
    if not sirket:
        raise HTTPException(status_code=404, detail="Ürünün şirketi bulunamadı")
    kullanicilar = (
        db.query(models.User)
        .filter(models.User.company_id == sirket_id)
        .filter(models.User.role != "admin")
        .order_by(models.User.ad_soyad.asc(), models.User.kullanici_adi.asc())
        .all()
    )
    return {
        "product_id": urun.id,
        "product_name": urun.name,
        "company_id": sirket.id,
        "company_name": sirket.name,
        "adet": len(kullanicilar),
        "kullanicilar": [_kullanici_public_dict(u, sirket.name) for u in kullanicilar],
    }

@app.post("/ai-veri-isle/")
def yapay_zeka_verisini_isle(
    veri: schemas.AIParsedData,
    db: Session = Depends(get_db),
    _: models.User = Depends(get_current_user),
):
    try:
        kurum = db.query(models.Institution).filter(models.Institution.name == veri.kurum_adi).first()
        if not kurum:
            kurum = models.Institution(name=veri.kurum_adi, type="UNIVERSITE")
            db.add(kurum)
            db.flush()

        urun = db.query(models.Product).filter(models.Product.code == veri.urun_kodu).first()
        if not urun:
            kod = (veri.urun_kodu or "").strip().upper()
            urun = models.Product(
                code=kod,
                name=kod,
                is_active=True,
                company_id=getattr(_, "company_id", None),
            )
            db.add(urun)
            db.flush()
        urun_id = urun.id

        yeni_abonelik = models.Subscription(
            institution_id=kurum.id,
            product_id=urun_id,
            kurum_adi=_kurum_adi_al(kurum),
            urun_adi=urun.name if urun else None,
            access_type=veri.abonelik_tipi,
            status=veri.durum,
            start_date=veri.baslangic_tarihi,
            end_date=veri.bitis_tarihi
        )
        db.add(yeni_abonelik)
        db.flush()

        yeni_egitim = models.Training(
            institution_id=kurum.id,
            subscription_id=yeni_abonelik.id,
            kurum_adi=_kurum_adi_al(kurum),
            training_type=veri.egitim_tipi,
            trigger_event=veri.aksiyon_notu
        )
        db.add(yeni_egitim)

        yeni_not = models.Note(
            institution_id=kurum.id,
            kurum_adi=_kurum_adi_al(kurum),
            note_key="AI_GORUSME_NOTU",
            content=veri.genel_not,
            created_by="AI"
        )
        db.add(yeni_not)

        ai_log = models.AIVoiceLog(
            institution_id=kurum.id,
            kurum_adi=_kurum_adi_al(kurum),
            raw_transcript=veri.ham_ses_metni,
            ai_parsed_json=veri.model_dump(mode="json"),
            status="SUCCESS"
        )
        db.add(ai_log)

        db.commit()

        return {
            "mesaj": "Sistem başarıyla güncellendi! 🚀",
            "eklenen_kurum": kurum.name,
            "islem_detayi": "Kurum, Abonelik, Eğitim, Not ve Log tabloları eşzamanlı dolduruldu."
        }

    except Exception as e:
        db.rollback()
        return {"hata": "Bir sorun oluştu, işlemler iptal edildi", "detay": str(e)}

@app.get("/kontrol/")
def verileri_kontrol_et(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    sorgu = _aktif(db.query(models.Institution), models.Institution)
    kurumlar = sorgu.all()
    return {"python_veritabani_sonucu": kurumlar}

@app.get("/kurum/{kurum_id}/detay")
def kurum_detay_getir(
    kurum_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    kurum = _aktif(db.query(models.Institution), models.Institution).filter(
        models.Institution.id == kurum_id
    ).first()
    
    if not kurum:
        return {"hata": "Böyle bir kurum sistemde bulunamadı."}

    _kurum_erisim_kontrol(db, kurum.id, current_user)

    abonelikler = _aktif(db.query(models.Subscription), models.Subscription).filter(
        models.Subscription.institution_id == kurum_id
    ).all()
    egitimler = _aktif(db.query(models.Training), models.Training).filter(
        models.Training.institution_id == kurum_id
    ).all()
    notlar = _aktif(db.query(models.Note), models.Note).filter(
        models.Note.institution_id == kurum_id
    ).all()
    
    return {
        "kurum_bilgisi": kurum,
        "abonelik_gecmisi": abonelikler,
        "planlanan_egitimler": egitimler,
        "gorusme_notlari": notlar
    }

@app.delete("/kurum/{kurum_id}")
def kurum_sil(
    kurum_id: int,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    kurum = _aktif(db.query(models.Institution), models.Institution).filter(
        models.Institution.id == kurum_id
    ).first()

    if not kurum:
        raise HTTPException(status_code=404, detail="Silinecek kurum bulunamadı.")

    try:
        db.query(models.Analysis).filter(
            models.Analysis.institution_id == kurum_id
        ).update({"is_deleted": True}, synchronize_session=False)
        db.query(models.Task).filter(
            models.Task.institution_id == kurum_id
        ).update({"is_deleted": True}, synchronize_session=False)
        db.delete(kurum)
        db.commit()
        return {"mesaj": f"'{kurum.name}' kaydı silindi."}
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Silme işlemi sırasında hata oluştu",
        ) from e

@app.put("/kurum/{kurum_id}")
def kurum_guncelle(
    kurum_id: int,
    guncel_veri: schemas.KurumGuncelle,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    kurum = _aktif(db.query(models.Institution), models.Institution).filter(
        models.Institution.id == kurum_id
    ).first()
    
    if not kurum:
        raise HTTPException(status_code=404, detail="Güncellenecek kurum bulunamadı.")
        
    if guncel_veri.yeni_ad:
        yeni_ad = guncel_veri.yeni_ad.strip()
        if yeni_ad:
            kurum.name = yeni_ad
            for model in (
                models.Analysis,
                models.Task,
                models.Note,
                models.Subscription,
                models.Training,
                models.AIVoiceLog,
            ):
                if hasattr(model, "kurum_adi") and hasattr(model, "institution_id"):
                    db.query(model).filter(model.institution_id == kurum_id).update(
                        {"kurum_adi": yeni_ad}, synchronize_session=False
                    )
    if guncel_veri.yeni_tip:
        kurum.type = guncel_veri.yeni_tip
        
    db.commit()
    db.refresh(kurum)
    
    return {
        "mesaj": "Kurum bilgileri başarıyla güncellendi!",
        "guncel_kurum": _kurum_dict(kurum),
    }

@app.get("/kurumlar")
def tum_kurumlari_getir(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    sorgu = _aktif(db.query(models.Institution), models.Institution)
    kurumlar = sorgu.all()

    if not kurumlar:
        return {
            "mesaj": "Sistemde henüz kayıtlı kurum bulunmamaktadır.",
            "toplam_kayit": 0,
            "kurum_listesi": [],
        }

    return {
        "toplam_kayit": len(kurumlar),
        "kurum_listesi": [_kurum_dict(k) for k in kurumlar],
    }

@app.get("/api/notlar")
def tum_notlari_getir(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    try:
        sorgu = _aktif(db.query(models.Note), models.Note)
        if not _is_admin(current_user):
            kurum_ids = _kullanici_kurum_ids(db, current_user)
            if not kurum_ids:
                return {"adet": 0, "notlar": []}
            sorgu = sorgu.filter(models.Note.institution_id.in_(kurum_ids))
        notlar = sorgu.order_by(models.Note.created_at.desc()).all()
        sonuc = []
        for n in notlar:
            kurum = db.query(models.Institution).filter(models.Institution.id == n.institution_id).first()
            icerik = (n.content or "").strip()
            if not icerik:
                continue
            sonuc.append({
                "id": n.id,
                "icerik": icerik,
                "kurum_adi": n.kurum_adi or (kurum.name if kurum else None),
                "olusturan": n.created_by,
                "tarih": n.created_at.isoformat() if n.created_at else None,
            })
        return {"adet": len(sonuc), "notlar": sonuc}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/istatistikler")
def istatistikler(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    try:
        is_admin = _is_admin(current_user)
        izinli_ids = None if is_admin else _kullanici_kurum_ids(db, current_user)
        kurumlar = (
            _aktif(db.query(models.Institution), models.Institution)
            .order_by(models.Institution.name.asc())
            .all()
        )
        urunler = (
            db.query(models.Product)
            .filter(models.Product.is_active.is_(True))
            .order_by(models.Product.name.asc())
            .all()
        )
        if is_admin:
            not_sayisi = _aktif(db.query(models.Note), models.Note).count()
        else:
            not_sayisi = (
                _aktif(db.query(models.Note), models.Note)
                .filter(models.Note.institution_id.in_(izinli_ids))
                .count()
                if izinli_ids else 0
            )
        # Rol bazlı sayımlar
        analiz_sorgu = _aktif(db.query(models.Analysis), models.Analysis)
        if not is_admin:
            analiz_sorgu = analiz_sorgu.filter(models.Analysis.user_id == current_user.id)
        analiz_sayisi = analiz_sorgu.count()
        gorev_sayisi = _aktif_gorev_sayisi(db, current_user)
        son_analiz = (
            analiz_sorgu
            .order_by(models.Analysis.created_at.desc(), models.Analysis.id.desc())
            .first()
        )
        son_not = (
            _aktif(db.query(models.Note), models.Note)
            .order_by(models.Note.created_at.desc())
            .first()
        ) if is_admin else None
        son_log = None
        if not son_not and not son_analiz and is_admin:
            son_log = (
                _aktif(db.query(models.AIVoiceLog), models.AIVoiceLog)
                .order_by(models.AIVoiceLog.created_at.desc())
                .first()
            )

        son_kayit = son_analiz or son_not or son_log
        son_gorusme = None
        if son_kayit:
            kurum_id = getattr(son_kayit, "institution_id", None)
            kurum = None
            if kurum_id:
                kurum = db.query(models.Institution).filter(
                    models.Institution.id == kurum_id
                ).first()
            if son_analiz and son_kayit is son_analiz:
                son_gorusme = {
                    "tarih": son_analiz.created_at.isoformat() if son_analiz.created_at else None,
                    "kurum_adi": son_analiz.kurum_adi or (kurum.name if kurum else None),
                    "kurum_id": son_analiz.institution_id or (kurum.id if kurum else None),
                    "durum": son_analiz.durum,
                }
            else:
                son_gorusme = {
                    "tarih": son_kayit.created_at.isoformat() if son_kayit.created_at else None,
                    "kurum_adi": kurum.name if kurum else None,
                    "kurum_id": kurum.id if kurum else getattr(son_kayit, "institution_id", None),
                }

        return {
            "toplam_kurum_sayisi": len(kurumlar),
            "kurum_listesi": [{"id": k.id, "name": k.name} for k in kurumlar],
            "populer_urun_sayisi": len(urunler),
            "urun_listesi": [(u.name or u.code) for u in urunler],
            "not_sayisi": not_sayisi,
            "analiz_sayisi": analiz_sayisi,
            "aktif_gorev_sayisi": gorev_sayisi,
            "son_gorusme": son_gorusme,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/kurum-detay")
def kurum_detay_ozet(
    id: Optional[int] = Query(None),
    ad: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    try:
        query = _aktif(db.query(models.Institution), models.Institution)
        kurum = None
        if id is not None:
            kurum = query.filter(models.Institution.id == id).first()
        elif ad and ad.strip():
            aranan = ad.strip()
            kurum = query.filter(models.Institution.name.ilike(aranan)).first()
            if not kurum:
                kurum = query.filter(models.Institution.name.ilike(f"%{aranan}%")).first()
        else:
            raise HTTPException(status_code=400, detail="id veya ad gerekli")

        if not kurum:
            raise HTTPException(status_code=404, detail="Kurum bulunamadı")

        _kurum_erisim_kontrol(db, kurum.id, current_user)

        abonelikler = (
            _aktif(db.query(models.Subscription), models.Subscription)
            .filter(models.Subscription.institution_id == kurum.id)
            .order_by(models.Subscription.created_at.desc())
            .all()
        )
        urun_ids = [a.product_id for a in abonelikler if a.product_id]
        urunler = []
        if urun_ids:
            urunler = db.query(models.Product).filter(models.Product.id.in_(urun_ids)).all()

        notlar = (
            _aktif(db.query(models.Note), models.Note)
            .filter(models.Note.institution_id == kurum.id)
            .order_by(models.Note.created_at.desc())
            .all()
        )
        loglar = (
            _aktif(db.query(models.AIVoiceLog), models.AIVoiceLog)
            .filter(models.AIVoiceLog.institution_id == kurum.id)
            .order_by(models.AIVoiceLog.created_at.desc())
            .all()
        )

        son_tarih = None
        if notlar and notlar[0].created_at:
            son_tarih = notlar[0].created_at
        elif loglar and loglar[0].created_at:
            son_tarih = loglar[0].created_at
        elif abonelikler and abonelikler[0].created_at:
            son_tarih = abonelikler[0].created_at

        durum = "Beklemede"
        if abonelikler:
            st = (abonelikler[0].status or "").upper()
            if st in ("AKTIF", "OLUMLU", "ONAY", "TAM_ERISIM"):
                durum = "Olumlu"
            elif st in ("IPTAL", "OLUMSUZ", "RED", "PASIF"):
                durum = "Olumsuz"

        analizler = (
            _aktif(db.query(models.Analysis), models.Analysis)
            .filter(models.Analysis.institution_id == kurum.id)
            .order_by(models.Analysis.created_at.desc(), models.Analysis.id.desc())
            .all()
        )

        urun_adlari = [(u.name or u.code) for u in urunler]
        for a in analizler:
            urun_adlari.extend(
                _ilgilenilen_urunler_normalize(
                    getattr(a, "ilgilenilen_urunler", None),
                    a.urun_adi or a.urun_kodu,
                )
            )
        temiz_urunler = []
        gorulen = set()
        for ad in urun_adlari:
            anahtar = (ad or "").casefold()
            if not anahtar or anahtar in gorulen:
                continue
            gorulen.add(anahtar)
            temiz_urunler.append(ad)

        son_analiz = analizler[0] if analizler else None
        if son_analiz and son_analiz.created_at:
            if son_tarih is None or son_analiz.created_at > son_tarih:
                son_tarih = son_analiz.created_at
        if son_analiz and son_analiz.durum:
            durum = _durum_normalize(son_analiz.durum) or durum
        surec = _surec_tipi_normalize(
            (getattr(son_analiz, "surec_tipi", None) or son_analiz.abonelik_tipi)
            if son_analiz
            else None
        )

        analiz_ids = [a.id for a in analizler]
        gorev_kosul = [models.Task.institution_id == kurum.id]
        if analiz_ids:
            gorev_kosul.append(models.Task.analysis_id.in_(analiz_ids))
        gorev_sorgu = (
            _aktif(db.query(models.Task), models.Task)
            .filter(or_(*gorev_kosul))
        )
        if not _is_admin(current_user):
            user_kosul = [models.Task.user_id == current_user.id]
            if analiz_ids:
                user_kosul.append(models.Task.analysis_id.in_(analiz_ids))
            gorev_sorgu = gorev_sorgu.filter(or_(*user_kosul))
        gorev_satirlari = [
            g
            for g in (
                gorev_sorgu
                .order_by(models.Task.created_at.asc(), models.Task.id.asc())
                .all()
            )
            if (g.title or "").strip()
            and str(g.source or "ai").lower() not in ("manuel", "manual")
        ]
        gorev_etiket = _kullanici_etiket_map(
            db,
            [(g.assigned_user_id or g.user_id) for g in gorev_satirlari],
        )
        kurum_gorevleri = [_gorev_kisa_dict(db, g, gorev_etiket) for g in gorev_satirlari]

        return {
            "id": kurum.id,
            "kurum_adi": kurum.name,
            "kurum_turu": kurum.type,
            "son_gorusme_tarihi": son_tarih.isoformat() if son_tarih else None,
            "ilgilenilen_urunler": temiz_urunler,
            "surec_tipi": surec,
            "gorusme_durumu": durum,
            "son_analiz_id": son_analiz.id if son_analiz else None,
            "gorevler": kurum_gorevleri,
            "gecmis_not": (son_analiz.ham_metin if son_analiz else None)
            or (notlar[0].content if notlar else None)
            or (loglar[0].raw_transcript if loglar else None),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def _kisa_gorevler(gorevler) -> list:
    """Görevleri kısa, temiz bir string listesine indirger.

    `gorevler` artık AI'dan (ve `schemas.AIAnalysisResult` doğrulamasından)
    her biri bir NESNE olan bir dizi (ör. `[{"task": "..."}]`) olarak
    gelebilir; eski düz string listesi/tek metin formatı da geriye dönük
    uyumluluk için desteklenir. Veritabanına (Task.title) her zaman düz bir
    metin listesi olarak yazılır.
    """
    if isinstance(gorevler, str):
        gorevler = [g.strip() for g in gorevler.replace("\n", ";").split(";") if g.strip()]
    if not isinstance(gorevler, list):
        return []
    temiz = []
    gorulen = set()
    for g in gorevler:
        if isinstance(g, dict):
            g = g.get("task") or g.get("gorev") or g.get("baslik") or g.get("aksiyon") or ""
        if not isinstance(g, str):
            continue
        cumle = " ".join(g.split()).strip()
        if not cumle or len(cumle.split()) > 20:
            continue
        anahtar = cumle.casefold()
        if anahtar in gorulen:
            continue
        gorulen.add(anahtar)
        temiz.append(cumle)
    return temiz


def _kurum_bul_veya_olustur(db: Session, kurum_adi: str, kurum_turu: Optional[str] = None):
    ad = (kurum_adi or "").strip()
    if not ad:
        return None
    kurum = db.query(models.Institution).filter(
        models.Institution.name.ilike(ad)
    ).first()
    if not kurum:
        kurum = models.Institution(
            name=ad,
            type=(kurum_turu or "UNIVERSITE").strip() or "UNIVERSITE",
        )
        db.add(kurum)
        db.flush()
    elif kurum_turu:
        kurum.type = kurum_turu.strip()
    return kurum


def _analiz_kaydet(db: Session, ham_metin: str, sonuc: dict, gorevler: list, user_id: Optional[int] = None):
    kurum_adi = (sonuc.get("kurum_adi") or "").strip()
    kurum_turu = sonuc.get("kurum_türü") or sonuc.get("kurum_turu")
    kurum = _kurum_bul_veya_olustur(db, kurum_adi, kurum_turu)

    # Kaydetmeden ÖNCE son bir katı doğrulama: sistemde kayıtlı (aktif) ürün
    # kataloğunda karşılığı olmayan (AI'nın uydurduğu) hiçbir ürün adı
    # veritabanına yazılmaz; fonetik/STT yazım farkları en yakın katalog
    # ürününe otomatik eşlenir (bkz. enums.urunleri_filtrele).
    katalog = aktif_urun_katalogu(db)
    urunler = _ilgilenilen_urunler_normalize(
        sonuc.get("ilgilenilen_urunler"),
        sonuc.get("urun_adi"),
    )
    urunler = enums.urunleri_filtrele(urunler, katalog, fuzzy=True)
    # Son savunma hattı: Gemini metinde BİRDEN FAZLA ürün geçse bile bazen
    # sadece ilk bahsedileni yakalayıp diğerini gözden kaçırabiliyor. Ham
    # metinde katalogdaki ürünlerin adı/kodu BİREBİR geçiyorsa (literal
    # eşleşme) bunları AI'nın listesinin ÜZERİNE YAZMADAN, EKSİK OLANLARI
    # listeye EKLİYORUZ. Eskiden bu sadece liste TAMAMEN boşsa çalışıyordu;
    # bu da "ilk söylediğim ürünü algıladı, diğerini algılamadı" hatasına
    # yol açıyordu çünkü liste boş olmadığı için tamamlayıcı tarama hiç
    # devreye girmiyordu.
    katalogdan_yakalanan = _katalogdan_urun_yakala(ham_metin, db)
    if katalogdan_yakalanan:
        gorulen_urunler = {u.casefold() for u in urunler}
        for ad in katalogdan_yakalanan:
            if ad.casefold() not in gorulen_urunler:
                urunler.append(ad)
                gorulen_urunler.add(ad.casefold())
    urun_adi_ham = (sonuc.get("urun_adi") or "").strip()
    urun_adi = (
        enums.urun_adi_coz(urun_adi_ham, katalog)
        or enums.en_yakin_urun_adi(urun_adi_ham, katalog)
        or (urunler[0] if urunler else None)
    )
    urun_kodu = _urun_kodu_esle(db, sonuc.get("urun_kodu"), urun_adi)
    # Katalogdan ad çözümü YALNIZCA metinde/kataloğa eşleşen bir ürün varsa
    # yapılır; aksi halde kod eşleşmesi üzerinden uydurma bir ürün adı geri sızabilir.
    if urun_adi and urun_adi not in urunler:
        urunler.insert(0, urun_adi)
    sonuc["urun_adi"] = urun_adi
    sonuc["urun_kodu"] = urun_kodu
    sonuc["ilgilenilen_urunler"] = urunler

    surec_tipi = _surec_tipi_normalize(sonuc.get("surec_tipi") or sonuc.get("abonelik_tipi"))
    if surec_tipi == enums.SurecTipi.HICBIRI.value:
        # Son savunma hattı: ham metinde açık bir abonelik/deneme niyeti
        # (gelecek tarihli planlar dahil) varsa 'Hiçbiri' burada düzeltilir.
        algilanan = enums.surec_tipi_metinden_algila(ham_metin)
        if algilanan:
            surec_tipi = algilanan
    sonuc["surec_tipi"] = surec_tipi
    sonuc["abonelik_tipi"] = surec_tipi

    analiz = models.Analysis(
        institution_id=kurum.id if kurum else None,
        user_id=user_id,
        ham_metin=ham_metin,
        kurum_adi=kurum_adi or None,
        durum=(sonuc.get("durum") or "").strip() or None,
        urun_kodu=urun_kodu,
        urun_adi=urun_adi,
        surec_tipi=surec_tipi,
        abonelik_tipi=surec_tipi,
        ilgilenilen_urunler=urunler,
        kaynak="ai",
        ai_json=sonuc,
        is_deleted=False,
    )
    db.add(analiz)
    db.flush()

    kayitli_gorevler = []
    gorev_sirket = _kullanici_sirket_id(db, user_id) or _urun_sirket_id(db, urun_kodu)
    for metin in gorevler:
        gorev = models.Task(
            analysis_id=analiz.id,
            institution_id=kurum.id if kurum else None,
            kurum_adi=_kurum_adi_al(kurum) or kurum_adi or None,
            title=metin,
            source="ai",
            is_done=False,
            user_id=user_id,
            assigned_user_id=user_id,
            company_id=gorev_sirket,
        )
        db.add(gorev)
        kayitli_gorevler.append(gorev)
    db.flush()

    # NOT: Buraya Gemini'nin ürettiği bir özet DEĞİL, kullanıcının orijinal
    # (değiştirilmemiş) ham_metin'i kaydediliyor; sistemde hiçbir yerde AI
    # tarafından yeniden yazılmış bir "not" saklanmıyor/gösterilmiyor.
    if kurum and ham_metin:
        db.add(
            models.Note(
                institution_id=kurum.id,
                kurum_adi=_kurum_adi_al(kurum),
                note_key="AI_ANALIZ",
                content=ham_metin,
                created_by="AI",
            )
        )

    db.commit()
    return analiz, kayitli_gorevler


async def _metni_analiz_et(metin: str, db: Session, current_user: Optional[models.User] = None) -> dict:
    """Ortak metin analiz mantığı.

    Flutter'dan (speech_to_text ile cihazda üretilen) hazır metni alır,
    Gemini ile CRM analizine (kurum, ürün, durum) çevirir ve DB'ye kaydeder.
    Ses dosyası bu akışa hiçbir zaman girmez; Whisper artık kullanılmıyor.
    """
    t_toplam = time.monotonic()
    metin = (metin or "").strip()

    onizleme = metin[:120].replace("\n", " ")
    print(f"Transkript için şu model kullanılıyor: {TRANSKRIPT_MODELI}")
    print(f"[analyze-text] Gelen metin ({len(metin)} karakter): \"{onizleme}\"")
    logger.info("Metin analizi isteği alındı: %d karakter", len(metin))

    if not metin:
        print("[analyze-text] UYARI: Boş metin geldi. Mikrofon ses almamış olabilir "
              "(Flutter tarafındaki [STT] loglarını kontrol edin).")
        raise HTTPException(status_code=400, detail="Analiz için metin boş olamaz.")
    try:
        katalog = aktif_urun_katalogu(db)
        t_katalog = time.monotonic()
        print(f"[analyze-text] Ürün kataloğu yüklendi ({time.monotonic() - t_katalog:.3f} sn)")

        print("[analyze-text] Gemini çağrısı başlıyor...")
        t_gemini = time.monotonic()
        sonuc = await ai_service.metni_yapilandir_async(metin, katalog)
        gemini_sure = time.monotonic() - t_gemini
        print(f"[analyze-text] Gemini çağrısı {gemini_sure:.2f} sn sürdü.")
        if not isinstance(sonuc, dict):
            sonuc = {"gorevler": []}
        sonuc.pop("not_icerigi", None)

        t_dogrulama = time.monotonic()
        dogrulanmis = schemas.AIAnalysisResult.model_validate(
            sonuc, context={"katalog": katalog}
        ).model_dump()
        sonuc.update(dogrulanmis)
        print(f"[analyze-text] Pydantic doğrulama {time.monotonic() - t_dogrulama:.3f} sn sürdü.")

        gorevler = _kisa_gorevler(sonuc.get("gorevler"))
        sonuc["gorevler"] = gorevler

        t_db = time.monotonic()
        analiz, kayitli = _analiz_kaydet(
            db, metin, sonuc, gorevler,
            user_id=current_user.id if current_user else None,
        )
        print(f"[analyze-text] DB kayıt işlemi {time.monotonic() - t_db:.3f} sn sürdü.")
        sonuc["analiz_id"] = analiz.id
        sonuc["kayitli_gorev_sayisi"] = len(kayitli)
        sonuc["urun_adi"] = analiz.urun_adi
        sonuc["ilgilenilen_urunler"] = getattr(analiz, "ilgilenilen_urunler", None) or sonuc.get("ilgilenilen_urunler") or []
        sonuc["surec_tipi"] = getattr(analiz, "surec_tipi", None) or analiz.abonelik_tipi
        sonuc["abonelik_tipi"] = sonuc["surec_tipi"]
        sonuc["not_icerigi"] = metin
        print(f"[analyze-text] Analiz tamamlandı: kurum={sonuc.get('kurum_adi')!r}, "
              f"durum={sonuc.get('durum')!r}, analiz_id={analiz.id}")
        print(f"[analyze-text] Toplam istek süresi: {time.monotonic() - t_toplam:.2f} sn")
        return sonuc
    except HTTPException:
        raise
    except ValidationError as e:
        db.rollback()
        print(f"[analyze-text] Pydantic doğrulama hatası: {e}")
        raise HTTPException(status_code=502, detail="AI yanıtı doğrulanamadı.")
    except json.JSONDecodeError:
        db.rollback()
        raise HTTPException(status_code=502, detail=GECERSIZ_YANIT)
    except Exception as e:
        db.rollback()
        msg = str(e)
        print(f"[analyze-text] HATA: {msg}")
        if "429" in msg or "quota" in msg.lower() or "ResourceExhausted" in msg:
            raise HTTPException(
                status_code=429,
                detail="Gemini API kotası doldu. Lütfen bir dakika bekleyip tekrar deneyin.",
            )
        if msg == GECERSIZ_YANIT or (isinstance(e, ValueError) and GECERSIZ_YANIT in msg):
            if "zaman aşımı" in msg.lower() or "timeout" in msg.lower():
                raise HTTPException(
                    status_code=504,
                    detail="Gemini API yanıt vermedi (zaman aşımı). Lütfen tekrar deneyin.",
                )
            raise HTTPException(status_code=502, detail=GECERSIZ_YANIT)
        if isinstance(e, ValueError):
            raise HTTPException(status_code=502, detail=msg or GECERSIZ_YANIT)
        raise HTTPException(status_code=500, detail=str(e) or GECERSIZ_YANIT)


@app.post("/api/analyze-text")
async def analyze_text(
    istek: schemas.AnalyzeTextRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Flutter'ın speech_to_text ile canlı ürettiği metni Gemini'a gönderir.

    Bu, sistemdeki TEK ses→CRM analiz yoludur. Ses dosyası kabul edilmez;
    tanıma tamamen cihazda (on-device) yapılır, backend sadece metni işler.
    """
    print("[API] POST /api/analyze-text isteği alındı.")
    return await _metni_analiz_et(istek.text, db, current_user)


@app.post("/api/analiz")
async def analiz_et(
    istek: schemas.HamMetinIstek,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Geriye dönük uyumluluk için korunan eski uç nokta (metin tabanlı)."""
    print("[API] POST /api/analiz isteği alındı (geriye dönük uyumluluk uç noktası).")
    return await _metni_analiz_et(istek.metin, db, current_user)


@app.get("/api/analizler")
def analizleri_listele(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    is_admin = _is_admin(current_user)
    sorgu = _aktif(db.query(models.Analysis), models.Analysis)
    if not is_admin:
        # Standart kullanıcı: sadece kendi kayıtları
        sorgu = sorgu.filter(models.Analysis.user_id == current_user.id)
    kayitlar = (
        sorgu
        # En son eklenen görüşme HER ZAMAN listenin en üstünde (Yeniden Eskiye)
        # görünsün diye `id` ikincil sıralama anahtarı olarak eklendi.
        .order_by(models.Analysis.created_at.desc(), models.Analysis.id.desc())
        .all()
    )
    sayaclar = {}
    if kayitlar:
        ids = [a.id for a in kayitlar]
        for analiz_id, adet in (
            db.query(models.Task.analysis_id, func.count(models.Task.id))
            .filter(
                models.Task.analysis_id.in_(ids),
                models.Task.is_deleted.is_(False),
            )
            .group_by(models.Task.analysis_id)
            .all()
        ):
            sayaclar[analiz_id] = int(adet or 0)
    # Admin için kullanıcı adlarını toplu çek (N+1 yerine tek sorgu)
    kullanici_map: dict = {}
    if is_admin and kayitlar:
        user_ids = list({a.user_id for a in kayitlar if a.user_id})
        if user_ids:
            for u in db.query(models.User).filter(models.User.id.in_(user_ids)).all():
                kullanici_map[u.id] = (u.ad_soyad or "").strip() or u.kullanici_adi
    sonuc = []
    for a in kayitlar:
        veri = _analiz_dict(a)
        veri["gorev_sayisi"] = sayaclar.get(a.id, 0)
        if is_admin:
            veri["kullanici_adi"] = kullanici_map.get(a.user_id) if a.user_id else None
        sonuc.append(veri)
    return {"adet": len(sonuc), "kayitlar": sonuc}


@app.get("/api/analizler/{analiz_id}")
def analiz_getir(
    analiz_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    analiz = _aktif(db.query(models.Analysis), models.Analysis).filter(
        models.Analysis.id == analiz_id
    ).first()
    if not analiz:
        raise HTTPException(status_code=404, detail="Kayıt bulunamadı")
    is_admin = _is_admin(current_user)
    if not is_admin and analiz.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bu kayda erişim yetkiniz yok.")
    veri = _analiz_dict(analiz)
    if is_admin and analiz.user_id:
        veri["kullanici_adi"] = _kullanici_adi_al(db, analiz.user_id)
    # Bu görüşmeye ait AI To-Do listesi (yalnızca yapay zekanın çıkardığı görevler).
    # Manuel görevler buraya karışmaz; detay paneli AI aksiyonlarını eksiksiz gösterir.
    gorev_kayitlari = [
        g
        for g in (
            _aktif(db.query(models.Task), models.Task)
            .filter(
                models.Task.analysis_id == analiz.id,
                or_(
                    models.Task.source == "ai",
                    models.Task.source.is_(None),
                ),
            )
            .order_by(models.Task.created_at.asc(), models.Task.id.asc())
            .all()
        )
        if (g.title or "").strip()
    ]
    gorev_etiket = _kullanici_etiket_map(
        db,
        [(g.assigned_user_id or g.user_id) for g in gorev_kayitlari],
    )
    gorev_listesi = [_gorev_kisa_dict(db, g, gorev_etiket) for g in gorev_kayitlari]
    # DB'de henüz satır yoksa ai_json.gorevler yedek kaynak olarak kullanılır
    if not gorev_listesi:
        ai = analiz.ai_json if isinstance(analiz.ai_json, dict) else {}
        for metin in _kisa_gorevler(ai.get("gorevler")):
            if metin:
                gorev_listesi.append({
                    "id": None,
                    "baslik": metin,
                    "tamamlandi": False,
                    "kaynak": "ai",
                    "kurum_adi": veri.get("kurum_adi"),
                    "assigned_user_id": analiz.user_id,
                    "assigned_user_name": veri.get("kullanici_adi"),
                    "user_id": analiz.user_id,
                    "company_id": _kullanici_sirket_id(db, analiz.user_id)
                    or _urun_sirket_id(db, analiz.urun_kodu),
                })
    veri["gorevler"] = gorev_listesi
    return veri


@app.post("/api/analizler")
def analiz_manuel_ekle(
    veri: schemas.AnalysisManualCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    kurum_adi = (veri.kurum_adi or "").strip()
    if not kurum_adi:
        raise HTTPException(status_code=400, detail="Kurum adı zorunludur.")
    try:
        kurum = _kurum_bul_veya_olustur(db, kurum_adi, veri.kurum_turu)
        urun_kodu = (veri.urun_kodu or "").strip() or None
        urun_adi = _urun_adi_coz(db, urun_kodu, veri.urun_adi)
        not_icerigi = (veri.not_icerigi or "").strip()
        surec_tipi = _surec_tipi_normalize(veri.surec_tipi or veri.abonelik_tipi)
        urunler = _ilgilenilen_urunler_normalize(veri.ilgilenilen_urunler, urun_adi)
        ai_json = {
            "kurum_adi": kurum_adi,
            "urun_kodu": urun_kodu,
            "urun_adi": urun_adi,
            "ilgilenilen_urunler": urunler,
            "durum": (veri.durum or "Beklemede").strip(),
            "surec_tipi": surec_tipi,
            "abonelik_tipi": surec_tipi,
            "not_icerigi": not_icerigi,
            "kaynak": "manuel",
        }
        analiz = models.Analysis(
            institution_id=kurum.id if kurum else None,
            # user_id token'dan alınır, frontend'den beklenmez
            user_id=current_user.id,
            ham_metin=not_icerigi or kurum_adi,
            kurum_adi=kurum_adi,
            durum=ai_json["durum"],
            urun_kodu=urun_kodu,
            urun_adi=urun_adi,
            surec_tipi=surec_tipi,
            abonelik_tipi=surec_tipi,
            ilgilenilen_urunler=urunler,
            kaynak="manuel",
            ai_json=ai_json,
            is_deleted=False,
        )
        db.add(analiz)
        if kurum and not_icerigi:
            db.add(
                models.Note(
                    institution_id=kurum.id,
                    kurum_adi=_kurum_adi_al(kurum),
                    note_key="MANUEL_KAYIT",
                    content=not_icerigi,
                    created_by="MANUEL",
                )
            )
        db.commit()
        db.refresh(analiz)
        return {"mesaj": "Kayıt eklendi", "kayit": _analiz_dict(analiz)}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/api/analizler/{analiz_id}")
def analiz_guncelle(
    analiz_id: int,
    veri: schemas.AnalysisManualUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    analiz = _aktif(db.query(models.Analysis), models.Analysis).filter(
        models.Analysis.id == analiz_id
    ).first()
    if not analiz:
        raise HTTPException(status_code=404, detail="Kayıt bulunamadı")
    _analiz_erisim_kontrol(analiz, current_user)
    try:
        ai_json = dict(analiz.ai_json) if isinstance(analiz.ai_json, dict) else {}
        if veri.kurum_adi is not None:
            kurum_adi = veri.kurum_adi.strip()
            if not kurum_adi:
                raise HTTPException(status_code=400, detail="Kurum adı boş olamaz.")
            kurum = _kurum_bul_veya_olustur(db, kurum_adi, veri.kurum_turu)
            analiz.kurum_adi = kurum_adi
            analiz.institution_id = kurum.id if kurum else None
            ai_json["kurum_adi"] = kurum_adi
            db.query(models.Task).filter(models.Task.analysis_id == analiz.id).update(
                {
                    "institution_id": analiz.institution_id,
                    "kurum_adi": kurum_adi,
                },
                synchronize_session=False,
            )
        if veri.urun_kodu is not None:
            analiz.urun_kodu = veri.urun_kodu.strip() or None
            ai_json["urun_kodu"] = analiz.urun_kodu
        if veri.urun_adi is not None or veri.urun_kodu is not None:
            analiz.urun_adi = _urun_adi_coz(
                db,
                analiz.urun_kodu,
                veri.urun_adi if veri.urun_adi is not None else analiz.urun_adi,
            )
            ai_json["urun_adi"] = analiz.urun_adi
            if veri.ilgilenilen_urunler is None and analiz.urun_adi:
                analiz.ilgilenilen_urunler = _ilgilenilen_urunler_normalize(
                    analiz.ilgilenilen_urunler, analiz.urun_adi
                )
                ai_json["ilgilenilen_urunler"] = analiz.ilgilenilen_urunler
        if veri.ilgilenilen_urunler is not None:
            analiz.ilgilenilen_urunler = _ilgilenilen_urunler_normalize(
                veri.ilgilenilen_urunler, analiz.urun_adi
            )
            ai_json["ilgilenilen_urunler"] = analiz.ilgilenilen_urunler
        if veri.durum is not None:
            analiz.durum = _durum_normalize(veri.durum) or veri.durum.strip() or None
            ai_json["durum"] = analiz.durum
        if veri.surec_tipi is not None or veri.abonelik_tipi is not None:
            surec = _surec_tipi_normalize(veri.surec_tipi or veri.abonelik_tipi)
            analiz.surec_tipi = surec
            analiz.abonelik_tipi = surec
            ai_json["surec_tipi"] = surec
            ai_json["abonelik_tipi"] = surec
        if veri.not_icerigi is not None:
            not_icerigi = veri.not_icerigi.strip()
            ai_json["not_icerigi"] = not_icerigi
            analiz.ham_metin = not_icerigi or analiz.kurum_adi or analiz.ham_metin or ""
        analiz.ai_json = ai_json
        flag_modified(analiz, "ai_json")
        db.commit()
        db.refresh(analiz)
        return {"mesaj": "Kayıt güncellendi", "kayit": _analiz_dict(analiz)}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@app.patch("/api/analizler/{analiz_id}")
def analiz_yama(
    analiz_id: int,
    veri: schemas.AnalysisManualUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    return analiz_guncelle(analiz_id, veri, db, current_user)


@app.delete("/api/analizler/{analiz_id}")
def analiz_sil(
    analiz_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    analiz = _aktif(db.query(models.Analysis), models.Analysis).filter(
        models.Analysis.id == analiz_id
    ).first()
    if not analiz:
        raise HTTPException(status_code=404, detail="Kayıt bulunamadı")
    _analiz_erisim_kontrol(analiz, current_user)
    analiz.is_deleted = True
    db.query(models.Task).filter(models.Task.analysis_id == analiz.id).update(
        {"is_deleted": True}, synchronize_session=False
    )
    db.commit()
    return {"mesaj": "Kayıt pasife alındı", "id": analiz.id}


def _gorev_kapsam_normalize(kapsam: Optional[str]) -> str:
    k = (kapsam or "").strip().lower()
    if k in ("benim", "mine"):
        return "benim"
    if k in ("ekip_gorusmeleri", "team_meetings", "personel", "personel_gorusmeleri"):
        return "ekip_gorusmeleri"
    if k in ("hepsi", "all"):
        return "hepsi"
    return ""


def _gorevleri_listele(
    db: Session,
    current_user: models.User,
    kapsam: Optional[str] = None,
) -> dict:
    """Görev listesi. User: kendi kayıtları. Admin: kapsam ile benim / ekip görüşmeleri."""
    is_admin = _is_admin(current_user)
    sorgu = _aktif(db.query(models.Task), models.Task)
    secilen = _gorev_kapsam_normalize(kapsam)
    if not is_admin:
        secilen = "benim"

    if is_admin and not secilen:
        secilen = "benim"

    if secilen == "benim":
        # Görüşmeden çıkan görev başkasına atandıysa artık o kişinin işidir;
        # görüşmeyi yapanın "benim görevlerim" listesinde kalmaz.
        sorgu = sorgu.filter(_gorev_su_an_bende_kosulu(current_user))
    elif secilen == "ekip_gorusmeleri":
        diger_q = db.query(models.Analysis.id).filter(
            models.Analysis.is_deleted.is_(False),
            models.Analysis.user_id.isnot(None),
            models.Analysis.user_id != current_user.id,
        )
        sirket_id = getattr(current_user, "company_id", None)
        if sirket_id:
            sirket_kullanici_ids = [
                r[0]
                for r in db.query(models.User.id)
                .filter(models.User.company_id == sirket_id)
                .all()
            ]
            if sirket_kullanici_ids:
                diger_q = diger_q.filter(models.Analysis.user_id.in_(sirket_kullanici_ids))
        diger_ids = [r[0] for r in diger_q.all()]
        if not diger_ids:
            return {"adet": 0, "gorevler": [], "kapsam": secilen}
        sorgu = sorgu.filter(
            models.Task.analysis_id.in_(diger_ids),
            or_(
                models.Task.source == "ai",
                models.Task.source.is_(None),
                models.Task.source == "",
            ),
        )

    kayitlar = (
        sorgu
        .order_by(models.Task.created_at.desc(), models.Task.id.desc())
        .limit(200)
        .all()
    )
    atanan_ids = [
        g.assigned_user_id or g.user_id
        for g in kayitlar
        if (g.assigned_user_id or g.user_id)
    ]
    for g in kayitlar:
        if g.user_id:
            atanan_ids.append(g.user_id)
    analiz_ids = [g.analysis_id for g in kayitlar if g.analysis_id]
    analiz_sahip = {}
    analiz_kurum = {}
    if analiz_ids:
        for row in (
            db.query(models.Analysis.id, models.Analysis.user_id, models.Analysis.kurum_adi)
            .filter(models.Analysis.id.in_(analiz_ids))
            .all()
        ):
            analiz_sahip[row[0]] = row[1]
            if (row[2] or "").strip():
                analiz_kurum[row[0]] = row[2].strip()
            if row[1]:
                atanan_ids.append(row[1])
    etiketler = _kullanici_etiket_map(db, atanan_ids)
    gorevler = []
    for g in kayitlar:
        atanan_id = g.assigned_user_id or g.user_id
        sahip_id = analiz_sahip.get(g.analysis_id)
        kurum_adi = (g.kurum_adi or "").strip() or analiz_kurum.get(g.analysis_id)
        gorevler.append({
            "id": g.id,
            "baslik": g.title,
            "kaynak": g.source or "ai",
            "tamamlandi": bool(g.is_done),
            "tarih": g.created_at.isoformat() if g.created_at else None,
            "kurum_adi": kurum_adi,
            "user_id": g.user_id,
            "assigned_user_id": atanan_id,
            "assigned_user_name": etiketler.get(atanan_id) if atanan_id else None,
            "olusturan_adi": etiketler.get(g.user_id) if g.user_id else None,
            "gorusme_sahibi_id": sahip_id,
            "gorusme_sahibi_adi": etiketler.get(sahip_id) if sahip_id else None,
            "company_id": _gorev_sirket_id_coz(db, g),
            "due_date": g.due_date.isoformat() if getattr(g, "due_date", None) else None,
            "gorusme_id": g.analysis_id,
            "analysis_id": g.analysis_id,
        })
    return {"adet": len(gorevler), "gorevler": gorevler, "kapsam": secilen or "hepsi"}


@app.get("/api/gorevler")
def gorevleri_getir(
    kapsam: Optional[str] = Query(
        None,
        description="Admin görünümü: benim | ekip_gorusmeleri",
    ),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Veritabanına kayıtlı görevleri döndürür.

    User: kendi oluşturduğu / atandığı / kendi görüşmesinden çıkan görevler.
    Admin: `kapsam=benim` kendi işi; `kapsam=ekip_gorusmeleri` diğer
    çalışanların görüşmelerinden çıkarılan AI görevleri.
    """
    try:
        return _gorevleri_listele(db, current_user, kapsam)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def _gorev_dict(g: models.Task, db: Session) -> dict:
    atanan_id = g.assigned_user_id or g.user_id
    return {
        "id": g.id,
        "baslik": g.title,
        "kaynak": g.source or "ai",
        "tamamlandi": bool(g.is_done),
        "tarih": g.created_at.isoformat() if g.created_at else None,
        "kurum_adi": g.kurum_adi,
        "kurum_id": g.institution_id,
        "user_id": g.user_id,
        "assigned_user_id": atanan_id,
        "assigned_user_name": _kullanici_adi_al(db, atanan_id) if atanan_id else None,
        "company_id": g.company_id,
        "due_date": g.due_date.isoformat() if getattr(g, "due_date", None) else None,
        "gorusme_id": g.analysis_id,
        "analysis_id": g.analysis_id,
    }


def _kullanici_gorunen_ad(kullanici: Optional[models.User]) -> str:
    if not kullanici:
        return "Yönetici"
    return ((kullanici.ad_soyad or "").strip() or kullanici.kullanici_adi or "Yönetici")


def _bildirim_dict(kayit: models.Notification) -> dict:
    olusturma = getattr(kayit, "created_at", None)
    return {
        "id": kayit.id,
        "title": kayit.title or "",
        "body": kayit.body or "",
        "actor_name": kayit.actor_name or "",
        "task_id": kayit.task_id,
        "kind": kayit.kind or "gorev_atama",
        "is_read": bool(kayit.is_read),
        "created_at": olusturma.isoformat() if olusturma else None,
    }


def _atama_bildirimini_yaz(
    db: Session,
    hedef: models.User,
    gorev: models.Task,
    atayan: models.User,
) -> None:
    """Atanan kullanıcıya uygulama içi bildirim. Kendine atamada yazılmaz. FK yok."""
    if not hedef or not gorev or hedef.id == getattr(atayan, "id", None):
        return
    db.add(
        models.Notification(
            user_id=hedef.id,
            actor_id=getattr(atayan, "id", None),
            actor_name=_kullanici_gorunen_ad(atayan),
            task_id=gorev.id,
            title="Size yeni bir görev atandı",
            body=(gorev.title or "").strip() or None,
            kind="gorev_atama",
            is_read=False,
        )
    )


def _atama_mailini_kuyruga_al(
    background_tasks: BackgroundTasks,
    hedef: models.User,
    gorev: models.Task,
) -> None:
    """Atanan kullanıcının DB'deki e-postasına bildirim kuyruğa alınır."""
    eposta = (getattr(hedef, "email", None) or "").strip()
    if not eposta:
        eposta = kullanici_eposta_adresi(hedef) or ""
    if eposta and "@" in eposta:
        background_tasks.add_task(
            send_assignment_email,
            eposta,
            {
                "task_id": gorev.id,
                "baslik": gorev.title or "",
                "kurum_adi": gorev.kurum_adi or "",
                "atanan_ad": (hedef.ad_soyad or hedef.kullanici_adi or ""),
            },
        )
        logger.info(
            "Atama maili kuyruğa alındı: user_id=%s email=%s task_id=%s",
            hedef.id,
            eposta,
            gorev.id,
        )
        return
        logger.warning(
            "Atama maili kuyruğa alınmadı: kullanıcıda e-posta yok (user_id=%s, kadi=%s)",
            hedef.id,
            hedef.kullanici_adi,
        )


def _atama_push_kuyruga_al(
    background_tasks: BackgroundTasks,
    hedef: models.User,
    gorev: models.Task,
) -> None:
    """Atanan kullanıcının kayıtlı telefonlarına FCM kuyruğa alınır."""
    if not hedef or not getattr(hedef, "id", None) or not gorev:
        return
    background_tasks.add_task(
        send_assignment_push,
        int(hedef.id),
        "Size yeni bir görev atandı",
        (gorev.title or "").strip() or "CRM Analiz Portalı",
        gorev.id,
    )
    logger.info(
        "Atama FCM kuyruğa alındı: user_id=%s task_id=%s",
        hedef.id,
        gorev.id,
    )


@app.post("/api/tasks")  # legacy alias — tercih: /api/gorevler
@app.post("/api/tasks/manual")  # legacy alias
@app.post("/api/gorevler")
def gorev_ekle(
    veri: schemas.TaskCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Manuel görev ekler. Görüşme/toplantı bağlamak zorunlu değildir (analysis_id NULL).

    Kendine görev: assigned_user_id gönderilmez, görev oluşturana atanır.
    Personele görev (yalnızca admin): urun_id + assigned_user_id zorunlu.
    Çalışanın şirketi, seçilen ürünün şirketiyle aynı olmak zorundadır.
    """
    baslik = veri.baslik_al()
    if not baslik:
        raise HTTPException(status_code=400, detail="Görev başlığı zorunludur.")
    try:
        atanan = current_user
        sirket_id = getattr(current_user, "company_id", None)

        if veri.assigned_user_id is not None:
            if not _is_admin(current_user):
                raise HTTPException(
                    status_code=403,
                    detail="Yalnızca admin başkasına görev atayabilir.",
                )
            if not veri.urun_id:
                raise HTTPException(
                    status_code=400,
                    detail="Personele atamak için önce ürün seçin.",
                )
            urun = (
                db.query(models.Product)
                .filter(models.Product.id == int(veri.urun_id))
                .first()
            )
            if not urun:
                raise HTTPException(status_code=404, detail="Ürün bulunamadı")
            urun_sirket = getattr(urun, "company_id", None)
            if urun_sirket is None:
                raise HTTPException(
                    status_code=400,
                    detail="Bu ürünün şirket bilgisi eksik; atama yapılamaz.",
                )
            hedef = (
                db.query(models.User)
                .filter(models.User.id == int(veri.assigned_user_id))
                .first()
            )
            if not hedef:
                raise HTTPException(status_code=404, detail="Atanacak kullanıcı bulunamadı.")
            hedef_sirket = getattr(hedef, "company_id", None)
            if hedef_sirket is None or int(hedef_sirket) != int(urun_sirket):
                raise HTTPException(status_code=400, detail=ATAMA_SIRKET_HATASI)
            atanan = hedef
            sirket_id = urun_sirket
        kurum = _kurum_bul_veya_olustur(db, veri.kurum_adi) if (veri.kurum_adi or "").strip() else None
        analiz_id = veri.gorusme_id_al()
        if analiz_id is not None:
            analiz = (
                db.query(models.Analysis)
                .filter(
                    models.Analysis.id == analiz_id,
                    models.Analysis.is_deleted.is_(False),
                )
                .first()
            )
            if not analiz:
                raise HTTPException(status_code=404, detail="Görüşme bulunamadı")
            _analiz_erisim_kontrol(analiz, current_user)
        gorev = models.Task(
            title=baslik,
            source="manuel",
            is_done=False,
            analysis_id=analiz_id,
            institution_id=kurum.id if kurum else None,
            kurum_adi=_kurum_adi_al(kurum),
            due_date=veri.due_date,
            is_deleted=False,
            user_id=current_user.id,
            assigned_user_id=atanan.id,
            company_id=sirket_id,
        )
        db.add(gorev)
        db.flush()
        if veri.assigned_user_id is not None and atanan.id != current_user.id:
            _atama_bildirimini_yaz(db, atanan, gorev, current_user)
        db.commit()
        db.refresh(gorev)
        if veri.assigned_user_id is not None and atanan.id != current_user.id:
            _atama_mailini_kuyruga_al(background_tasks, atanan, gorev)
            _atama_push_kuyruga_al(background_tasks, atanan, gorev)
        return {"mesaj": "Görev eklendi", "gorev": _gorev_dict(gorev, db)}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/api/gorevler/{gorev_id}")
def gorev_guncelle(
    gorev_id: int,
    veri: schemas.TaskUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    gorev = _aktif(db.query(models.Task), models.Task).filter(models.Task.id == gorev_id).first()
    if not gorev:
        raise HTTPException(status_code=404, detail="Görev bulunamadı")
    _gorev_erisim_kontrol(db, gorev, current_user)
    try:
        if veri.baslik is not None:
            baslik = veri.baslik.strip()
            if not baslik:
                raise HTTPException(status_code=400, detail="Görev başlığı boş olamaz.")
            gorev.title = baslik
        if veri.kurum_adi is not None:
            ad = veri.kurum_adi.strip()
            kurum = _kurum_bul_veya_olustur(db, ad) if ad else None
            gorev.institution_id = kurum.id if kurum else None
            gorev.kurum_adi = _kurum_adi_al(kurum)
        if veri.tamamlandi is not None:
            gorev.is_done = bool(veri.tamamlandi)
            gorev.done_at = datetime.utcnow() if gorev.is_done else None
        db.commit()
        db.refresh(gorev)
        return {"mesaj": "Görev güncellendi", "gorev": _gorev_dict(gorev, db)}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@app.patch("/api/gorevler/{gorev_id}")
def gorev_yama(
    gorev_id: int,
    veri: schemas.TaskUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    return gorev_guncelle(gorev_id, veri, db, current_user)


@app.delete("/api/gorevler/{gorev_id}")
def gorev_sil(
    gorev_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    gorev = _aktif(db.query(models.Task), models.Task).filter(models.Task.id == gorev_id).first()
    if not gorev:
        raise HTTPException(status_code=404, detail="Görev bulunamadı")
    _gorev_erisim_kontrol(db, gorev, current_user)
    gorev.is_deleted = True
    db.commit()
    return {"mesaj": "Görev pasife alındı", "id": gorev.id}


@app.put("/api/tasks/{task_id}/assign", tags=["admin"])  # legacy alias — tercih: /api/gorevler/{id}/ata
@app.put("/api/gorevler/{task_id}/ata", tags=["admin"])
def gorev_ata(
    task_id: int,
    veri: schemas.TaskAssign,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(require_admin),
):
    """[Admin] Görevi bir personele atar. Şirketler birebir aynı olmak zorundadır.

    Atama kaydı yazıldıktan sonra e-posta BackgroundTasks ile gider; SMTP
    gecikmesi HTTP yanıtını bekletmez. Atanan kullanıcıya uygulama içi
    bildirim de yazılır.
    """
    gorev = _aktif(db.query(models.Task), models.Task).filter(models.Task.id == task_id).first()
    if not gorev:
        raise HTTPException(status_code=404, detail="Görev bulunamadı")

    hedef = db.query(models.User).filter(models.User.id == veri.assigned_user_id).first()
    if not hedef:
        raise HTTPException(status_code=404, detail="Atanmak istenen kullanıcı bulunamadı.")

    # KESİN güvenlik duvarı: görev.company_id === kullanıcı.company_id
    _atama_sirket_kontrol(db, gorev, hedef)

    onceki_atanan = gorev.assigned_user_id
    try:
        gorev.assigned_user_id = hedef.id
        if gorev.company_id is None and hedef.company_id is not None:
            gorev.company_id = hedef.company_id
        if onceki_atanan != hedef.id:
            _atama_bildirimini_yaz(db, hedef, gorev, current_user)
        db.commit()
        db.refresh(gorev)
        db.refresh(hedef)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

    _atama_mailini_kuyruga_al(background_tasks, hedef, gorev)
    if onceki_atanan != hedef.id and hedef.id != current_user.id:
        _atama_push_kuyruga_al(background_tasks, hedef, gorev)
    return {"mesaj": "Görev atandı", "gorev": _gorev_dict(gorev, db)}


@app.get("/api/bildirimler")
def bildirimleri_listele(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
    limit: int = Query(40, ge=1, le=100),
):
    """Giriş yapan kullanıcının bildirimleri (en yeni üstte)."""
    q = (
        db.query(models.Notification)
        .filter(models.Notification.user_id == current_user.id)
        .order_by(models.Notification.id.desc())
    )
    kayitlar = q.limit(limit).all()
    okunmamis = (
        db.query(func.count(models.Notification.id))
        .filter(
            models.Notification.user_id == current_user.id,
            models.Notification.is_read.is_(False),
        )
        .scalar()
        or 0
    )
    return {
        "okunmamis": int(okunmamis),
        "adet": len(kayitlar),
        "bildirimler": [_bildirim_dict(k) for k in kayitlar],
    }


@app.put("/api/bildirimler/okundu-hepsi")
def bildirimleri_okundu_isaretle(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    adet = (
        db.query(models.Notification)
        .filter(
            models.Notification.user_id == current_user.id,
            models.Notification.is_read.is_(False),
        )
        .update({models.Notification.is_read: True}, synchronize_session=False)
    )
    db.commit()
    return {"mesaj": "Bildirimler okundu işaretlendi", "adet": int(adet or 0)}


@app.put("/api/bildirimler/{bildirim_id}/okundu")
def bildirimi_okundu_isaretle(
    bildirim_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    kayit = (
        db.query(models.Notification)
        .filter(
            models.Notification.id == bildirim_id,
            models.Notification.user_id == current_user.id,
        )
        .first()
    )
    if not kayit:
        raise HTTPException(status_code=404, detail="Bildirim bulunamadı")
    kayit.is_read = True
    db.commit()
    db.refresh(kayit)
    return {"mesaj": "Bildirim okundu", "bildirim": _bildirim_dict(kayit)}


@app.post("/api/cihaz-token")
def cihaz_token_kaydet(
    veri: schemas.CihazTokenIn,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Giriş yapan kullanıcının FCM jetonunu kaydeder / günceller. FK yok."""
    jeton = (veri.token or "").strip()
    if len(jeton) < 20 or len(jeton) > 512:
        raise HTTPException(status_code=400, detail="Geçersiz cihaz jetonu.")
    platform = (veri.platform or "android").strip().lower()[:20] or "android"
    kayit = db.query(models.FcmToken).filter(models.FcmToken.token == jeton).first()
    if kayit:
        kayit.user_id = current_user.id
        kayit.platform = platform
        kayit.updated_at = datetime.utcnow()
    else:
        kayit = models.FcmToken(
            user_id=current_user.id,
            token=jeton,
            platform=platform,
        )
        db.add(kayit)
    db.commit()
    return {"mesaj": "Cihaz jetonu kaydedildi"}


@app.delete("/api/cihaz-token")
def cihaz_token_sil(
    token: str = Query(..., min_length=20, max_length=512),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Çıkışta bu cihazın FCM jetonunu siler."""
    jeton = (token or "").strip()
    if not jeton:
        return {"mesaj": "Jeton yok", "adet": 0}
    adet = (
        db.query(models.FcmToken)
        .filter(
            models.FcmToken.token == jeton,
            models.FcmToken.user_id == current_user.id,
        )
        .delete(synchronize_session=False)
    )
    db.commit()
    return {"mesaj": "Cihaz jetonu silindi", "adet": int(adet or 0)}


def _fcm_web_ayar_govde():
    cfg = fcm_ayarlari.web_firebase_config() if fcm_ayarlari.ENABLED else None
    vapid = fcm_ayarlari.WEB_VAPID_KEY if cfg else ""
    hazir = bool(cfg and vapid)
    return {
        "enabled": hazir,
        "firebase": cfg,
        "vapidKey": vapid if hazir else "",
    }


@app.get("/api/fcm-web-ayar")
def fcm_web_ayar():
    """Tarayıcı FCM genel ayarları (apiKey / vapid). Servis hesabı içermez."""
    return _fcm_web_ayar_govde()


@app.get("/api/fcm-web-ayar.js")
def fcm_web_ayar_js():
    """Service worker'ın importScripts ile okuduğu Firebase web ayarı."""
    govde = _fcm_web_ayar_govde()
    js = (
        "self.FIREBASE_WEB = {firebase};\n"
        "self.FIREBASE_VAPID_KEY = {vapid};\n"
        "self.FIREBASE_WEB_ENABLED = {enabled};\n"
    ).format(
        firebase=json.dumps(govde.get("firebase")),
        vapid=json.dumps(govde.get("vapidKey") or ""),
        enabled="true" if govde.get("enabled") else "false",
    )
    return Response(
        content=js,
        media_type="application/javascript; charset=utf-8",
        headers={
            "Cache-Control": "no-store",
            "Access-Control-Allow-Origin": "*",
        },
    )


@app.get("/api/companies", tags=["admin"])
def sirketleri_listele(
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    """[Admin] Tüm şirketleri listeler (kullanıcı formu dropdown için)."""
    sirketler = db.query(models.Company).order_by(models.Company.name.asc()).all()
    return {
        "adet": len(sirketler),
        "sirketler": [
            {
                "id": s.id,
                "name": s.name,
                "created_at": s.created_at.isoformat() if s.created_at else None,
            }
            for s in sirketler
        ],
    }


@app.get("/api/companies/{company_id}/users", tags=["admin"])
def sirket_kullanicilari(
    company_id: int,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    """[Admin] Yalnızca verilen şirkette çalışan kullanıcıları döndürür."""
    sirket = db.query(models.Company).filter(models.Company.id == company_id).first()
    if not sirket:
        raise HTTPException(status_code=404, detail="Şirket bulunamadı")
    kullanicilar = (
        db.query(models.User)
        .filter(models.User.company_id == company_id)
        .order_by(models.User.ad_soyad.asc(), models.User.kullanici_adi.asc())
        .all()
    )
    return {
        "company_id": sirket.id,
        "company_name": sirket.name,
        "adet": len(kullanicilar),
        "kullanicilar": [_kullanici_public_dict(u, sirket.name) for u in kullanicilar],
    }


@app.get("/api/notlardan-gorevler")  # legacy — yeni istemciler /api/gorevler kullanır
def notlardan_gorevler_legacy(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Kayıtlı görevleri döndürür. Kota koruması için Gemini çağrısı yapmaz."""
    return _gorevleri_listele(db, current_user)


# Bilinen tablolar için Türkçe etiket. Liste yine MySQL'deki gerçek
# tablolardan gelir; burada olmayan adlar tablo adıyla gösterilir.
TABLO_BASLIKLARI = {
    "institutions": "Kurumlar",
    "products": "Ürünler",
    "subscriptions": "Abonelikler",
    "trainings": "Eğitimler",
    "notes": "Notlar",
    "ai_voice_logs": "Ses kayıt logları",
    "analyses": "Analizler",
    "tasks": "Görevler",
    "users": "Kullanıcılar",
    "companies": "Şirketler",
    "notifications": "Bildirimler",
    "fcm_tokens": "Cihaz bildirim jetonları",
}
_TABLO_ADI_RE = re.compile(r"^[A-Za-z0-9_]+$")


def _tablo_hucre(deger):
    if deger is None:
        return None
    if isinstance(deger, datetime):
        return deger.isoformat()
    if isinstance(deger, date):
        return deger.isoformat()
    if isinstance(deger, dtime):
        return deger.isoformat()
    if isinstance(deger, Decimal):
        return str(deger)
    if isinstance(deger, (bytes, bytearray)):
        return deger.hex()
    if isinstance(deger, (dict, list)):
        return json.dumps(deger, ensure_ascii=False)
    if isinstance(deger, bool):
        return deger
    return deger


def _tablo_adini_dogrula(tablo_adi: str) -> str:
    ad = (tablo_adi or "").strip()
    if not _TABLO_ADI_RE.fullmatch(ad):
        raise HTTPException(status_code=404, detail="Tablo bulunamadı")
    return ad


def _veritabani_tablolari(db: Session):
    isimler = inspect(db.get_bind()).get_table_names()
    return [t for t in isimler if _TABLO_ADI_RE.fullmatch(t)]


@app.get("/api/tablolar")
def tablolari_listele(
    db: Session = Depends(get_db),
    _: models.User = Depends(get_current_user),
):
    return {
        "tablolar": [
            {"ad": ad, "baslik": TABLO_BASLIKLARI.get(ad, ad)}
            for ad in _veritabani_tablolari(db)
        ]
    }


@app.get("/api/tablolar/{tablo_adi}")
def tablo_satirlari(
    tablo_adi: str,
    db: Session = Depends(get_db),
    _: models.User = Depends(get_current_user),
):
    ad = _tablo_adini_dogrula(tablo_adi)
    if ad not in _veritabani_tablolari(db):
        raise HTTPException(status_code=404, detail="Tablo bulunamadı")
    bind = db.get_bind()
    kolonlar = [c["name"] for c in inspect(bind).get_columns(ad)]
    # Şifre hash'lerini asla dışarı verme
    kolonlar = [c for c in kolonlar if c != "sifre_hash"]
    quoted = "`" + ad.replace("`", "") + "`"
    kolon_sql = ", ".join("`" + c.replace("`", "") + "`" for c in kolonlar) if kolonlar else "*"
    order = " ORDER BY `id` DESC" if "id" in kolonlar else ""
    sonuc = db.execute(text(f"SELECT {kolon_sql} FROM {quoted}{order} LIMIT 500"))
    satirlar = []
    for row in sonuc.mappings().all():
        satirlar.append({k: _tablo_hucre(row.get(k)) for k in kolonlar})
    return {
        "ad": ad,
        "baslik": TABLO_BASLIKLARI.get(ad, ad),
        "kolonlar": kolonlar,
        "adet": len(satirlar),
        "kayitlar": satirlar,
    }


_GUNCELLENEMEZ_KOLONLAR = frozenset({
    "id",
    "sifre_hash",
    "created_at",
    "updated_at",
    "role",
    "company_id",
    "kullanici_adi",
    "email",
})


@app.put("/api/tablolar/{tablo_adi}/{kayit_id}", tags=["admin"])
def tablo_satir_guncelle(
    tablo_adi: str,
    kayit_id: int,
    govde: dict,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    """[Admin] Ham tablo görünümünden tek satır günceller."""
    ad = _tablo_adini_dogrula(tablo_adi)
    if ad not in _veritabani_tablolari(db):
        raise HTTPException(status_code=404, detail="Tablo bulunamadı")
    bind = db.get_bind()
    kolonlar = [c["name"] for c in inspect(bind).get_columns(ad) if c["name"] != "sifre_hash"]
    if "id" not in kolonlar:
        raise HTTPException(status_code=400, detail="Bu tabloda id kolonu yok")
    guncellenecek = {}
    for anahtar, deger in (govde or {}).items():
        if anahtar in kolonlar and anahtar not in _GUNCELLENEMEZ_KOLONLAR:
            guncellenecek[anahtar] = deger
    if not guncellenecek:
        raise HTTPException(status_code=400, detail="Güncellenecek alan yok")
    quoted = "`" + ad.replace("`", "") + "`"
    set_sql = ", ".join(
        "`" + k.replace("`", "") + "` = :" + k for k in guncellenecek
    )
    params = dict(guncellenecek)
    params["kid"] = kayit_id
    sonuc = db.execute(
        text(f"UPDATE {quoted} SET {set_sql} WHERE `id` = :kid"),
        params,
    )
    if sonuc.rowcount == 0:
        raise HTTPException(status_code=404, detail="Kayıt bulunamadı")
    db.commit()
    return {"mesaj": "Kayıt güncellendi", "id": kayit_id, "tablo": ad}


@app.post("/ai-ham-metin-isle/")
def ham_metin_isle_ve_kaydet(
    istek: schemas.HamMetinIstek,
    db: Session = Depends(get_db),
    _: models.User = Depends(get_current_user),
):
    try:
        llm_json = ai_service.metni_yapilandir(istek.metin)
        if not isinstance(llm_json, dict) or not llm_json.get("kurum_adi"):
            db.rollback()
            return {"hata": "İşlem başarısız", "detay": GECERSIZ_YANIT}
        
        aranan_isim = llm_json["kurum_adi"].strip()
        kurum = db.query(models.Institution).filter(models.Institution.name.ilike(aranan_isim)).first()
        
        if not kurum:
            kurum = models.Institution(name=aranan_isim, type=llm_json["kurum_türü"])
            db.add(kurum)
            db.flush()
            
        urun_kodu_str = (llm_json["urun_kodu"] or "").strip().upper()
        urun = db.query(models.Product).filter(models.Product.code == urun_kodu_str).first()
        
        if not urun:
            urun = models.Product(
                code=urun_kodu_str,
                name=f"{urun_kodu_str} Modülü",
                is_active=True,
                company_id=getattr(_, "company_id", None),
            )
            db.add(urun)
            db.flush()
            
        yeni_abonelik = models.Subscription(
            institution_id=kurum.id,
            product_id=urun.id,
            kurum_adi=_kurum_adi_al(kurum),
            urun_adi=urun.name if urun else None,
            start_date=llm_json["baslangic_tarihi"],
            end_date=llm_json["bitis_tarihi"],
            status="AKTIF",
            access_type="TAM_ERISIM"
        )
        db.add(yeni_abonelik)
        db.flush()
        
        yeni_egitim = models.Training(
            institution_id=kurum.id,
            subscription_id=yeni_abonelik.id,
            kurum_adi=_kurum_adi_al(kurum),
            training_type=llm_json["egitim_turu"],
            trigger_event="AI Otomatik Kayıt"
        )
        db.add(yeni_egitim)
        
        # NOT: Gemini artık "not_icerigi" (özet) alanı üretmiyor; asıl transkript
        # her zaman kullanıcının orijinal metni (istek.metin) olarak saklanıyor.
        yeni_not = models.Note(
            institution_id=kurum.id,
            kurum_adi=_kurum_adi_al(kurum),
            content=istek.metin
        )
        db.add(yeni_not)
        
        yeni_log = models.AIVoiceLog(
            institution_id=kurum.id,
            kurum_adi=_kurum_adi_al(kurum),
            raw_transcript=istek.metin,
            ai_parsed_json=llm_json,
            status="SUCCESS"
        )
        db.add(yeni_log)
        
        db.commit()
        
        return {
            "mesaj": "İşlem başarılı",
            "ai_ciktisi": llm_json
        }
        
    except Exception as e:
        db.rollback()
        return {"hata": "İşlem başarısız", "detay": str(e)}


# NOT: Ses dosyası kabul eden endpoint'ler (/api/upload-audio, /ai-ses-isle/) ve
# Whisper tabanlı `audio_service` sistemden tamamen kaldırıldı. Konuşma tanıma
# artık Flutter tarafında `speech_to_text` ile cihazda (on-device) yapılıyor;
# backend'e yalnızca nihai metin `/api/analyze-text` ile gönderiliyor.


# ─────────────────────────────────────────────────────────────────────────────
# ADMIN: Kullanıcı Yönetimi Endpoint'leri
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/api/kullanicilar", tags=["admin"])
def kullanicilari_listele(
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    """[Admin] Sistemdeki tüm kullanıcıların listesini döndürür (şifre_hash hariç)."""
    kullanicilar = db.query(models.User).order_by(models.User.id.asc()).all()
    adlar = _sirket_ad_haritasi(db, [u.company_id for u in kullanicilar])
    return {
        "adet": len(kullanicilar),
        "kullanicilar": [
            _kullanici_public_dict(u, adlar.get(u.company_id)) for u in kullanicilar
        ],
    }


@app.post("/api/kullanicilar", status_code=201, tags=["admin"])
def kullanici_ekle(
    veri: schemas.UserCreate,
    db: Session = Depends(get_db),
    _: models.User = Depends(require_admin),
):
    """[Admin] Yeni personel (role=user) veya admin ekler."""
    yeni = _kullanici_olustur(
        db,
        veri.kullanici_adi,
        veri.sifre,
        veri.ad_soyad,
        veri.role,
        company_id=getattr(veri, "company_id", None),
        email=getattr(veri, "email", None),
    )
    return {
        "mesaj": f"Kullanıcı '{yeni.kullanici_adi}' oluşturuldu.",
        "kullanici": _kullanici_public_dict(yeni),
    }


@app.delete("/api/kullanicilar/{kullanici_id}", tags=["admin"])
def kullanici_sil(
    kullanici_id: int,
    db: Session = Depends(get_db),
    current_admin: models.User = Depends(require_admin),
):
    """[Admin] Kullanıcıyı siler. Admin kendi hesabını silemez."""
    if kullanici_id == current_admin.id:
        raise HTTPException(status_code=400, detail="Kendi hesabınızı silemezsiniz.")
    kullanici = db.query(models.User).filter(models.User.id == kullanici_id).first()
    if not kullanici:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı.")
    if getattr(kullanici, "role", "user") == "admin":
        raise HTTPException(status_code=400, detail="Admin hesapları silinemez.")
    db.delete(kullanici)
    db.commit()
    return {"mesaj": f"Kullanıcı '{kullanici.kullanici_adi}' silindi."}


_WEB_KOK = Path(__file__).resolve().parent / "html5up-hyperspace"


@app.get("/")
def web_kok():
    """Portalı localhost'tan açmak web push için güvenli bağlam sağlar."""
    return RedirectResponse(url="/portal/login.html")


if _WEB_KOK.is_dir():
    app.mount(
        "/portal",
        StaticFiles(directory=str(_WEB_KOK), html=True),
        name="portal",
    )