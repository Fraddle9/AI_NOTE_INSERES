import os
from pathlib import Path

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base

VARSAYILAN_DATABASE_URL = "mysql+pymysql://root:@localhost:3306/CRM_AI?charset=utf8mb4"


def _env_dosyasini_yukle(dosya: Path = Path(__file__).with_name(".env")) -> None:
    """python-dotenv bağımlılığı olmadan .env dosyasındaki KEY=VALUE satırlarını okur."""
    if not dosya.exists():
        return
    for satir in dosya.read_text(encoding="utf-8").splitlines():
        satir = satir.strip()
        if not satir or satir.startswith("#") or "=" not in satir:
            continue
        anahtar, _, deger = satir.partition("=")
        os.environ.setdefault(anahtar.strip(), deger.strip().strip("\"'"))


_env_dosyasini_yukle()

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", VARSAYILAN_DATABASE_URL)
engine = create_engine(SQLALCHEMY_DATABASE_URL, pool_pre_ping=True)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _kolon_var_mi(conn, tablo, kolon):
    satir = conn.execute(
        text(
            "SELECT COUNT(*) FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :tablo AND COLUMN_NAME = :kolon"
        ),
        {"tablo": tablo, "kolon": kolon},
    ).scalar()
    return bool(satir)


def _tablo_var_mi(conn, tablo):
    satir = conn.execute(
        text(
            "SELECT COUNT(*) FROM information_schema.TABLES "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :tablo"
        ),
        {"tablo": tablo},
    ).scalar()
    return bool(satir)


def _kolon_ekle(conn, tablo, kolon, ddl):
    if _tablo_var_mi(conn, tablo) and not _kolon_var_mi(conn, tablo, kolon):
        conn.execute(text(f"ALTER TABLE `{tablo}` ADD COLUMN `{kolon}` {ddl}"))


def _indeks_var_mi(conn, tablo, indeks_adi):
    satir = conn.execute(
        text(
            "SELECT COUNT(*) FROM information_schema.STATISTICS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :tablo "
            "AND INDEX_NAME = :indeks"
        ),
        {"tablo": tablo, "indeks": indeks_adi},
    ).scalar()
    return bool(satir)


def _fk_var_mi(conn, tablo, fk_adi):
    satir = conn.execute(
        text(
            "SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :tablo "
            "AND CONSTRAINT_NAME = :fk AND CONSTRAINT_TYPE = 'FOREIGN KEY'"
        ),
        {"tablo": tablo, "fk": fk_adi},
    ).scalar()
    return bool(satir)


def _unique_indeks_ekle(conn, tablo, kolon, indeks_adi):
    if not _tablo_var_mi(conn, tablo) or not _kolon_var_mi(conn, tablo, kolon):
        return
    if _indeks_var_mi(conn, tablo, indeks_adi):
        return
    # Yinelenen dolu e-postalar unique index'i kırar — önce uyar.
    tekrar = conn.execute(
        text(
            f"SELECT `{kolon}`, COUNT(*) AS adet FROM `{tablo}` "
            f"WHERE `{kolon}` IS NOT NULL AND TRIM(`{kolon}`) <> '' "
            f"GROUP BY `{kolon}` HAVING adet > 1 LIMIT 5"
        )
    ).fetchall()
    if tekrar:
        print(
            f"[Schema UYARI] `{tablo}.{kolon}` üzerinde yinelenen değerler var; "
            f"unique index eklenemedi: {tekrar}"
        )
        return
    conn.execute(text(f"CREATE UNIQUE INDEX `{indeks_adi}` ON `{tablo}` (`{kolon}`)"))
    print(f"[Schema] Unique index eklendi: {tablo}.{kolon} → {indeks_adi}")


def _fk_ekle(conn, tablo, kolon, ref_tablo, fk_adi):
    """company_id → companies.id FK. Yetim satır varsa uyarır, eklemez."""
    if not (
        _tablo_var_mi(conn, tablo)
        and _kolon_var_mi(conn, tablo, kolon)
        and _tablo_var_mi(conn, ref_tablo)
    ):
        return
    if _fk_var_mi(conn, tablo, fk_adi):
        return
    yetim = conn.execute(
        text(
            f"SELECT COUNT(*) FROM `{tablo}` t "
            f"LEFT JOIN `{ref_tablo}` r ON r.id = t.`{kolon}` "
            f"WHERE t.`{kolon}` IS NOT NULL AND r.id IS NULL"
        )
    ).scalar()
    if yetim:
        print(
            f"[Schema UYARI] `{tablo}.{kolon}` için {yetim} yetim kayıt var; "
            f"Foreign Key `{fk_adi}` eklenmedi. Önce company_id değerlerini düzeltin."
        )
        return
    conn.execute(
        text(
            f"ALTER TABLE `{tablo}` "
            f"ADD CONSTRAINT `{fk_adi}` FOREIGN KEY (`{kolon}`) "
            f"REFERENCES `{ref_tablo}` (`id`) "
            f"ON DELETE SET NULL ON UPDATE CASCADE"
        )
    )
    print(f"[Schema] Foreign Key eklendi: {tablo}.{kolon} → {ref_tablo}.id")


