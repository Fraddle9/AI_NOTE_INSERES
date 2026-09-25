# CRM Analiz Portalı

Satış görüşmesi notunu konuşarak veya yazarak kaydeden, yapay zekâ ile düzenleyen bir CRM uygulaması. **Web** ve **mobil** aynı sunucuyu kullanır.

Konuşma cihazda / tarayıcıda yazıya çevrilir. Ses dosyası sunucuya gitmez. Analizi Google Gemini yapar.

---

## Özellikler

- **Giriş:** kullanıcı adı ve şifre (JWT). Personel yalnız kendi kayıtlarını görür; yönetici herkesi görür.
- **Not + analiz:** mikrofon veya klavye. Metinden kurum, ürün, durum (Olumlu / Olumsuz / Karma / Beklemede) ve görevler çıkarılır.
- **Ürünler:** Piri Keşif Aracı, Piri AI ve Chatbot ayrı tutulur. Yönetici kataloga yeni ürün ekleyebilir.
- **Görüşmeler / Notlarım:** kayıt listesi, arama, filtre, detay.
- **Görevler:** analizden gelen veya elle eklenen işler. Yönetici personele atar (bildirim zili; e-posta/push isteğe bağlı).
- **Kurumlar, kullanıcı yönetimi** (kullanıcı yönetimi yalnız webde), **veritabanı** ekranı.
- **Tema:** koyu / açık.

Örnek not (analizi denemek için):

> Gazi Üniversitesi ile görüştük. Piri AI’dan memnun değiller, aboneliği iptal etmek istiyorlar. Piri Keşif Aracı’nı beğendiler, gelecek hafta online eğitim istediler.

Kaydetmeden önce **Analiz Et / Kaydet** demeniz gerekir; mikrofonu durdurmak yetmez.

---

## Parçalar

| | Ne | Klasör |
|---|---|---|
| API | FastAPI, MySQL, Gemini | kök (`main.py`) |
| Web | Tarayıcı portalı | `html5up-hyperspace/` — sunucu `/portal` olarak açar |
| Mobil | Flutter (Android / iOS) | `mobile/` |

Web için ayrı Node kurulumu yok. Backend çalışınca tarayıcı yeter.

---

## Gereksinimler

- Python 3.9+
- MySQL veya MariaDB
- Google Gemini API anahtarı — **kendi anahtarınız** (`.env` → `GOOGLE_API_KEY`). Repoda hazır anahtar yoktur.
- Web için modern tarayıcı (Chrome önerilir)
- Mobil için Flutter SDK (Dart 3.4+)

E-posta (SMTP) ve Firebase **şart değil**. Olmadan giriş, analiz ve görevler çalışır.

---

## Çalıştırma

### 1. Veritabanı

```sql
CREATE DATABASE IF NOT EXISTS CRM_AI
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
```

Tablolar ilk açılışta oluşur.

### 2. Ayar

```bash
cp .env.example .env
```

Doldurun: `DATABASE_URL` (kendi MySQL kullanıcı/şifreniz) ve `GOOGLE_API_KEY` (kendi Gemini anahtarınız; [Google AI Studio](https://aistudio.google.com/apikey) üzerinden alınır). Anahtar git’e girmez (`.env` yok sayılır).

### 3. Backend ve web

```bash
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
pip install google-generativeai

uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

- Portal: http://127.0.0.1:8000/portal/login.html
- API şeması: http://127.0.0.1:8000/docs

`--host 0.0.0.0` telefonun bağlanması içindir.

### 4. Mobil

Backend açık olsun. Telefon ve bilgisayar **aynı Wi-Fi**’de olsun. Telefonda `localhost` kullanmayın.

```bash
cd mobile
./setup.sh
ipconfig getifaddr en0            # Windows: ipconfig → IPv4
flutter run --dart-define=API_BASE_URL=http://BILGISAYAR_IP:8000
```

Android emülatör: `http://10.0.2.2:8000`  
iOS simülatör: `http://127.0.0.1:8000`

### Demo hesaplar (ilk açılışta)

| Kullanıcı | Şifre | Rol |
|---|---|---|
| `admin` | `123456` | yönetici |
| `gamze` | `gamze123` | personel |

---

## Kullanılan kütüphaneler

**Backend (Python)** — `requirements.txt`

| Kütüphane | İşi |
|---|---|
| FastAPI, Uvicorn | API ve web dosyalarını sunmak |
| SQLAlchemy, PyMySQL | MySQL |
| Pydantic | İstek / yanıt doğrulama |
| google-generativeai | Gemini analizi (`pip install` ayrıca gerekir) |
| python-jose, passlib, bcrypt | JWT ve şifre |
| firebase-admin | İsteğe bağlı push |

**Web** — HTML / CSS / JavaScript (HTML5 UP Hyperspace). Konuşma tanıma: tarayıcı Web Speech API. Stil: Tailwind CDN. Push: Firebase JS (ayarsızsa atlanır).

**Mobil (Flutter)** — `mobile/pubspec.yaml`

| Kütüphane | İşi |
|---|---|
| http | API |
| speech_to_text | Cihazda konuşma → yazı |
| permission_handler | Mikrofon / bildirim izni |
| shared_preferences | Oturum (token) |
| firebase_core, firebase_messaging | Push |
| flutter_local_notifications | Yerel bildirim |
| intl | Tarih |

---

## Takılınca

| Sorun | Kontrol |
|---|---|
| Analiz hata | `GOOGLE_API_KEY` |
| Mobil bağlanamıyor | Backend `0.0.0.0:8000`, doğru LAN IP, aynı Wi-Fi |
| Web “Failed to fetch” | Adres `/portal/...` olsun; HTML’i `file://` ile açmayın |
| Giriş olmuyor | MySQL ve `staj` veritabanı |
