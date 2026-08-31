import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/assign_task_sheet.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/change_profile_dialog.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/edit_form_sheet.dart';
import '../widgets/meeting_card.dart';
import '../widgets/meeting_detail_sheet.dart';
import '../widgets/notification_bell.dart';
import '../widgets/record_button.dart';
import '../widgets/stat_card.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/task_tile.dart';
import '../widgets/text_analyze_sheet.dart';
import 'kurumlar_screen.dart';
import 'login_screen.dart';
import 'urunler_screen.dart';
import 'veritabani_screen.dart';

/// CRM ANA EKRAN.
///
/// Ses akışı uçtan uca "sıfır ses dosyası" prensibiyle çalışır: `speech_to_text`
/// paketi cihazın yerel konuşma tanıma motorunu kullanarak kullanıcı konuştukça
/// ham metni (`result.recognizedWords`) canlı olarak geniş, çok satırlı bir
/// `TextField`e yazar (Whisper YOK, ses dosyası backend'e gönderilmez).
///
/// Dinleme durdurulduğunda backend'e OTOMATİK istek ATILMAZ: kullanıcı önce
/// kutudaki metni isterse klavyeyle düzeltebilir, sonra "Analiz Et"e dokunarak
/// gönderir. Kutuda ne yazıyorsa TAMAMEN AYNISI (hiçbir özetleme/değiştirme
/// olmadan) `/api/analyze-text` ile Gemini analizine gönderilir; backend de bu
/// metni birebir saklar, Gemini yalnızca kurum/ürün/durum/görev gibi alanları
/// bu metinden çıkarır, metnin kendisini asla yeniden yazmaz.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  CrmNavSection _navSection = CrmNavSection.anaSayfa;
  AuthUser? _currentUser;

  bool _loading = true;
  bool _speechReady = false;
  bool _listening = false;
  bool _analyzing = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _error;
  int _listTab = 0;
  DateTime? _listenStartedAt;
  String _analyzeStatus = 'Yapay Zeka Analiz Ediyor...';

  /// Konuşma tanımanın ham çıktısını (`result.recognizedWords`) TEK doğruluk
  /// kaynağı olarak tutan controller. Kullanıcı dinleme bitince bu kutudaki
  /// metni klavyeyle düzenleyebilir; backend'e HER ZAMAN bu kutuda o an ne
  /// yazıyorsa, hiçbir değişikliğe uğramadan, birebir gönderilir.
  final TextEditingController _transcriptController = TextEditingController();
  String? _lastTranscript;
  AnalysisRecord? _lastAnaliz;

  /// Android/iOS'ta doğal konuşma tanıma (SpeechRecognizer) oturumu, kullanıcı
  /// hâlâ konuşuyor olsa bile bir sessizlik/duraklama sonrası kendi kendine
  /// "final" bir sonuç verip kapanabilir (bu, web'deki `SpeechRecognition`in
  /// `onend` olayıyla BİREBİR aynı platform davranışı). Web tarafı bunu
  /// `baseText` (bkz. `main.js`) ile çözüyor: oturum kapandığında o ana kadarki
  /// metni sabitleyip dinlemeyi SESSİZCE yeniden başlatıyor. Burada da aynı
  /// mekanizma: `_baseTranskript`, ÖNCEKİ (kapanmış) oturumlardan biriken
  /// metni tutar; her yeni oturumun `onResult` çıktısı bunun ÜZERİNE eklenir,
  /// böylece kullanıcı konuşmaya devam ettiği sürece transkript YARIDA
  /// KESİLMEDEN büyümeye devam eder.
  String _baseTranskript = '';
  String _sessionStable = '';
  bool _lastErrorPermanent = false;

  /// Tüm sayfa (üst bilgi kartları + kayıt kutusu + liste) TEK bir
  /// `CustomScrollView` içinde birleştiği için sayfanın HERHANGİ bir
  /// noktasından parmakla kaydırmak listeyi de kaydırır.
  final ScrollController _scrollController = ScrollController();

  Stats _stats = const Stats();
  List<AnalysisRecord> _meetings = const [];
  List<TaskItem> _tasks = const [];
  List<Product> _products = const [];

  Future<void>? _inflightLoad;

  // Android'de konuşmadan önce kısa bir sessizlik olsa bile sistem
  // `error_speech_timeout` fırlatabiliyor. Bunu kullanıcıya hissettirmemek
  // için birkaç kez sessizce yeniden dinlemeyi deniyoruz.
  static const int _maxSttRetries = 2;
  int _sttRetryCount = 0;
  double _maxSoundLevelSeen = -999;
  String? _lastErrorMsg;
  Timer? _stopSettleTimer;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadAll();
    _initSpeech();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    setState(() => _currentUser = user);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopSettleTimer?.cancel();
    _speech.cancel();
    _transcriptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectTab(int tab) {
    setState(() => _listTab = tab);
  }

  Future<void> _initSpeech() async {
    // Transkript için kullanılan model: cihazın yerel (on-device) konuşma
    // tanıma motoru. Backend'e HİÇ ses gönderilmiyor, Whisper/Google Speech
    // API vb. kullanılmıyor.
    print('[STT] Transkript için şu model kullanılıyor: Flutter Native STT '
        '(speech_to_text paketi -> iOS: on-device SFSpeechRecognizer, '
        'Android: cihazın Google/OEM konuşma tanıma servisi)');
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) {
          print('[STT] HATA: ${error.errorMsg} (permanent: ${error.permanent})');
          _lastErrorMsg = error.errorMsg;
          _lastErrorPermanent = error.permanent;
          // NOT: Android'de durum (notListening/done) genelde hatadan ÖNCE
          // gelir; bu yüzden kararı hemen burada vermek yerine, durum ve hata
          // olaylarının hepsini kısa bir süre (debounce) toplayıp tek yerden
          // (_evaluateStop) karar veriyoruz.
          if (_listening) _scheduleStopEvaluation();
        },
      );
      print('[STT] initialize() sonucu: cihazda konuşma tanıma kullanılabilir mi? $available');
      if (!mounted) return;
      setState(() => _speechReady = available);
    } catch (e) {
      print('[STT] initialize() istisna fırlattı: $e');
      if (!mounted) return;
      setState(() => _speechReady = false);
    }
  }

  void _onSpeechStatus(String status) {
    print('[STT] Durum değişti: $status');
    final durdu = status == stt.SpeechToText.doneStatus ||
        status == stt.SpeechToText.notListeningStatus;
    if (durdu && _listening) {
      _scheduleStopEvaluation();
    }
  }

  /// Durum (`notListening`/`done`) ve hata (`onError`) callback'leri Android'de
  /// neredeyse aynı anda, farklı sırada gelebiliyor. Bunları 300ms içinde tek
  /// bir karara indirgiyoruz: gerçekten hiç ses/kelime algılanmadan
  /// `error_speech_timeout`/`error_no_match` geldiyse ve deneme hakkımız
  /// varsa sessizce yeniden dinlemeye başlıyoruz; aksi halde oturumu bitiriyoruz.
  void _scheduleStopEvaluation() {
    _stopSettleTimer?.cancel();
    _stopSettleTimer = Timer(const Duration(milliseconds: 300), _evaluateStop);
  }

  Future<void> _evaluateStop() async {
    if (!mounted || !_listening) return;
    final hataMesaji = _lastErrorMsg;
    final hataKalici = _lastErrorPermanent;
    _lastErrorMsg = null;
    _lastErrorPermanent = false;
    final tekrarDenenebilirHata = hataMesaji == 'error_speech_timeout' || hataMesaji == 'error_no_match';
    final henuzKelimeYok = _transcriptController.text.trim().isEmpty;

    if (tekrarDenenebilirHata && henuzKelimeYok && _sttRetryCount < _maxSttRetries) {
      _sttRetryCount++;
      print('[STT] "$hataMesaji" alındı ve hiç kelime algılanmadı '
          '(muhtemelen mikrofon henüz ses yakalamadı). '
          'Sessizce yeniden dinlemeye başlanıyor (deneme $_sttRetryCount/$_maxSttRetries)...');
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted || !_listening) return;
      await _beginSpeechSession();
      return;
    }

    if (tekrarDenenebilirHata && henuzKelimeYok) {
      print('[STT] Deneme hakları tükendi ($_sttRetryCount/$_maxSttRetries), '
          'oturum sessizlikle sonlandırılıyor.');
    }

    // Kalıcı (permanent) bir hata (ör. izin iptali) DEĞİLSE ve kullanıcı henüz
    // "Durdur"a basmadıysa (buraya gelindiğinde `_listening` hâlâ true), bu
    // durum platformun (Android/iOS) konuşma arasında kendiliğinden verdiği
    // doğal bir "final" sonuçtur — kullanıcının konuşması BİTMEMİŞ olabilir.
    // Web'deki `recognition.onend -> baseText'e sabitle -> recognition.start()`
    // ile BİREBİR AYNI mantıkla: mevcut metni sabitleyip dinlemeyi KESİNTİSİZ
    // şekilde yeniden başlatıyoruz. Bunu yapmazsak (eski davranış) transkript
    // ilk doğal duraklamada YARIDA KESİLİYOR ve geri kalanı asla yazılmıyordu.
    final sureDoldu = _listenStartedAt == null ||
        DateTime.now().difference(_listenStartedAt!) >= const Duration(minutes: 5);
    final gercekBitisHatasi = hataMesaji != null && !tekrarDenenebilirHata;

    if (!hataKalici && !gercekBitisHatasi && !sureDoldu) {
      _baseTranskript = _transcriptController.text.trim();
      _sessionStable = '';
      print('[STT] Doğal duraklama sonrası oturum kapandı, kullanıcı durdurmadı. '
          'Metin sabitlendi (${_baseTranskript.length} karakter), dinleme kesintisiz devam ediyor...');
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted || !_listening) return;
      await _beginSpeechSession();
      return;
    }

    await _stopListening();
  }

  Future<void> _loadAll() {
    return _inflightLoad ??= _fetchDashboard().whenComplete(() => _inflightLoad = null);
  }

  Future<void> _fetchDashboard() async {
    Object? hata;
    try {
      final meetings = await _api.fetchAnalyses();
      if (!mounted) return;
      setState(() {
        _meetings = meetings;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      hata = e;
    }
    try {
      final results = await Future.wait([
        _api.fetchStats(),
        _api.fetchTasks(),
      ]);
      List<Product> products = _products;
      try {
        products = await _api.fetchProducts();
      } catch (_) {}
      if (!mounted) return;
      final tasks = results[1] as List<TaskItem>;
      final userId = _currentUser?.id;
      tasks.sort((a, b) {
        final aY = a.yoneticiAtamasiMi(userId) ? 0 : 1;
        final bY = b.yoneticiAtamasiMi(userId) ? 0 : 1;
        if (aY != bY) return aY.compareTo(bY);
        if (a.tamamlandi != b.tamamlandi) return a.tamamlandi ? 1 : -1;
        return 0;
      });
      setState(() {
        _stats = results[0] as Stats;
        _tasks = tasks;
        _products = products;
        _loading = false;
        if (hata == null) _error = null;
      });
    } catch (e) {
      hata ??= e;
    }
    if (!mounted) return;
    if (_loading || hata != null) {
      setState(() {
        _loading = false;
        if (_meetings.isEmpty && hata != null) {
          _error = hata.toString();
        }
      });
    }
  }

  Future<void> _toggleListen() async {
    if (_analyzing) return;
    try {
      if (_listening) {
        _stopSettleTimer?.cancel();
        _timer?.cancel();
        setState(() => _listening = false);
        await _speech.stop();
        await _stopListening();
      } else {
        await _startListening();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _analyzing = false;
      });
      _toast(_analyzeError(e));
    }
  }

  Future<void> _startListening() async {
    if (!_speechReady) {
      await _initSpeech();
    }
    if (!_speechReady) {
      print('[STT] Dinleme başlatılamadı: cihazda konuşma tanıma kullanılamıyor.');
      _toast('Bu cihazda canlı konuşma tanıma kullanılamıyor.');
      return;
    }

    final mic = await Permission.microphone.request();
    print('[STT] Mikrofon izni durumu: $mic');
    if (!mic.isGranted) {
      print('[STT] Mikrofon izni reddedildi, dinleme başlatılamıyor.');
      _toast('Mikrofon izni gerekli.');
      return;
    }

    print('[STT] Ses dosyası oluşturulmuyor; canlı, cihaz-üstü tanıma başlatılıyor (speech_to_text).');

    _sttRetryCount = 0;
    _maxSoundLevelSeen = -999;
    _lastErrorMsg = null;
    _stopSettleTimer?.cancel();

    setState(() {
      _listening = true;
      _transcriptController.clear();
      _baseTranskript = '';
      _sessionStable = '';
      _lastTranscript = null;
      _lastAnaliz = null;
      _error = null;
      _elapsed = Duration.zero;
    });

    _listenStartedAt = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _listenStartedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_listenStartedAt!));
    });

    await _beginSpeechSession();
  }

  String _sttBirlestir(String onceki, String gelen) {
    final prev = onceki.trim();
    final next = gelen.trim();
    if (next.isEmpty) return prev;
    if (prev.isEmpty) return next;
    if (next.startsWith(prev)) return next;
    if (prev.endsWith(next)) return prev;
    final max = prev.length < next.length ? prev.length : next.length;
    for (var len = max; len >= 4; len--) {
      if (prev.substring(prev.length - len) == next.substring(0, len)) {
        return '${prev.substring(0, prev.length - len)}$next';
      }
    }
    return '$prev $next';
  }

  String _sttBuyut(String onceki, String gelen) {
    final prev = onceki.trim();
    final next = gelen.trim();
    if (next.isEmpty) return prev;
    if (prev.isEmpty) return next;
    if (next.startsWith(prev) || prev.startsWith(next)) {
      return next.length >= prev.length ? next : prev;
    }
    return _sttBirlestir(prev, next);
  }

  void _sttMetniYaz(String metin) {
    _transcriptController.value = TextEditingValue(
      text: metin,
      selection: TextSelection.collapsed(offset: metin.length),
    );
  }

  /// Gerçek `_speech.listen()` çağrısı burada. Hem ilk başlatmada hem de
  /// `error_speech_timeout` sonrası sessiz yeniden denemelerde kullanılır.
  Future<void> _beginSpeechSession() async {
    print('[STT] Dinleme oturumu başlatılıyor (deneme ${_sttRetryCount + 1}/${_maxSttRetries + 1})...');
    await _speech.listen(
      onResult: (result) {
        print('[STT] Algılanan ham metin (final: ${result.finalResult}): '
            '"${result.recognizedWords}"');
        if (!mounted) return;
        final gelen = result.recognizedWords.trim();
        if (gelen.isEmpty) return;
        // Android her final sonuçtan sonra recognizedWords'ü sıfırlar; iOS
        // ise oturum boyunca biriktirir. Ayrıca uzun kayıtlarda motor baştaki
        // kelimeleri düşürebilir. _sessionStable küçülmez, finaller
        // _baseTranskript'e yazılır — böylece transkriptin başı silinmez.
        _sessionStable = _sttBuyut(_sessionStable, gelen);
        if (result.finalResult) {
          _baseTranskript = _sttBirlestir(_baseTranskript, _sessionStable);
          _sessionStable = '';
        }
        _sttMetniYaz(_sttBirlestir(_baseTranskript, _sessionStable));
      },
      onSoundLevelChange: (level) {
        // Ses seviyesi sürekli çok düşük kalıyorsa mikrofon gerçek sesi
        // almıyor demektir (bkz. _stopListening'deki tanı mesajı).
        if (level > _maxSoundLevelSeen) _maxSoundLevelSeen = level;
        print('[STT] Mikrofon ses seviyesi: ${level.toStringAsFixed(1)}');
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        autoPunctuation: true,
        localeId: 'tr_TR',
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 8),
      ),
    );
    print('[STT] _speech.listen() çağrıldı, dinleme aktif: ${_speech.isListening}');
  }

  /// Dinlemeyi durdurur ama HİÇBİR ŞEKİLDE backend'e istek atmaz. Kutudaki
  /// ham transkript olduğu gibi kalır; kullanıcı isterse klavyeyle düzeltip
  /// sonra kendisi "Analiz Et" ile gönderir (bkz. _sendTranscriptForAnalysis).
  Future<void> _stopListening() async {
    _stopSettleTimer?.cancel();
    _timer?.cancel();
    final metin = _transcriptController.text.trim();
    if (!mounted) return;
    setState(() => _listening = false);

    print('[STT] Dinleme durduruldu. Kutudaki ham metin uzunluğu: ${metin.length} karakter. '
        'İçerik (hiç değiştirilmedi): "$metin"');
    print('[STT] Oturum(lar) boyunca görülen en yüksek ses seviyesi: '
        '${_maxSoundLevelSeen.toStringAsFixed(1)} (referans: sessiz ortam ~ -2..2, konuşma genelde 3+)');

    if (metin.isEmpty) {
      final sessizGorunuyor = _maxSoundLevelSeen < 1.0;
      if (sessizGorunuyor) {
        print('[STT] UYARI: Mikrofon ses seviyesi tüm oturum boyunca çok düşük kaldı. '
            'Mikrofon muhtemelen gerçek sesi almıyor. Olası nedenler:');
        print('  1) Android emülatör kullanıyorsanız: emülatör varsayılan olarak host '
            'mikrofonunu iletmeyebilir -> Extended Controls (...) > Microphone > '
            '"Virtual microphone uses host audio input" seçeneğini açın.');
        print('  2) Fiziksel cihazda mikrofon başka bir uygulama tarafından kullanılıyor olabilir.');
        print('  3) Mikrofon izni ayarlardan sonradan kapatılmış olabilir.');
        _toast('Mikrofon ses algılamadı. Emülatörde iseniz Extended Controls > Microphone > '
            '"Virtual microphone uses host audio input" seçeneğini açın ya da gerçek cihazda deneyin.');
      } else {
        print('[STT] UYARI: Ses seviyesi algılandı ama konuşma metne çevrilemedi.');
        _toast('Konuşma algılanamadı. Lütfen mikrofona yakın ve net şekilde tekrar konuşun. '
            'İsterseniz kutuya elle de yazabilirsiniz.');
      }
      return;
    }

    _toast('Transkript hazır. Göndermeden önce dilerseniz düzenleyin, sonra "Analiz Et"e dokunun.');
  }

  /// Kutudaki metni (kullanıcı elle düzenlemiş olsun ya da olmasın) TAM OLARAK
  /// olduğu gibi, hiçbir değişiklik yapmadan backend'e gönderir. Backend de bu
  /// metni birebir saklar; Gemini sadece bu metinden alan (kurum/ürün/durum/
  /// görev) çıkarımı yapar, metnin kendisini asla yeniden yazmaz.
  Future<void> _sendTranscriptForAnalysis() async {
    if (_analyzing || _listening) return;
    final metin = _transcriptController.text.trim();
    if (metin.isEmpty) {
      _toast('Önce konuşarak veya yazarak bir transkript oluşturun.');
      return;
    }

    setState(() {
      _analyzing = true;
      _analyzeStatus = 'Yapay Zeka Analiz Ediyor...';
    });

    AnalysisRecord? analiz;
    try {
      print('[ANALYZE] Backend\'e analiz isteği gönderiliyor: POST /api/analyze-text');
      print('[ANALYZE] Gönderilen ham metin (${metin.length} karakter, HİÇ değiştirilmedi): "$metin"');
      final sonuc = await _api.analyzeText(metin);
      print('[ANALYZE] Backend yanıtı alındı: kurum=${sonuc.kurumAdi}, durum=${sonuc.durum}, '
          'abonelik_tipi=${sonuc.abonelikTipi}, analiz_id=${sonuc.analizId}');
      await _loadAll();
      if (!mounted) return;
      if (sonuc.analizId != null) {
        for (final m in _meetings) {
          if (m.id == sonuc.analizId) {
            analiz = m;
            break;
          }
        }
        if (analiz == null) {
          // Liste henüz tazelenmediyse (nadir bir zamanlama durumu), kaydı
          // doğrudan sunucudan çekerek yine de detay ekranını açabilelim.
          try {
            analiz = await _api.fetchAnalysis(sonuc.analizId!);
          } catch (_) {}
        }
      }
      if (!mounted) return;
      setState(() {
        _lastTranscript = metin;
        _lastAnaliz = analiz;
        _listTab = 0;
        _transcriptController.clear();
      });
      final kurum = (analiz?.kurumAdi ?? sonuc.kurumAdi ?? '').trim();
      final toastMsg = kurum.isNotEmpty
          ? 'Analiz tamamlandı: $kurum'
          : (sonuc.mesaj.trim().isNotEmpty ? sonuc.mesaj.trim() : 'Analiz tamamlandı');
      _toast(toastMsg);
    } catch (e) {
      print('[ANALYZE] HATA: $e');
      if (e is TimeoutException) {
        print('[ANALYZE] Zaman aşımı! Backend çalışıyor mu (${ApiService.baseUrl})? '
            'Telefon bilgisayarla aynı Wi-Fi ağında mı, Gemini analizi mi yavaş, '
            'yoksa bağlantı mı kopuk kontrol edin.');
      }
      if (!mounted) return;
      _toast(_analyzeError(e));
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }

    // Analiz veritabanına eklendiği anda, kullanıcının AI'ın çıkardığı
    // "Abonelik mi Deneme mi", "Hangi Kurum", "Hangi Ürün" bilgilerini anında
    // gözüyle teyit edebilmesi için o kaydın detay ekranı OTOMATİK açılır.
    // Detay ekranından çıkıldığında kullanıcı ana ekrandaki listede kaydı
    // görmeye devam eder (liste zaten yukarıda yenilenmiş durumda).
    if (mounted && analiz != null) {
      await _openMeeting(analiz);
    }
  }

  String _analyzeError(Object e) {
    final raw = e.toString();
    if (raw.contains('bağlanılamadı') || raw.contains('zaman aşımı')) return raw;
    if (raw.contains('kotas') ||
        raw.contains('kota') ||
        raw.contains('kotası') ||
        raw.contains('429') ||
        raw.contains('ResourceExhausted')) {
      return 'API kotası doldu. Lütfen bir dakika bekleyip tekrar deneyin.';
    }
    if (e is ApiException && e.message.trim().isNotEmpty) {
      if (e.statusCode == 502 ||
          e.statusCode == 504 ||
          raw.contains('geçersiz veya boş') ||
          raw.contains('zaman aşımına')) {
        return e.message.trim();
      }
    }
    if (raw.contains('geçersiz veya boş yanıt') || raw.contains('zaman aşımına uğradı')) {
      return raw.replaceFirst(RegExp(r'^.*Exception:\s*'), '');
    }
    return 'Analiz başarısız oldu, lütfen tekrar deneyin';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm({AnalysisRecord? record}) async {
    if (_analyzing || _listening) return;
    final saved = await showEditFormSheet(
      context: context,
      api: _api,
      products: _products,
      record: record,
    );
    if (saved) {
      await _loadAll();
      _toast(record == null ? 'Kayıt eklendi' : 'Kayıt güncellendi');
    }
  }

  Future<void> _openMeeting(AnalysisRecord record) async {
    if (_analyzing || _listening) return;
    final changed = await showMeetingDetailSheet(
      context: context,
      api: _api,
      products: _products,
      record: record,
    );
    if (changed) await _loadAll();
  }

  Future<void> _openTextAnalyze() async {
    if (_analyzing || _listening) return;
    final saved = await showTextAnalyzeSheet(context: context, api: _api);
    if (saved) {
      await _loadAll();
      _toast('Analiz tamamlandı');
    }
  }

  Future<void> _quickAddTask(String title) async {
    if (_analyzing || _listening) return;
    try {
      await _api.createTask(TaskWrite(baslik: title));
      await _loadAll();
      _toast('Görev eklendi');
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _openTaskForm({TaskItem? task}) async {
    if (_analyzing || _listening) return;
    final saved = await showTaskFormSheet(context: context, api: _api, task: task);
    if (saved) {
      await _loadAll();
      _toast(task == null ? 'Görev eklendi' : 'Görev güncellendi');
    }
  }

  Future<void> _confirmDeleteTask(TaskItem task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görevi sil'),
        content: const Text('Bu görev listeden kaldırılacak (soft delete).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.olumsuz),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteTask(task.id);
      await _loadAll();
      _toast('Görev pasife alındı');
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _toggleTask(TaskItem task) async {
    try {
      await _api.patchTask(task.id, {'tamamlandi': !task.tamamlandi});
      await _loadAll();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _openCreateMenu() async {
    if (_analyzing || _listening) return;
    final isAdmin = _currentUser?.isAdmin ?? false;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.forum_outlined, color: AppColors.accent),
              title: const Text('Yeni görüşme'),
              onTap: () => Navigator.pop(ctx, 'gorusme'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded, color: AppColors.olumlu),
              title: const Text('Yeni görev'),
              onTap: () => Navigator.pop(ctx, 'gorev'),
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.beklemede),
                title: const Text('Personele görev ata'),
                onTap: () => Navigator.pop(ctx, 'ata'),
              ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.account_balance_rounded, color: AppColors.accentPurple),
                title: const Text('Yeni kurum'),
                onTap: () => Navigator.pop(ctx, 'kurum'),
              ),
          ],
        ),
      ),
    );
    if (choice == 'gorusme') await _openForm();
    if (choice == 'gorev') await _openTaskForm();
    if (choice == 'ata') await _openAssignTask();
    if (choice == 'kurum') await _addKurum();
  }

  Future<void> _openAssignTask() async {
    final saved = await showAssignTaskSheet(context: context, api: _api);
    if (saved == true) {
      await _loadAll();
      _toast('Görev atandı');
    }
  }

  Future<void> _addKurum() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Kurum'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Kurum adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      await _api.createInstitution(name: name);
      await _loadAll();
      _toast('Kurum eklendi');
    } catch (e) {
      _toast(e.toString());
    }
  }

  /// Yeni sayfayı ana ekranın ÜZERİNE ekler; altta kalan HomeScreen içeriği
  /// değiştirilmez. Böylece geri tuşu uygulamadan çıkmaz, ana sayfaya döner.
  Future<void> _openPage(Widget page, {CrmNavSection? navSection}) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) await _loadAll();
  }

  Future<void> _confirmDelete(AnalysisRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: const Text(
          'Bu kaydı silmek istiyor musunuz? Kayıt kalıcı silinmez, listeden kaldırılır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.olumsuz),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteAnalysis(record.id);
      await _loadAll();
      _toast('Kayıt pasife alındı');
    } catch (e) {
      _toast(e.toString());
    }
  }

  String get _elapsedLabel {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _selectNav(CrmNavSection section) async {
    _scaffoldKey.currentState?.closeDrawer();
    if (section == CrmNavSection.kurumlar) {
      await _openPage(KurumlarScreen(api: _api), navSection: CrmNavSection.kurumlar);
      return;
    }
    if (section == CrmNavSection.urunler) {
      await _openPage(UrunlerScreen(api: _api), navSection: CrmNavSection.urunler);
      return;
    }
    if (section == CrmNavSection.veritabani) {
      await _openPage(VeritabaniScreen(api: _api), navSection: CrmNavSection.veritabani);
      return;
    }
    if (_navSection == section) return;
    setState(() {
      _navSection = section;
      if (section == CrmNavSection.gorusmeler) {
        _listTab = 0;
      } else if (section == CrmNavSection.gorevler) {
        _listTab = 1;
      }
    });
  }

  void _notEklePanelineGit() {
    setState(() => _navSection = CrmNavSection.anaSayfa);
    _scaffoldKey.currentState?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _changePassword() async {
    final user = _currentUser ?? await AuthService.getUser();
    if (user == null || !mounted) return;
    _scaffoldKey.currentState?.closeDrawer();
    final ok = await showChangePasswordDialog(context, user: user);
    if (ok == true && mounted) {
      _toast('Şifreniz güncellendi');
    }
  }

  Future<void> _editProfile() async {
    final user = _currentUser ?? await AuthService.getUser();
    if (user == null || !mounted) return;
    _scaffoldKey.currentState?.closeDrawer();
    final guncel = await showChangeProfileDialog(context, user: user);
    if (guncel != null && mounted) {
      setState(() => _currentUser = guncel);
      _toast('Profiliniz güncellendi');
    }
  }

  Future<void> _logout() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F30),
        title: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Oturumunuzu kapatmak istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çıkış Yap', style: TextStyle(color: Color(0xFFF08080))),
          ),
        ],
      ),
    );
    if (onay == true && mounted) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  int get _yoneticiGorevSayisi =>
      _tasks.where((t) => t.yoneticiAtamasiMi(_currentUser?.id) && !t.tamamlandi).length;

  Widget _buildSidebar({bool inDrawer = false}) {
    return AppSidebar(
      selected: _navSection,
      user: _currentUser,
      notSayisi: _meetings.length,
      gorevSayisi: _tasks.where((t) => !t.tamamlandi).length,
      yoneticiGorevSayisi: _yoneticiGorevSayisi,
      onSelect: _selectNav,
      onNotEkle: () {
        _notEklePanelineGit();
        if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
      },
      onChangePassword: _changePassword,
      onEditProfile: _editProfile,
      onLogout: _logout,
    );
  }

  String get _sectionTitle {
    switch (_navSection) {
      case CrmNavSection.anaSayfa:
        return 'CRM ANALİZ';
      case CrmNavSection.gorusmeler:
        return 'GÖRÜŞMELER';
      case CrmNavSection.notlarim:
        return 'NOTLARIM';
      case CrmNavSection.gorevler:
        return 'GÖREVLER';
      case CrmNavSection.kurumlar:
        return 'KURUMLAR';
      case CrmNavSection.urunler:
        return 'ÜRÜNLER';
      case CrmNavSection.veritabani:
        return 'VERİTABANI';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isWide ? null : Drawer(child: _buildSidebar(inDrawer: true)),
      appBar: AppBar(
        leading: isWide
            ? null
            : IconButton(
                tooltip: 'Menü',
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        title: Text(_sectionTitle),
        actions: [
          NotificationBellButton(
            api: _api,
            onOpenTasks: () => _selectNav(CrmNavSection.gorevler),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: ThemeController.instance.isLight,
            builder: (context, isLight, _) {
              return IconButton(
                tooltip: isLight ? 'Koyu temaya geç' : 'Açık temaya geç',
                onPressed: ThemeController.instance.toggle,
                icon: Icon(isLight ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded),
              );
            },
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: _analyzing || _listening ? null : _loadAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      floatingActionButton: _navSection == CrmNavSection.anaSayfa ||
              _navSection == CrmNavSection.gorusmeler ||
              _navSection == CrmNavSection.notlarim ||
              _navSection == CrmNavSection.gorevler
          ? FloatingActionButton(
              onPressed: _analyzing || _listening ? null : _openCreateMenu,
              backgroundColor: AppColors.accent,
              tooltip: 'Yeni Kayıt Ekle',
              child: const Icon(Icons.add),
            )
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide)
            SizedBox(
              width: 280,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
                  ),
                ),
                child: _buildSidebar(),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                AppRefreshIndicator(
                  onRefresh: _loadAll,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: _buildSectionSlivers(),
                  ),
                ),
                if (_analyzing) _AnalyzingOverlay(message: _analyzeStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSectionSlivers() {
    switch (_navSection) {
      case CrmNavSection.gorusmeler:
        return [
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ErrorBanner(message: _error!, onRetry: _loadAll),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _SectionIntro(
                icon: Icons.forum_rounded,
                title: 'Görüşmeler',
                subtitle:
                    'Kurum, ürün, durum ve süreç özeti. Karta dokunun; not metni ve çıkan görevler detayda açılır.',
                actionLabel: 'Yeni kayıt ekle',
                onAction: () => _openForm(),
              ),
            ),
          ),
          _MeetingsSliver(
            meetings: _meetings,
            loading: _loading,
            mode: MeetingCardMode.gorusme,
            showUserBadge: _currentUser?.isAdmin ?? false,
            emptyTitle: 'Henüz görüşme yok',
            emptySubtitle:
                'Yeni kayıt ekleyebilir veya ana sayfadan konuşarak analiz alabilirsiniz.',
            onAdd: () => _openForm(),
            onOpen: _openMeeting,
            onEdit: (r) => _openForm(record: r),
            onDelete: _confirmDelete,
          ),
        ];
      case CrmNavSection.notlarim:
        return [
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ErrorBanner(message: _error!, onRetry: _loadAll),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _SectionIntro(
                icon: Icons.sticky_note_2_rounded,
                title: 'Notlarınız',
                subtitle:
                    'Görüşme metinleriniz. Karta dokunun; ürün, süreç, durum ve bu görüşmeden çıkan görevler dahil tüm detayı görün.',
                actionLabel: 'Yeni not ekle',
                onAction: _notEklePanelineGit,
              ),
            ),
          ),
          _MeetingsSliver(
            meetings: _meetings,
            loading: _loading,
            mode: MeetingCardMode.not,
            showUserBadge: _currentUser?.isAdmin ?? false,
            emptyTitle: 'Henüz not yok',
            emptySubtitle:
                'Konuşarak veya yazarak eklediğiniz notlar burada listelenir.',
            onAdd: () => _openForm(),
            onOpen: _openMeeting,
            onEdit: (r) => _openForm(record: r),
            onDelete: _confirmDelete,
          ),
        ];
      case CrmNavSection.gorevler:
        return [
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ErrorBanner(message: _error!, onRetry: _loadAll),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _SectionIntro(
                icon: Icons.checklist_rounded,
                title: 'Görev listeniz',
                subtitle: _yoneticiGorevSayisi > 0
                    ? 'Sarı kenarlı görevler yöneticiniz tarafından size atanmıştır.'
                    : 'Yapay zeka veya manuel eklenen görevlerinizi buradan takip edin.',
                actionLabel: 'Görev ekle',
                onAction: () => _openTaskForm(),
              ),
            ),
          ),
          _TasksSliver(
            tasks: _tasks,
            loading: _loading,
            mevcutKullaniciId: _currentUser?.id,
            onAdd: () => _openTaskForm(),
            onQuickAdd: _quickAddTask,
            onEdit: (t) => _openTaskForm(task: t),
            onDelete: _confirmDeleteTask,
            onToggle: _toggleTask,
          ),
        ];
      case CrmNavSection.kurumlar:
      case CrmNavSection.urunler:
      case CrmNavSection.veritabani:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Sol menüden tekrar seçerek ilgili sayfayı açabilirsiniz.',
                  style: const TextStyle(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ];
      case CrmNavSection.anaSayfa:
        return _buildDashboardSlivers();
    }
  }

  List<Widget> _buildDashboardSlivers() {
    return [
      SliverToBoxAdapter(
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _StatsHeader(
                  stats: _stats,
                  loading: _loading,
                  error: _error,
                  onRetry: _loadAll,
                  onKurumlar: () => _openPage(
                    KurumlarScreen(api: _api),
                    navSection: CrmNavSection.kurumlar,
                  ),
                  onGorusmeler: () => _selectNav(CrmNavSection.gorusmeler),
                  onGorevler: () => _selectNav(CrmNavSection.gorevler),
                  onNotlarim: () => _selectNav(CrmNavSection.notlarim),
                  onUrunler: () => _openPage(
                    UrunlerScreen(api: _api),
                    navSection: CrmNavSection.urunler,
                  ),
                  showUrunler: _currentUser?.isAdmin ?? false,
                ),
              ),
            ),
            _RecordSection(
              listening: _listening,
              analyzing: _analyzing,
              speechReady: _speechReady,
              elapsedLabel: _elapsedLabel,
              analyzeStatus: _analyzeStatus,
              transcriptController: _transcriptController,
              onRecord: _toggleListen,
              onSend: _sendTranscriptForAnalysis,
              onTextAnalyze: _openTextAnalyze,
            ),
            if (_lastAnaliz != null || (_lastTranscript ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _AnalyzeGlance(
                  transcript: _lastTranscript,
                  analiz: _lastAnaliz,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  _ListChip(
                    label: 'Görüşmeler',
                    selected: _listTab == 0,
                    count: _meetings.length,
                    onTap: () => _selectTab(0),
                  ),
                  const SizedBox(width: 8),
                  _ListChip(
                    label: 'Notlarım',
                    selected: false,
                    count: _meetings.length,
                    onTap: () => _selectNav(CrmNavSection.notlarim),
                  ),
                  const SizedBox(width: 8),
                  _ListChip(
                    label: 'Görevler',
                    selected: _listTab == 1,
                    count: _tasks.length,
                    onTap: () => _selectTab(1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (_listTab == 0)
        _MeetingsSliver(
          meetings: _meetings,
          loading: _loading,
          mode: MeetingCardMode.gorusme,
          showUserBadge: _currentUser?.isAdmin ?? false,
          onAdd: () => _openForm(),
          onOpen: _openMeeting,
          onEdit: (r) => _openForm(record: r),
          onDelete: _confirmDelete,
        )
      else
        _TasksSliver(
          tasks: _tasks,
          loading: _loading,
          mevcutKullaniciId: _currentUser?.id,
          onAdd: () => _openTaskForm(),
          onQuickAdd: _quickAddTask,
          onEdit: (t) => _openTaskForm(task: t),
          onDelete: _confirmDeleteTask,
          onToggle: _toggleTask,
        ),
    ];
  }
}

class _SectionIntro extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final Stats stats;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onKurumlar;
  final VoidCallback onGorusmeler;
  final VoidCallback onGorevler;
  final VoidCallback onUrunler;
  final VoidCallback onNotlarim;
  final bool showUrunler;

  const _StatsHeader({
    required this.stats,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onKurumlar,
    required this.onGorusmeler,
    required this.onGorevler,
    required this.onUrunler,
    required this.onNotlarim,
    this.showUrunler = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error != null) ...[
          _ErrorBanner(message: error!, onRetry: onRetry),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Toplam Kurum',
                value: loading ? '...' : '${stats.toplamKurumSayisi}',
                icon: Icons.account_balance_rounded,
                iconColor: AppColors.accentPurple,
                onTap: onKurumlar,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'Görüşmeler',
                value: loading ? '...' : '${stats.analizSayisi}',
                icon: Icons.forum_rounded,
                iconColor: AppColors.accent,
                onTap: onGorusmeler,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Aktif Görev',
                value: loading ? '...' : '${stats.aktifGorevSayisi}',
                icon: Icons.task_alt_rounded,
                iconColor: AppColors.olumlu,
                onTap: onGorevler,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: showUrunler
                  ? StatCard(
                      label: 'Ürünler',
                      value: loading ? '...' : '${stats.populerUrunSayisi}',
                      icon: Icons.inventory_2_rounded,
                      iconColor: AppColors.accentBlue,
                      onTap: onUrunler,
                    )
                  : StatCard(
                      label: 'Notlarım',
                      value: loading ? '...' : '${stats.analizSayisi}',
                      icon: Icons.sticky_note_2_rounded,
                      iconColor: AppColors.accentBlue,
                      onTap: onNotlarim,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecordSection extends StatelessWidget {
  final bool listening;
  final bool analyzing;
  final bool speechReady;
  final String elapsedLabel;
  final String analyzeStatus;
  final TextEditingController transcriptController;
  final VoidCallback onRecord;
  final VoidCallback onSend;
  final VoidCallback onTextAnalyze;

  const _RecordSection({
    required this.listening,
    required this.analyzing,
    required this.speechReady,
    required this.elapsedLabel,
    required this.analyzeStatus,
    required this.transcriptController,
    required this.onRecord,
    required this.onSend,
    required this.onTextAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.accentPurple.withValues(alpha: 0.55), width: 1.2),
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accentPurple.withValues(alpha: 0.14),
                AppColors.surface.withValues(alpha: 0.9),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentPurple.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: AppColors.accentPurple, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Görüşme Notu Ekle',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Konuşarak veya yazarak not ekleyin',
                            style: TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RecordButton(
                  isRecording: listening,
                  enabled: !analyzing,
                  onPressed: onRecord,
                ),
                const SizedBox(height: 12),
                if (analyzing) ...[
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    analyzeStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ] else ...[
                  Text(
                    listening ? 'Dinleniyor  $elapsedLabel' : 'Mikrofona dokunup konuşun',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: listening ? AppColors.record : AppColors.muted,
                      fontSize: 14,
                      fontWeight: listening ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listening
                        ? 'Söylediğiniz kelimeler aşağıya birebir yazılır.'
                        : (speechReady
                            ? 'Bitince metni düzenleyip kaydedin'
                            : 'Bu cihazda canlı konuşma tanıma kullanılamıyor'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                _TranscriptEditor(
                  controller: transcriptController,
                  listening: listening,
                  enabled: !analyzing,
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: transcriptController,
                  builder: (context, value, _) {
                    final canSend = !listening && !analyzing && value.text.trim().isNotEmpty;
                    return FilledButton.icon(
                      onPressed: canSend ? onSend : null,
                      icon: const Icon(Icons.save_alt_rounded, size: 18),
                      label: const Text('Notu Kaydet ve Analiz Et'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: analyzing || listening ? null : onTextAnalyze,
                  icon: const Icon(Icons.notes_rounded, size: 18),
                  label: const Text('Yazılı not gir'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent.withValues(alpha: 0.55)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Konuşma tanımanın ham çıktısını gösteren VE kullanıcının klavyeyle
/// düzenlemesine izin veren geniş, çok satırlı metin kutusu.
///
/// Bu kutudaki metin `speech_to_text`in `onResult` callback'inden gelen
/// `result.recognizedWords` değeridir — hiçbir özetleme/değiştirme yapılmaz.
/// Dinleme bitince kullanıcı bu kutu üzerinde serbestçe düzeltme yapabilir;
/// backend'e gönderilen metin her zaman bu kutunun o anki içeriğidir.
class _TranscriptEditor extends StatelessWidget {
  final TextEditingController controller;
  final bool listening;
  final bool enabled;

  const _TranscriptEditor({
    required this.controller,
    required this.listening,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: listening ? AppColors.record.withValues(alpha: 0.6) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                if (listening) ...[
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.podcasts_rounded, size: 14, color: AppColors.record),
                  ),
                ],
                const Text(
                  'NOTUNUZ (düzenlenebilir)',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            readOnly: listening,
            enabled: enabled,
            // Kutu hâlâ geniş ve düzenlenebilir, ama listeleme alanına daha
            // fazla dikey alan bırakmak için varsayılan yüksekliği makul
            // tutuyoruz; uzun transkriptlerde kutunun kendi içi kayar.
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.4),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              hintText: listening ? 'Dinleniyor... konuşmaya başlayın' : 'Görüşme notunuzu buraya yazın veya mikrofonla dikte edin...',
              hintStyle: const TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _ListChip({
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.accent.withValues(alpha: 0.7) : AppColors.border,
              ),
            ),
            child: Text(
              '$label  $count',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.text : AppColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Görüşme kartlarını, sayfanın tek ortak `CustomScrollView`ine doğrudan
/// eklenebilecek bir sliver olarak üretir. Böylece üst bilgi kartlarıyla
/// liste TEK bir kaydırma alanı paylaşır; sayfanın herhangi bir yerinden
/// başlatılan bir sürükleme tüm içeriği (liste dahil) birlikte kaydırır.
class _MeetingsSliver extends StatelessWidget {
  final List<AnalysisRecord> meetings;
  final bool loading;
  final bool showUserBadge;
  final MeetingCardMode mode;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback onAdd;
  final ValueChanged<AnalysisRecord> onOpen;
  final ValueChanged<AnalysisRecord> onEdit;
  final ValueChanged<AnalysisRecord> onDelete;

  const _MeetingsSliver({
    required this.meetings,
    required this.loading,
    required this.onAdd,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    this.showUserBadge = false,
    this.mode = MeetingCardMode.gorusme,
    this.emptyTitle = 'Henüz aktif kayıt yok',
    this.emptySubtitle =
        'Yeni kayıt ekleyebilir veya mikrofonla canlı konuşarak analiz alabilirsiniz.',
  });

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyState(
          icon: mode == MeetingCardMode.not
              ? Icons.sticky_note_2_outlined
              : Icons.forum_outlined,
          title: loading ? 'Yükleniyor...' : emptyTitle,
          subtitle: loading ? 'Kayıtlar getiriliyor.' : emptySubtitle,
          actionLabel: loading ? null : 'Yeni Kayıt Ekle',
          onAction: loading ? null : onAdd,
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Yeni Kayıt Ekle'),
                  ),
                ),
              );
            }
            // Her kart içeriğine (özellikle uzun transkriptlere) göre
            // dinamik yükseklikte render edilir; SliverList bunu ekstra
            // bir sabit yükseklik/kısıtlama olmadan doğal destekler.
            final record = meetings[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MeetingCard(
                record: record,
                mode: mode,
                showUserBadge: showUserBadge,
                onOpen: () => onOpen(record),
                onEdit: () => onEdit(record),
                onDelete: () => onDelete(record),
              ),
            );
          },
          childCount: meetings.length + 1,
        ),
      ),
    );
  }
}

/// Görev kartlarını sliver olarak üretir (bkz. `_MeetingsSliver` açıklaması).
class _TasksSliver extends StatelessWidget {
  final List<TaskItem> tasks;
  final bool loading;
  final int? mevcutKullaniciId;
  final VoidCallback onAdd;
  final Future<void> Function(String title) onQuickAdd;
  final ValueChanged<TaskItem> onEdit;
  final ValueChanged<TaskItem> onDelete;
  final ValueChanged<TaskItem> onToggle;

  const _TasksSliver({
    required this.tasks,
    required this.loading,
    this.mevcutKullaniciId,
    required this.onAdd,
    required this.onQuickAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          child: Column(
            children: [
              _QuickTaskBar(onSubmit: onQuickAdd),
              const SizedBox(height: 36),
              const Icon(Icons.checklist_rounded, size: 44, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(
                loading ? 'Yükleniyor...' : 'Henüz görev yok',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loading
                    ? 'Görevler getiriliyor.'
                    : 'Yapay zeka analizinden çıkan veya manuel eklenen görevler burada görünür.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              if (!loading) ...[
                const SizedBox(height: 16),
                Center(
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Yeni Görev'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _QuickTaskBar(onSubmit: onQuickAdd),
              );
            }
            final task = tasks[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TaskTile(
                task: task,
                mevcutKullaniciId: mevcutKullaniciId,
                onEdit: () => onEdit(task),
                onDelete: () => onDelete(task),
                onToggle: () => onToggle(task),
              ),
            );
          },
          childCount: tasks.length + 1,
        ),
      ),
    );
  }
}

class _QuickTaskBar extends StatefulWidget {
  final Future<void> Function(String title) onSubmit;

  const _QuickTaskBar({required this.onSubmit});

  @override
  State<_QuickTaskBar> createState() => _QuickTaskBarState();
}

class _QuickTaskBarState extends State<_QuickTaskBar> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _ctrl.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(title);
      if (mounted) _ctrl.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            enabled: !_saving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'Manuel görev ekle...',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}

class _AnalyzingOverlay extends StatelessWidget {
  final String message;

  const _AnalyzingOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC050816),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sadece metin backend’e gönderiliyor',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzeGlance extends StatelessWidget {
  final String? transcript;
  final AnalysisRecord? analiz;

  const _AnalyzeGlance({this.transcript, this.analiz});

  @override
  Widget build(BuildContext context) {
    final kurum = (analiz?.kurumAdi ?? '').trim();
    final durum = AnalysisRecord.normalizeDurum(analiz?.durum);
    final metin = (transcript ?? '').trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SON ANALİZ',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              kurum.isEmpty ? 'Analiz tamamlandı' : kurum,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (analiz != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ...analiz!.urunRozetleri.map(
                    (ad) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        ad,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      AnalysisRecord.normalizeSurecTipi(analiz!.surecTipi ?? analiz!.abonelikTipi),
                      style: const TextStyle(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                durum,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
            if (metin.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                metin,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceAlt,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.olumsuz),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.text, fontSize: 12),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Yenile')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // Artık kendi başına kaydırılabilir bir liste DEĞİL: sayfanın tek ortak
    // `CustomScrollView`i içinde bir `SliverToBoxAdapter` çocuğu olarak
    // gösteriliyor; bu yüzden burada sabit/kısıtlı bir Column yeterli.
    return Padding(
      padding: const EdgeInsets.only(top: 48, bottom: 24),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
