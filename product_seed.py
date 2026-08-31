"""Inseres ürün kataloğu ve veritabanı seed işlemleri."""

from typing import Optional

from sqlalchemy.orm import Session

import models
from enums import VARSAYILAN_URUN_KATALOGU

INSERES_PRODUCTS = VARSAYILAN_URUN_KATALOGU

# Eski/sentetik kodları güncel ürünlere eşle. Piri AI asla Piri Keşif Aracı'na bağlanmaz.
LEGACY_CODE_MAP = {
    "PiRE AI": "PIRI_AI",
    "PIRE AI": "PIRI_AI",
    "PIRI_KESIF": "PIRI",
    "PIRI_INTIHAL": "PIRI",
    "PLAGIARISM_PRO": "PIRI",
}

# Katalogdan çıkan veya demo seed ile basılmış ürünler restart'ta kapatılır.
PASIF_URUN_KODLARI = {
    "LIBDIS",
    "PLEKSNET",
    "NOVA_KATALOG",
    "NOVA_ANALIZ",
    "KIRACI_B_PORTAL",
    *LEGACY_CODE_MAP.keys(),
}


def _upsert_product(
    db: Session,
    code: str,
    name: str,
    is_active: bool = True,
    company_id: Optional[int] = None,
) -> models.Product:
    code = code.strip().upper()
    urun = db.query(models.Product).filter(models.Product.code == code).first()
    if urun:
        urun.name = name
        urun.is_active = is_active
        if company_id:
            urun.company_id = company_id
    else:
        urun = models.Product(
            code=code,
            name=name,
            is_active=is_active,
            company_id=company_id,
        )
        db.add(urun)
        db.flush()
    return urun


def seed_inseres_products(db: Session, company_id: Optional[int] = None) -> dict:
    """Inseres ürünlerini ekler/günceller; eski kayıtları yeni koda taşır."""
    hedef_urunler = {}
    for kayit in INSERES_PRODUCTS:
        urun = _upsert_product(db, kayit["code"], kayit["name"], True, company_id)
        hedef_urunler[kayit["code"]] = urun

    for eski_kod, yeni_kod in LEGACY_CODE_MAP.items():
        eski = db.query(models.Product).filter(models.Product.code == eski_kod).first()
        if not eski:
            continue
        hedef = hedef_urunler.get(yeni_kod)
        if hedef and eski.id != hedef.id:
            db.query(models.Subscription).filter(
                models.Subscription.product_id == eski.id
            ).update({"product_id": hedef.id}, synchronize_session=False)
            eski.is_active = False
        elif not hedef:
            eski.is_active = False

    if PASIF_URUN_KODLARI:
        db.query(models.Product).filter(
            models.Product.code.in_(list(PASIF_URUN_KODLARI))
        ).update({"is_active": False}, synchronize_session=False)

    # Admin'in /api/urunler ile eklediği diğer ürünler restart'ta kapatılmaz.

    db.commit()
    aktif = (
        db.query(models.Product)
        .filter(models.Product.is_active.is_(True))
        .order_by(models.Product.name.asc())
        .all()
    )
    return {
        "aktif_urun_sayisi": len(aktif),
        "urunler": [{"id": u.id, "code": u.code, "name": u.name} for u in aktif],
    }


def aktif_urun_kodlari(db: Session) -> list:
    return [u["code"] for u in aktif_urun_katalogu(db)]


def aktif_urun_katalogu(db: Session) -> list:
    urunler = (
        db.query(models.Product)
        .filter(models.Product.is_active.is_(True))
        .order_by(models.Product.name.asc())
        .all()
    )
    return [{"code": u.code, "name": u.name} for u in urunler]
