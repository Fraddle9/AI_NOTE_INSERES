"""Görev atama FCM bildirimi — kimlik yoksa veya hata olursa API isteğini düşürmez."""
import logging
from pathlib import Path
from typing import List, Optional

from app.core.config import fcm_ayarlari
from database import SessionLocal
import models

logger = logging.getLogger("ainote.fcm")

_firebase_app = None
_init_denendi = False

try:
    import firebase_admin
    from firebase_admin import credentials, messaging

    _HAS_ADMIN = True
except ImportError:
    firebase_admin = None  # type: ignore
    credentials = None  # type: ignore
    messaging = None  # type: ignore
    _HAS_ADMIN = False


def _proje_koku() -> Path:
    return Path(__file__).resolve().parents[1]


def _kimlik_dosyasi() -> Optional[Path]:
    ham = (fcm_ayarlari.CREDENTIALS_PATH or "").strip()
    if ham:
        yol = Path(ham).expanduser()
        if not yol.is_absolute():
            yol = _proje_koku() / yol
        return yol if yol.is_file() else None
    for ad in ("firebase-service-account.json", "serviceAccountKey.json"):
        aday = _proje_koku() / ad
        if aday.is_file():
            return aday
    return None


def _hazir_et() -> bool:
    """firebase-admin'i bir kez başlatır. Kimlik yoksa False döner, çökmez."""
    global _firebase_app, _init_denendi
    if not fcm_ayarlari.ENABLED:
        return False
    if not _HAS_ADMIN:
        if not _init_denendi:
            logger.info("FCM atlandı: firebase-admin yüklü değil (`pip install firebase-admin`).")
            _init_denendi = True
        return False
    if _firebase_app is not None:
        return True
    if _init_denendi:
        return False
    _init_denendi = True
    yol = _kimlik_dosyasi()
    if yol is None:
        logger.info(
            "FCM atlandı: servis hesabı JSON yok. "
            "FIREBASE_CREDENTIALS veya proje kökünde firebase-service-account.json bekleniyor."
        )
        return False
    try:
        if firebase_admin._apps:
            _firebase_app = firebase_admin.get_app()
        else:
            _firebase_app = firebase_admin.initialize_app(credentials.Certificate(str(yol)))
        logger.info("FCM hazır (kimlik: %s)", yol.name)
        return True
    except Exception:
        logger.exception("FCM başlatılamadı (%s)", yol)
        return False


def _gecersiz_jeton_mu(exc: BaseException) -> bool:
    ad = type(exc).__name__.lower()
    metin = str(exc).lower()
    if "unregistered" in ad or "notfound" in ad or "not_found" in ad:
        return True
    if any(p in metin for p in ("unregistered", "not-found", "not_found", "requested entity was not found")):
        return True
    return False


def _gonder(tokens: List[str], title: str, body: str, task_id: Optional[int]) -> List[str]:
    """Başarılı gönderimleri yapar; geçersiz jetonları döner."""
    gecersiz: List[str] = []
    veri = {
        "kind": "gorev_atama",
        "task_id": str(task_id or ""),
    }
    mesajlar = [
        messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=veri,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="gorev_atama",
                    sound="default",
                ),
            ),
            webpush=messaging.WebpushConfig(
                headers={"Urgency": "high", "TTL": "86400"},
                fcm_options=(
                    messaging.WebpushFCMOptions(link=fcm_ayarlari.WEB_CLICK_URL)
                    if fcm_ayarlari.WEB_CLICK_URL
                    else None
                ),
            ),
            token=jeton,
        )
        for jeton in tokens
    ]
    # send_each en fazla 500 mesaj kabul eder.
    for i in range(0, len(mesajlar), 500):
        paket = mesajlar[i : i + 500]
        dilim = tokens[i : i + 500]
        sonuc = messaging.send_each(paket)
        for j, yanit in enumerate(sonuc.responses):
            if yanit.success:
                continue
            hata = yanit.exception
            if hata is not None and _gecersiz_jeton_mu(hata):
                gecersiz.append(dilim[j])
            else:
                logger.warning("FCM gönderilemedi (%s): %s", dilim[j][:18], hata)
    return gecersiz


def send_assignment_push(
    user_id: int,
    title: str,
    body: str,
    task_id: Optional[int] = None,
) -> None:
    """Atanan kullanıcının kayıtlı cihazlarına FCM yollar.

    FastAPI BackgroundTasks ile senkron çağrılır; kendi DB oturumunu açar.
    Hatalar yutulur.
    """
    try:
        if not _hazir_et():
            return
        baslik = (title or "").strip() or "Size yeni bir görev atandı"
        govde = (body or "").strip() or "CRM Analiz Portalı"
        db = SessionLocal()
        try:
            kayitlar = (
                db.query(models.FcmToken)
                .filter(models.FcmToken.user_id == int(user_id))
                .all()
            )
            tokens = [ (k.token or "").strip() for k in kayitlar ]
            tokens = [t for t in tokens if t]
            if not tokens:
                logger.info("FCM atlandı: user_id=%s için kayıtlı cihaz yok", user_id)
                return
            gecersiz = _gonder(tokens, baslik, govde, task_id)
            logger.info(
                "FCM gönderildi: user_id=%s cihaz=%s gecersiz=%s task_id=%s",
                user_id,
                len(tokens),
                len(gecersiz),
                task_id,
            )
            if gecersiz:
                db.query(models.FcmToken).filter(models.FcmToken.token.in_(gecersiz)).delete(
                    synchronize_session=False
                )
                db.commit()
        finally:
            db.close()
    except Exception:
        logger.exception("FCM gönderimi başarısız (user_id=%s)", user_id)
