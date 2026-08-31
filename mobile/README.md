# Ainote Mobile (CRM Analiz)

FastAPI backend'e bağlı, koyu temalı Flutter uygulaması.

## İlk kurulum

Flutter SDK gerekir. Ardından platform klasörlerini üretin (mevcut `lib/` korunur):

```bash
cd mobile
flutter create . --project-name ainote_mobile --org com.gmz.ainote --platforms android,ios
./setup.sh
flutter pub get
```

`setup.sh` mikrofon, internet ve HTTP (cleartext) izinlerini Android/iOS dosyalarına ekler.

## Çalıştırma (fiziksel cihaz — birincil kurulum)

Uygulama artık fiziksel bir Android cihazda, bilgisayarla **aynı Wi-Fi ağında** test ediliyor:

1. Backend'i host makinede `0.0.0.0`'a bağlayarak açın (sadece `127.0.0.1`'e bağlarsa telefon erişemez):
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```
2. Bilgisayarınızın yerel Wi-Fi IP'sini öğrenin:
   - macOS: `ipconfig getifaddr en0`
   - Windows: `ipconfig` (Wi-Fi adaptörünün IPv4 adresi)
3. `lib/config/api_config.dart` içindeki `defaultValue` değerini bu IP ile güncelleyin (şu an `http://192.168.1.107:8000`).
4. Telefonu USB ile bağlayıp `flutter run` çalıştırın; telefon ve bilgisayarın **aynı Wi-Fi ağında** olduğundan emin olun.
5. Bilgisayarınızın güvenlik duvarı 8000 portuna gelen bağlantılara izin vermeli.

> **Not:** Bilgisayarın IP'si DHCP ile değişebilir; bağlantı hatası alırsanız IP'yi tekrar kontrol edip `baseUrl`'ü güncelleyin.

### Alternatif: Emülatör/simülatör ile test

- Android emülatör: API adresini geçici olarak `http://10.0.2.2:8000` yapın (host makinenin loopback'ine gider).
- iOS simülatör: API adresini geçici olarak `http://127.0.0.1:8000` yapın.

## Ekranlar

- **Ana Sayfa:** istatistik kartları + canlı konuşma tanıma (`speech_to_text`) ile anlık transkript
- **Görüşmeler:** `/api/analizler`
- **Görevler:** `/api/gorevler`

Dinleme bitince yalnızca elde edilen **metin** `POST /api/analyze-text` ile gönderilir (ses dosyası backend'e hiç gönderilmez, Whisper kullanılmaz).
