from sqlalchemy import Column, Integer, String, Boolean, Date, Time, Text, JSON, TIMESTAMP, DateTime, ForeignKey
from sqlalchemy.sql import func
from database import Base
from datetime import datetime

# Çoklu kiracı: users / tasks / products → companies.id Foreign Key.
# Diğer sayısal *_id alanları (institution_id, analysis_id vb.) uygulama
# katmanında tutulur; her satır görüntülenmek için gereken adı (kurum_adi /
# urun_adi) kendi üzerinde taşır.


class Company(Base):
    """Çoklu şirket (multi-tenant) kök kaydı."""
    __tablename__ = "companies"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False, unique=True, index=True)
    created_at = Column(TIMESTAMP, server_default=func.now())


class User(Base):
    """Uygulama kullanıcıları — company_id ile şirket ağacına bağlı."""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    kullanici_adi = Column(String(100), unique=True, nullable=False, index=True)
    sifre_hash = Column(String(255), nullable=False)
    ad_soyad = Column(String(255), nullable=True)
    # "admin" veya "user" — varsayılan: "user"
    role = Column(String(20), nullable=False, default="user", server_default="user")
    company_id = Column(Integer, ForeignKey("companies.id"), index=True, nullable=True)
    # Atama bildirimi için zorunlu hedef alan; unique + index
    email = Column(String(255), unique=True, index=True, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())


class Institution(Base):
    __tablename__ = "institutions"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    type = Column(String(50))
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())


class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(50), unique=True, nullable=False)
    name = Column(String(150), nullable=False)
    is_active = Column(Boolean, default=True)
    company_id = Column(Integer, ForeignKey("companies.id"), index=True, nullable=True)


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    institution_id = Column(Integer, index=True, nullable=True)
    product_id = Column(Integer, index=True, nullable=True)
    kurum_adi = Column(String(255))
    urun_adi = Column(String(150))
    access_type = Column(String(50))
    status = Column(String(50))
    start_date = Column(Date, nullable=True)
    end_date = Column(Date, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())


class Training(Base):
    __tablename__ = "trainings"

    id = Column(Integer, primary_key=True, index=True)
    institution_id = Column(Integer, index=True, nullable=True)
    subscription_id = Column(Integer, index=True, nullable=True)
    kurum_adi = Column(String(255))
    training_type = Column(String(50))
    planned_date = Column(Date, nullable=True)
    planned_time = Column(Time, nullable=True)
    trigger_event = Column(String(255))
    is_mail_sent = Column(Boolean, default=False)
    created_at = Column(TIMESTAMP, server_default=func.now())


class Note(Base):
    __tablename__ = "notes"

    id = Column(Integer, primary_key=True, index=True)
    institution_id = Column(Integer, index=True, nullable=True)
    kurum_adi = Column(String(255))
    note_key = Column(String(50))
    content = Column(Text)
    created_by = Column(String(50))
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())


class AIVoiceLog(Base):
    __tablename__ = "ai_voice_logs"

    id = Column(Integer, primary_key=True, index=True)
    institution_id = Column(Integer, nullable=True)
    kurum_adi = Column(String(255))
    raw_transcript = Column(Text, nullable=False)
    ai_parsed_json = Column(JSON, nullable=False)
    status = Column(String(50), default="SUCCESS")
    created_at = Column(DateTime, default=datetime.utcnow)


class Analysis(Base):
    __tablename__ = "analyses"

    id = Column(Integer, primary_key=True, index=True)
    institution_id = Column(Integer, index=True, nullable=True)
    # Görüşmeyi oluşturan kullanıcı — FK constraint YOKTUR, bağımsız integer.
    user_id = Column(Integer, index=True, nullable=True)
    ham_metin = Column(Text, nullable=False)
    kurum_adi = Column(String(255))
    # "Olumlu", "Olumsuz", "Karma" veya "Beklemede" (bkz. enums.GorusmeDurumu)
    durum = Column(String(50))
    urun_kodu = Column(String(50))
    urun_adi = Column(String(150))
    # "Deneme", "Abonelik" veya "Hiçbiri"
    surec_tipi = Column(String(50), default="Hiçbiri")
    # Geriye dönük uyumluluk: surec_tipi ile aynı değer tutulur.
    abonelik_tipi = Column(String(50), default="Hiçbiri")
    ilgilenilen_urunler = Column(JSON)
    kaynak = Column(String(50), default="ai")
    ai_json = Column(JSON)
    is_deleted = Column(Boolean, default=False, nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())


class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    analysis_id = Column(Integer, index=True, nullable=True)  # görüşme/toplantı; manuel görevde NULL
    institution_id = Column(Integer, index=True, nullable=True)
    kurum_adi = Column(String(255))
    title = Column(String(500), nullable=False)
    source = Column(String(50), default="ai")
    is_done = Column(Boolean, default=False)
    done_at = Column(DateTime, nullable=True)
    due_date = Column(Date, nullable=True)
    is_deleted = Column(Boolean, default=False, nullable=False)
    # Görevi oluşturan kullanıcı — FK constraint YOKTUR.
    user_id = Column(Integer, index=True, nullable=True)
    # Görevin atandığı personel.
    assigned_user_id = Column(Integer, index=True, nullable=True)
    company_id = Column(Integer, ForeignKey("companies.id"), index=True, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())


class Notification(Base):
    """Uygulama içi bildirim — FK yok; user_id / task_id uygulama katmanında tutulur."""
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True, nullable=False)
    actor_id = Column(Integer, index=True, nullable=True)
    actor_name = Column(String(255))
    task_id = Column(Integer, index=True, nullable=True)
    title = Column(String(500), nullable=False)
    body = Column(String(1000))
    kind = Column(String(50), default="gorev_atama")
    is_read = Column(Boolean, default=False, nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())


class FcmToken(Base):
    """Cihazın FCM kayıt jetonu — FK yok; user_id uygulama katmanında tutulur."""
    __tablename__ = "fcm_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True, nullable=False)
    token = Column(String(512), unique=True, nullable=False, index=True)
    platform = Column(String(20), default="android")
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())
