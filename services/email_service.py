"""Görev atama e-posta bildirimi — SMTP hataları API isteğini asla düşürmez."""
import html
import logging
import smtplib
from email.message import EmailMessage
from typing import Any, Dict, Optional

from app.core.config import smtp_ayarlari

logger = logging.getLogger("ainote.email")


def _metin_govde(detay: Dict[str, Any]) -> str:
    ad = detay.get("atanan_ad") or "Personel"
    baslik = detay.get("baslik") or "Yeni görev"
    kurum = detay.get("kurum_adi") or ""
    kurum_satir = f"Kurum: {kurum}\n" if kurum else ""
    return (
        f"Merhaba {ad},\n\n"
        f"Size yeni bir görev atandı.\n\n"
        f"{kurum_satir}"
        f"Görev: {baslik}\n\n"
        f"Detayları CRM Analiz Portalı üzerindeki Görevler sayfasından görebilirsiniz.\n\n"
        f"— CRM Analiz Portalı\n"
    )


def _html_govde(detay: Dict[str, Any]) -> str:
    ad = html.escape(str(detay.get("atanan_ad") or "Personel"))
    baslik = html.escape(str(detay.get("baslik") or "Yeni görev"))
    kurum = html.escape(str(detay.get("kurum_adi") or "").strip())
    kurum_html = (
        f'<p style="margin:0 0 8px;color:#9ca8c4;font-size:13px;">Kurum: '
        f"<strong style=\"color:#e8eefc;\">{kurum}</strong></p>"
        if kurum
        else ""
    )
    return f"""\
<!DOCTYPE html>
<html lang="tr">
<body style="margin:0;padding:0;background:#0f1524;font-family:Segoe UI,Helvetica,Arial,sans-serif;">
  <div style="max-width:560px;margin:24px auto;padding:28px 24px;background:#161d31;
              border:1px solid #2a3554;border-radius:12px;color:#e8eefc;">
    <p style="margin:0 0 6px;color:#7dd3fc;font-size:12px;letter-spacing:.12em;text-transform:uppercase;">
      CRM Analiz Portalı
    </p>
    <h1 style="margin:0 0 16px;font-size:20px;font-weight:600;">Yeni görev atandı</h1>
    <p style="margin:0 0 16px;line-height:1.55;">Merhaba {ad}, yöneticiniz size bir görev atadı.</p>
    {kurum_html}
    <div style="margin:16px 0;padding:14px 16px;background:#1e2740;border-left:3px solid #7dd3fc;
                border-radius:8px;font-size:15px;line-height:1.5;">{baslik}</div>
    <p style="margin:16px 0 0;color:#9ca8c4;font-size:13px;line-height:1.5;">
      Görevi portalın Görevler sayfasından görüntüleyebilir ve tamamlandı olarak işaretleyebilirsiniz.
    </p>
  </div>
</body>
</html>
"""


def send_assignment_email(user_email: str, task_details: dict) -> None:
    """Atama bildirimi gönderir. SMTP hataları yutulur; yalnızca logger'a yazılır.

    FastAPI BackgroundTasks ile senkron çağrılır; yanıt zaten dönmüş olur.
    """
    try:
        eposta = (user_email or "").strip()
        if not eposta or "@" not in eposta:
            logger.warning("Atama maili atlandı: geçersiz e-posta (%r)", user_email)
            return
        if not smtp_ayarlari.ENABLED:
            logger.info("Atama maili atlandı: SMTP_ENABLED=false (%s)", eposta)
            return
        if not smtp_ayarlari.USERNAME or not smtp_ayarlari.PASSWORD:
            logger.warning(
                "Atama maili atlandı: SMTP_USERNAME / SMTP_PASSWORD .env içinde tanımlı değil."
            )
            return

        detay = task_details or {}
        gonderen = smtp_ayarlari.FROM_EMAIL or smtp_ayarlari.USERNAME
        konu = "Size yeni bir görev atandı"
        if detay.get("kurum_adi"):
            konu = f"Yeni görev atandı — {detay.get('kurum_adi')}"

        msg = EmailMessage()
        msg["Subject"] = konu
        msg["From"] = f"{smtp_ayarlari.FROM_NAME} <{gonderen}>"
        msg["To"] = eposta
        msg.set_content(_metin_govde(detay), charset="utf-8")
        msg.add_alternative(_html_govde(detay), subtype="html", charset="utf-8")

        with smtplib.SMTP(
            smtp_ayarlari.HOST,
            smtp_ayarlari.PORT,
            timeout=smtp_ayarlari.TIMEOUT,
        ) as sunucu:
            sunucu.ehlo()
            if smtp_ayarlari.USE_TLS:
                sunucu.starttls()
                sunucu.ehlo()
            sunucu.login(smtp_ayarlari.USERNAME, smtp_ayarlari.PASSWORD)
            sunucu.send_message(msg)

        logger.info("Atama maili gönderildi: %s (görev=%s)", eposta, detay.get("task_id"))
    except Exception:
        logger.exception(
            "Atama maili gönderilemedi (SMTP). Görev ataması etkilenmedi. alici=%s",
            user_email,
        )


def kullanici_eposta_adresi(kullanici: Any) -> Optional[str]:
    """Kullanıcı kaydından gönderilebilir bir e-posta üretir."""
    if not kullanici:
        return None
    eposta = (getattr(kullanici, "email", None) or "").strip()
    if eposta and "@" in eposta:
        return eposta
    kadi = (getattr(kullanici, "kullanici_adi", None) or "").strip()
    if "@" in kadi:
        return kadi
    return None
