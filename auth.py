"""
auth.py — JWT tabanlı kimlik doğrulama yardımcıları.

Bağımlılıklar: passlib[bcrypt], python-jose[cryptography]
"""
import hashlib
import os
from datetime import datetime, timedelta
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from database import get_db
import models

# ─── Ayarlar ──────────────────────────────────────────────────────────────────
_AINOTE_ENV = os.getenv("AINOTE_ENV", "development").strip().lower()
_DEV_JWT_FALLBACK = "ainote-dev-only-jwt-anahtari-degistirin"
_jwt_secret = (os.getenv("JWT_SECRET_KEY") or "").strip()
if not _jwt_secret:
    if _AINOTE_ENV == "production":
        raise RuntimeError(
            "JWT_SECRET_KEY ortam değişkeni production ortamında zorunludur."
        )
    _jwt_secret = _DEV_JWT_FALLBACK
SECRET_KEY = _jwt_secret
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "1440"))  # 24 saat

# ─── Şifre Hashing ────────────────────────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ─── OAuth2 Şeması ────────────────────────────────────────────────────────────
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")


def sifreyi_dogrula(duz_sifre: str, hashli_sifre: str) -> bool:
    return pwd_context.verify(duz_sifre, hashli_sifre)


def sifreyi_hashle(sifre: str) -> str:
    return pwd_context.hash(sifre)


def access_token_olustur(data: dict, expire_delta: Optional[timedelta] = None) -> str:
    kopyala = data.copy()
    if expire_delta:
        bitis = datetime.utcnow() + expire_delta
    else:
        bitis = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    kopyala.update({"exp": bitis})
    return jwt.encode(kopyala, SECRET_KEY, algorithm=ALGORITHM)


def token_pwd_ver(user: models.User) -> str:
    """Şifre değişince eski JWT'leri geçersiz kılmak için kısa parmak izi."""
    raw = (user.sifre_hash or "").encode("utf-8")
    return hashlib.sha256(raw).hexdigest()[:16]


def kullanici_token_olustur(user: models.User, expire_delta: Optional[timedelta] = None) -> str:
    return access_token_olustur(
        {"sub": user.kullanici_adi, "pv": token_pwd_ver(user)},
        expire_delta,
    )


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> models.User:
    kimlik_hatasi = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Kimlik dogrulamasi basarisiz",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        kullanici_adi: str = payload.get("sub")
        if not kullanici_adi:
            raise kimlik_hatasi
    except JWTError:
        raise kimlik_hatasi

    kullanici = (
        db.query(models.User)
        .filter(models.User.kullanici_adi == kullanici_adi)
        .first()
    )
    if not kullanici:
        raise kimlik_hatasi
    if payload.get("pv") != token_pwd_ver(kullanici):
        raise kimlik_hatasi
    return kullanici


def require_admin(
    current_user: models.User = Depends(get_current_user),
) -> models.User:
    """
    Sadece role='admin' olan kullanıcıların erişebileceği endpointler için
    Depends() ile kullanılır. Yetki yoksa 403 Forbidden fırlatır.
    """
    if getattr(current_user, "role", "user") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu işlem için yönetici yetkisi gereklidir.",
        )
    return current_user
