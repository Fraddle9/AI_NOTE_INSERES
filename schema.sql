-- =====================================================================
-- staj veritabanı - sıfırdan kurulum şeması (DBeaver'da çalıştırılabilir)
-- Kaynak: models.py (SQLAlchemy modelleri)
--
-- KURAL 1: Tablolar arasında hiçbir bağ (yabancı anahtar) tanımı yoktur.
--          Her tablo kendi satırında adı da tutar (kurum_adi / urun_adi).
--          Sayısal *_id alanları yalnızca uygulama katmanında kullanılan
--          değerlerdir; JOIN zorunlu değildir.
-- KURAL 2: Her CREATE TABLE komutunun hemen önünde o tabloya ait
--          DROP TABLE IF EXISTS satırı vardır. Böylece script'i tek tek
--          (Ctrl+Enter) veya tümünü birden (Alt+X) çalıştırmanız fark
--          etmeksizin her seferinde temiz bir kurulum yapılır.
--
-- UYARI: Bu script çalıştığında mevcut tablolar ve İÇİNDEKİ TÜM VERİ silinir.
--        Canlı veriyi bozmamak için mevcut kurulumda schema.py/ensure_schema
--        kolon ekler-siler; bu dosya yalnızca sıfırdan kurulum içindir.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS staj
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE staj;

-- ---------------------------------------------------------------------
-- 1. institutions - Üniversiteler ve kurumlar
--    id = kurum kimliği. Soft-delete yok.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS institutions;
CREATE TABLE institutions (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(255)  NOT NULL,
    type        VARCHAR(50)       NULL COMMENT 'UNIVERSITE, KURUM, OZEL',
    created_at  TIMESTAMP         NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP         NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_institutions_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 2. products - Ürün kataloğu
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS products;
CREATE TABLE products (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    code       VARCHAR(50)  NOT NULL COMMENT 'PIRI, PIRI_AI, LIBDIS, PLEKSNET',
    name       VARCHAR(150) NOT NULL,
    is_active  TINYINT(1)       NULL DEFAULT 1,
    UNIQUE KEY uq_products_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 3. subscriptions - Abonelikler ve denemeler
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS subscriptions;
CREATE TABLE subscriptions (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    institution_id  INT             NULL COMMENT 'değer; yabancı anahtar yok',
    product_id      INT             NULL COMMENT 'değer; yabancı anahtar yok',
    kurum_adi       VARCHAR(255)    NULL,
    urun_adi        VARCHAR(150)    NULL,
    access_type     VARCHAR(50)     NULL COMMENT 'DENEME veya ABONE',
    status          VARCHAR(50)     NULL COMMENT 'OLUMLU, BEKLEMEDE, OLUMSUZ, TALEP_EDILMEDI',
    start_date      DATE            NULL,
    end_date        DATE            NULL,
    created_at      TIMESTAMP       NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_subscriptions_institution (institution_id),
    INDEX idx_subscriptions_product (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 4. trainings - Eğitim planlamaları
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS trainings;
CREATE TABLE trainings (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    institution_id   INT              NULL COMMENT 'değer; yabancı anahtar yok',
    subscription_id  INT              NULL COMMENT 'değer; yabancı anahtar yok',
    kurum_adi        VARCHAR(255)     NULL,
    training_type    VARCHAR(50)      NULL COMMENT 'ONLINE, YUZYUZE, BELIRSIZ',
    planned_date     DATE             NULL,
    planned_time     TIME             NULL,
    trigger_event    VARCHAR(255)     NULL,
    is_mail_sent     TINYINT(1)       NULL DEFAULT 0,
    created_at       TIMESTAMP        NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_trainings_institution (institution_id),
    INDEX idx_trainings_subscription (subscription_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 5. notes - Esnek not tablosu
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS notes;
CREATE TABLE notes (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    institution_id  INT             NULL COMMENT 'değer; yabancı anahtar yok',
    kurum_adi       VARCHAR(255)    NULL,
    note_key        VARCHAR(50)     NULL COMMENT 'NOTE_1, NOTE_2',
    content         TEXT            NULL,
    created_by      VARCHAR(50)     NULL COMMENT 'AI veya MANUAL',
    created_at      TIMESTAMP       NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_notes_institution (institution_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 6. ai_voice_logs - Ham transkript ve LLM çıktısı denetim kaydı
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS ai_voice_logs;
CREATE TABLE ai_voice_logs (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    institution_id  INT             NULL COMMENT 'değer; yabancı anahtar yok',
    kurum_adi       VARCHAR(255)    NULL,
    raw_transcript  TEXT        NOT NULL COMMENT 'speech_to_text (cihaz üstü) ham metni',
    ai_parsed_json  JSON        NOT NULL COMMENT 'LLM JSON çıktısı',
    status          VARCHAR(50)     NULL DEFAULT 'SUCCESS' COMMENT 'PROCESSING, SUCCESS, FAILED, MANUALLY_EDITED',
    created_at      DATETIME        NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ai_voice_logs_institution (institution_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 7. analyses - Görüşme / analiz kayıtları (ana hat)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS analyses;
CREATE TABLE analyses (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    institution_id       INT             NULL COMMENT 'değer; yabancı anahtar yok',
    ham_metin            TEXT        NOT NULL,
    kurum_adi            VARCHAR(255)    NULL,
    durum                VARCHAR(50)     NULL COMMENT 'Olumlu, Beklemede, Olumsuz, Karma',
    urun_kodu            VARCHAR(50)     NULL,
    urun_adi             VARCHAR(150)    NULL,
    surec_tipi           VARCHAR(50)     NULL DEFAULT 'Hiçbiri' COMMENT 'Abonelik, Deneme veya Hiçbiri',
    abonelik_tipi        VARCHAR(50)     NULL DEFAULT 'Hiçbiri' COMMENT 'surec_tipi ile aynı değer',
    ilgilenilen_urunler  JSON            NULL COMMENT 'Örn: ["PIRI", "PIRI_AI"]',
    kaynak               VARCHAR(50)     NULL DEFAULT 'ai' COMMENT 'ai veya manual',
    ai_json              JSON            NULL,
    is_deleted           TINYINT(1)  NOT NULL DEFAULT 0,
    created_at           TIMESTAMP       NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP       NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_analyses_institution (institution_id),
    INDEX idx_analyses_surec_tipi (surec_tipi),
    INDEX idx_analyses_is_deleted (is_deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 8. tasks - Aksiyon maddeleri (görüşme detayı analysis_id değeriyle bulunur)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS tasks;
CREATE TABLE tasks (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    analysis_id     INT              NULL COMMENT 'değer; yabancı anahtar yok',
    institution_id  INT              NULL COMMENT 'değer; yabancı anahtar yok',
    kurum_adi       VARCHAR(255)     NULL,
    title           VARCHAR(500) NOT NULL,
    source          VARCHAR(50)      NULL DEFAULT 'ai' COMMENT 'ai veya manual',
    is_done         TINYINT(1)       NULL DEFAULT 0,
    done_at         DATETIME         NULL,
    is_deleted      TINYINT(1)   NOT NULL DEFAULT 0,
    created_at      TIMESTAMP        NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_tasks_analysis (analysis_id),
    INDEX idx_tasks_institution (institution_id),
    INDEX idx_tasks_is_deleted (is_deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Ürün kataloğu başlangıç verisi (Inseres Bilişim)
-- INSERT IGNORE: tek başına tekrar çalıştırılsa da hata vermez.
-- ---------------------------------------------------------------------
INSERT IGNORE INTO products (code, name, is_active) VALUES
    ('PIRI',     'Piri Keşif Aracı',                 1),
    ('PIRI_AI',  'Piri AI',                          1),
    ('LIBDIS',   'LİBDİS Koleksiyon Veritabanları',  1),
    ('PLEKSNET', 'Pleksnet Bibliyometrik Analiz',    1);