def _kolon_sil(conn, tablo, kolon):
    if _tablo_var_mi(conn, tablo) and _kolon_var_mi(conn, tablo, kolon):
        conn.execute(text(f"ALTER TABLE `{tablo}` DROP COLUMN `{kolon}`"))


def ensure_schema():
    """Mevcut MySQL tablolarını modellerle hizalar; multi-tenant FK/index ekler."""
    eklemeler = {
        "analyses": [
            ("urun_adi", "VARCHAR(150) NULL"),
            ("kaynak", "VARCHAR(50) NULL DEFAULT 'ai'"),
            ("abonelik_tipi", "VARCHAR(50) NULL DEFAULT 'Hiçbiri'"),
            ("surec_tipi", "VARCHAR(50) NULL DEFAULT 'Hiçbiri'"),
            ("ilgilenilen_urunler", "JSON NULL"),
            ("updated_at", "TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
            ("is_deleted", "TINYINT(1) NOT NULL DEFAULT 0"),
            # Çok-kullanıcılı destek: kayıt sahibi (FK constraint YOK)
            ("user_id", "INT NULL"),
        ],
        "tasks": [
            ("is_deleted", "TINYINT(1) NOT NULL DEFAULT 0"),
            ("kurum_adi", "VARCHAR(255) NULL"),
            ("user_id", "INT NULL"),
            ("assigned_user_id", "INT NULL"),
            ("company_id", "INT NULL"),
            ("due_date", "DATE NULL"),
        ],
        "products": [
            ("company_id", "INT NULL"),
        ],
        "notes": [("kurum_adi", "VARCHAR(255) NULL")],
        "subscriptions": [
            ("kurum_adi", "VARCHAR(255) NULL"),
            ("urun_adi", "VARCHAR(150) NULL"),
        ],
        "trainings": [("kurum_adi", "VARCHAR(255) NULL")],
        "ai_voice_logs": [("kurum_adi", "VARCHAR(255) NULL")],
    }
    silmeler = {
        "institutions": ["is_deleted"],
        "notes": ["is_deleted"],
        "subscriptions": ["is_deleted"],
        "trainings": ["is_deleted"],
        "ai_voice_logs": ["is_deleted", "audio_file_url"],
    }
    with engine.begin() as conn:
        # users tablosunu oluştur (yoksa)
        _users_tablosu_olustur(conn)
        _companies_tablosu_olustur(conn)
        _notifications_tablosu_olustur(conn)
        _fcm_tokens_tablosu_olustur(conn)
        for tablo, kolonlar in eklemeler.items():
            for kolon, ddl in kolonlar:
                _kolon_ekle(conn, tablo, kolon, ddl)
        for tablo, kolonlar in silmeler.items():
            for kolon in kolonlar:
                _kolon_sil(conn, tablo, kolon)
        _veri_onar(conn)
        # Multi-tenant: email unique + company_id Foreign Keys
        _unique_indeks_ekle(conn, "users", "email", "uq_users_email")
        _fk_ekle(conn, "users", "company_id", "companies", "fk_users_company_id")
        _fk_ekle(conn, "tasks", "company_id", "companies", "fk_tasks_company_id")
        _fk_ekle(conn, "products", "company_id", "companies", "fk_products_company_id")
        _sema_uyarilari(conn)


def _sema_uyarilari(conn):
    """Terminalde görünür uyumsuzluk uyarıları."""
    if _tablo_var_mi(conn, "users") and _kolon_var_mi(conn, "users", "email"):
        eksik = conn.execute(
            text(
                "SELECT COUNT(*) FROM users "
                "WHERE email IS NULL OR TRIM(email) = ''"
            )
        ).scalar()
        if eksik:
            print(
                f"[Schema UYARI] {eksik} kullanıcıda e-posta yok; "
                "görev atama bildirimi bu hesaplara gönderilemez."
            )


def _users_tablosu_olustur(conn):
    """users tablosunu CREATE TABLE IF NOT EXISTS ile oluşturur."""
    conn.execute(text(
        "CREATE TABLE IF NOT EXISTS `users` ("
        "  `id` INT NOT NULL AUTO_INCREMENT,"
        "  `kullanici_adi` VARCHAR(100) NOT NULL,"
        "  `sifre_hash` VARCHAR(255) NOT NULL,"
        "  `ad_soyad` VARCHAR(255) NULL,"
        "  `role` VARCHAR(20) NOT NULL DEFAULT 'user',"
        "  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,"
        "  PRIMARY KEY (`id`),"
        "  UNIQUE KEY `uq_kullanici_adi` (`kullanici_adi`)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    ))
    # Mevcut tabloya role kolonu yoksa ekle
    _kolon_ekle(conn, "users", "role", "VARCHAR(20) NOT NULL DEFAULT 'user'")
    _kolon_ekle(conn, "users", "company_id", "INT NULL")
    _kolon_ekle(conn, "users", "email", "VARCHAR(255) NULL")
    # Mevcut satırlardaki role = NULL → 'user' olarak doldur
    conn.execute(text(
        "UPDATE `users` SET `role` = 'user' WHERE `role` IS NULL OR `role` = ''"
    ))
    # Boş string e-postaları NULL yap (unique index öncesi)
    if _kolon_var_mi(conn, "users", "email"):
        conn.execute(text(
            "UPDATE `users` SET `email` = NULL WHERE `email` IS NOT NULL AND TRIM(`email`) = ''"
        ))


def _notifications_tablosu_olustur(conn):
    """Uygulama içi görev-atama bildirimleri. FK yok."""
    conn.execute(text(
        "CREATE TABLE IF NOT EXISTS `notifications` ("
        "  `id` INT NOT NULL AUTO_INCREMENT,"
        "  `user_id` INT NOT NULL,"
        "  `actor_id` INT NULL,"
        "  `actor_name` VARCHAR(255) NULL,"
        "  `task_id` INT NULL,"
        "  `title` VARCHAR(500) NOT NULL,"
        "  `body` VARCHAR(1000) NULL,"
        "  `kind` VARCHAR(50) NULL DEFAULT 'gorev_atama',"
        "  `is_read` TINYINT(1) NOT NULL DEFAULT 0,"
        "  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,"
        "  PRIMARY KEY (`id`),"
        "  KEY `ix_notifications_user_id` (`user_id`),"
        "  KEY `ix_notifications_task_id` (`task_id`),"
        "  KEY `ix_notifications_is_read` (`is_read`)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    ))


def _fcm_tokens_tablosu_olustur(conn):
    """Uygulama kapalıyken push için cihaz FCM jetonları. FK yok."""
    conn.execute(text(
        "CREATE TABLE IF NOT EXISTS `fcm_tokens` ("
        "  `id` INT NOT NULL AUTO_INCREMENT,"
        "  `user_id` INT NOT NULL,"
        "  `token` VARCHAR(512) NOT NULL,"
        "  `platform` VARCHAR(20) NULL DEFAULT 'android',"
        "  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP "
        "    ON UPDATE CURRENT_TIMESTAMP,"
        "  PRIMARY KEY (`id`),"
        "  UNIQUE KEY `uq_fcm_tokens_token` (`token`),"
        "  KEY `ix_fcm_tokens_user_id` (`user_id`)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    ))


def _companies_tablosu_olustur(conn):
    """companies tablosunu oluşturur; yoksa varsayılan şirketi ekler."""
    conn.execute(text(
        "CREATE TABLE IF NOT EXISTS `companies` ("
        "  `id` INT NOT NULL AUTO_INCREMENT,"
        "  `name` VARCHAR(255) NOT NULL,"
        "  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,"
        "  PRIMARY KEY (`id`),"
        "  UNIQUE KEY `uq_company_name` (`name`)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    ))
    satir = conn.execute(text("SELECT COUNT(*) FROM `companies`")).scalar()
    if not satir:
        conn.execute(text(
            "INSERT INTO `companies` (`name`) VALUES ('Inseres')"
        ))


def _veri_onar(conn):
    """Bağımsız satırlar için adları doldurur; bozuk kayıtları pasife alır."""
    if _tablo_var_mi(conn, "companies"):
        varsayilan_id = conn.execute(text(
            "SELECT id FROM companies ORDER BY id ASC LIMIT 1"
        )).scalar()
        if varsayilan_id:
            if _tablo_var_mi(conn, "users") and _kolon_var_mi(conn, "users", "company_id"):
                conn.execute(text(
                    "UPDATE users SET company_id = :sid WHERE company_id IS NULL"
                ), {"sid": varsayilan_id})
            if _tablo_var_mi(conn, "products") and _kolon_var_mi(conn, "products", "company_id"):
                conn.execute(text(
                    "UPDATE products SET company_id = :sid WHERE company_id IS NULL"
                ), {"sid": varsayilan_id})
    if _tablo_var_mi(conn, "notes") and _kolon_var_mi(conn, "notes", "kurum_adi"):
        conn.execute(text(
            "UPDATE notes n INNER JOIN institutions i ON i.id = n.institution_id "
            "SET n.kurum_adi = i.name "
            "WHERE n.kurum_adi IS NULL OR n.kurum_adi = ''"
        ))
    if _tablo_var_mi(conn, "tasks") and _kolon_var_mi(conn, "tasks", "kurum_adi"):
        conn.execute(text(
            "UPDATE tasks t LEFT JOIN institutions i ON i.id = t.institution_id "
            "LEFT JOIN analyses a ON a.id = t.analysis_id "
            "SET t.kurum_adi = COALESCE(NULLIF(t.kurum_adi, ''), i.name, a.kurum_adi) "
            "WHERE t.kurum_adi IS NULL OR t.kurum_adi = ''"
        ))
    if _tablo_var_mi(conn, "subscriptions") and _kolon_var_mi(conn, "subscriptions", "kurum_adi"):
        conn.execute(text(
            "UPDATE subscriptions s LEFT JOIN institutions i ON i.id = s.institution_id "
            "LEFT JOIN products p ON p.id = s.product_id "
            "SET s.kurum_adi = COALESCE(NULLIF(s.kurum_adi, ''), i.name), "
            "    s.urun_adi = COALESCE(NULLIF(s.urun_adi, ''), p.name) "
            "WHERE s.kurum_adi IS NULL OR s.kurum_adi = '' "
            "   OR s.urun_adi IS NULL OR s.urun_adi = ''"
        ))
    if _tablo_var_mi(conn, "trainings") and _kolon_var_mi(conn, "trainings", "kurum_adi"):
        conn.execute(text(
            "UPDATE trainings t INNER JOIN institutions i ON i.id = t.institution_id "
            "SET t.kurum_adi = i.name "
            "WHERE t.kurum_adi IS NULL OR t.kurum_adi = ''"
        ))
    if _tablo_var_mi(conn, "ai_voice_logs") and _kolon_var_mi(conn, "ai_voice_logs", "kurum_adi"):
        conn.execute(text(
            "UPDATE ai_voice_logs l INNER JOIN institutions i ON i.id = l.institution_id "
            "SET l.kurum_adi = i.name "
            "WHERE l.kurum_adi IS NULL OR l.kurum_adi = ''"
        ))
    if _tablo_var_mi(conn, "analyses"):
        if _kolon_var_mi(conn, "analyses", "abonelik_tipi") and _kolon_var_mi(conn, "analyses", "surec_tipi"):
            conn.execute(text(
                "UPDATE analyses SET abonelik_tipi = surec_tipi "
                "WHERE IFNULL(abonelik_tipi, '') <> IFNULL(surec_tipi, '')"
            ))
        conn.execute(text(
            "UPDATE analyses SET is_deleted = 1 "
            "WHERE is_deleted = 0 AND ("
            "  kurum_adi IS NULL OR TRIM(kurum_adi) = '' "
            "  OR LOWER(TRIM(kurum_adi)) IN ('null', 'none')"
            ")"
        ))
        if _tablo_var_mi(conn, "tasks"):
            conn.execute(text(
                "UPDATE tasks t INNER JOIN analyses a ON a.id = t.analysis_id "
                "SET t.is_deleted = 1 "
                "WHERE a.is_deleted = 1 AND t.is_deleted = 0"
            ))
            if _kolon_var_mi(conn, "tasks", "user_id") and _kolon_var_mi(conn, "analyses", "user_id"):
                conn.execute(text(
                    "UPDATE tasks t INNER JOIN analyses a ON a.id = t.analysis_id "
                    "SET t.user_id = a.user_id "
                    "WHERE t.user_id IS NULL AND a.user_id IS NOT NULL"
                ))
            if _kolon_var_mi(conn, "tasks", "assigned_user_id"):
                conn.execute(text(
                    "UPDATE tasks SET assigned_user_id = user_id "
                    "WHERE assigned_user_id IS NULL AND user_id IS NOT NULL"
                ))
            if (
                _kolon_var_mi(conn, "tasks", "company_id")
                and _tablo_var_mi(conn, "users")
                and _kolon_var_mi(conn, "users", "company_id")
            ):
                conn.execute(text(
                    "UPDATE tasks t INNER JOIN users u ON u.id = COALESCE(t.assigned_user_id, t.user_id) "
                    "SET t.company_id = u.company_id "
                    "WHERE t.company_id IS NULL AND u.company_id IS NOT NULL"
                ))
    if _tablo_var_mi(conn, "institutions"):
        conn.execute(text(
            "DELETE FROM institutions WHERE LOWER(TRIM(name)) IN ('null', 'none') "
            "OR LOWER(TRIM(IFNULL(type, ''))) = 'null'"
        ))
    if _tablo_var_mi(conn, "products") and _tablo_var_mi(conn, "subscriptions"):
        conn.execute(text(
            "DELETE p FROM products p "
            "LEFT JOIN subscriptions s ON s.product_id = p.id "
            "WHERE p.is_active = 0 AND s.id IS NULL"
        ))
