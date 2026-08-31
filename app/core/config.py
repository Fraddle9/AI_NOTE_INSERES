"""SMTP ve diğer gizli ayarlar — değerler .env / ortam değişkenlerinden okunur."""
import os
from pathlib import Path


def _env_dosyasini_yukle(dosya: Path) -> None:
    """python-dotenv olmadan KEY=VALUE satırlarını yükler (database.py ile aynı desen)."""
    if not dosya.exists():
        return
    for satir in dosya.read_text(encoding="utf-8").splitlines():
        satir = satir.strip()
        if not satir or satir.startswith("#") or "=" not in satir:
            continue
        anahtar, _, deger = satir.partition("=")
        os.environ.setdefault(anahtar.strip(), deger.strip().strip("\"'"))


_env_dosyasini_yukle(Path(__file__).resolve().parents[2] / ".env")


def _bool(deger: str, varsayilan: bool = True) -> bool:
    if deger is None or str(deger).strip() == "":
        return varsayilan
    return str(deger).strip().lower() in ("1", "true", "yes", "on")


class SMTPAyarlari:
    """Gmail test varsayılanları: smtp.gmail.com:587 (STARTTLS)."""

    HOST: str = os.getenv("SMTP_HOST", "smtp.gmail.com")
    PORT: int = int(os.getenv("SMTP_PORT", "587") or "587")
    USERNAME: str = os.getenv("SMTP_USERNAME", "")
    PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    FROM_EMAIL: str = os.getenv("SMTP_FROM", "") or os.getenv("SMTP_USERNAME", "")
    FROM_NAME: str = os.getenv("SMTP_FROM_NAME", "CRM Analiz Portalı")
    USE_TLS: bool = _bool(os.getenv("SMTP_USE_TLS", "true"), True)
    TIMEOUT: int = int(os.getenv("SMTP_TIMEOUT", "20") or "20")
    ENABLED: bool = _bool(os.getenv("SMTP_ENABLED", "true"), True)


smtp_ayarlari = SMTPAyarlari()


class FcmAyarlari:
    """Firebase Cloud Messaging — kimlik yoksa push sessizce atlanır."""

    ENABLED: bool = _bool(os.getenv("FCM_ENABLED", "true"), True)
    CREDENTIALS_PATH: str = (
        os.getenv("FIREBASE_CREDENTIALS")
        or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        or ""
    ).strip()
    WEB_API_KEY: str = os.getenv("FIREBASE_WEB_API_KEY", "").strip()
    WEB_AUTH_DOMAIN: str = os.getenv("FIREBASE_WEB_AUTH_DOMAIN", "").strip()
    WEB_PROJECT_ID: str = os.getenv("FIREBASE_WEB_PROJECT_ID", "").strip()
    WEB_STORAGE_BUCKET: str = os.getenv("FIREBASE_WEB_STORAGE_BUCKET", "").strip()
    WEB_MESSAGING_SENDER_ID: str = os.getenv("FIREBASE_WEB_MESSAGING_SENDER_ID", "").strip()
    WEB_APP_ID: str = os.getenv("FIREBASE_WEB_APP_ID", "").strip()
    WEB_VAPID_KEY: str = os.getenv("FIREBASE_WEB_VAPID_KEY", "").strip()
    WEB_CLICK_URL: str = os.getenv("FIREBASE_WEB_CLICK_URL", "").strip()

    def web_firebase_config(self):
        """Tarayıcıya gidecek genel Firebase web ayarı. Eksikse None."""
        if not self.WEB_API_KEY or not self.WEB_MESSAGING_SENDER_ID or not self.WEB_APP_ID:
            return None
        cfg = {
            "apiKey": self.WEB_API_KEY,
            "authDomain": self.WEB_AUTH_DOMAIN,
            "projectId": self.WEB_PROJECT_ID,
            "storageBucket": self.WEB_STORAGE_BUCKET,
            "messagingSenderId": self.WEB_MESSAGING_SENDER_ID,
            "appId": self.WEB_APP_ID,
        }
        return {k: v for k, v in cfg.items() if v}

    def web_push_hazir(self) -> bool:
        return bool(self.web_firebase_config() and self.WEB_VAPID_KEY)


fcm_ayarlari = FcmAyarlari()
