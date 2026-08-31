import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/models.dart';

// Token anahtarı AuthService ile aynı olmalı
const _kToken = 'crm_auth_token';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// FastAPI backend istemcisi (`http` paketi).
///
/// UYGULAMA ARTIK FİZİKSEL CİHAZDA test ediliyor (emülatör değil), bu yüzden
/// `baseUrl` bilgisayarın aynı Wi-Fi ağındaki **yerel LAN IP adresini**
/// kullanır: `192.168.1.107`.
///
/// DİKKAT:
/// - `localhost` / `127.0.0.1` fiziksel cihazda ÇALIŞMAZ (telefonun kendi
///   loopback adresini işaret eder, bilgisayarı değil).
/// - `10.0.2.2` SADECE Android emülatörde çalışır, fiziksel cihazda ÇALIŞMAZ.
/// - Telefon ve bilgisayar AYNI Wi-Fi ağında olmalı.
/// - Backend `uvicorn main:app --host 0.0.0.0 --port 8000` ile başlatılmalı
///   (sadece `127.0.0.1`'e bağlarsa LAN'daki diğer cihazlar erişemez).
/// - Bilgisayarın IP'si değişirse (DHCP yeniden atarsa) bu sabiti güncelleyin.
///   Güncel IP'yi görmek için terminalde: `ipconfig getifaddr en0` (macOS Wi-Fi).
class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  /// 401 yanıtında oturumu kapatıp login'e yönlendirmek için (main.dart'ta atanır).
  static Future<void> Function()? onUnauthorized;

  /// Tüm istekler için asgari zaman aşımı süresi.
  /// birkaç saniyeden uzun sürebildiği için bağlantı erken kesilmesin diye
  /// 60 saniyeye çıkarıldı (önceden GET=20sn, POST/PUT/PATCH/DELETE=30sn idi).
  static const Duration _defaultTimeout = Duration(seconds: 60);

  ApiService({http.Client? client}) : _client = client ?? http.Client() {
    print('[ApiService] Backend adresi: $baseUrl '
        '(bilgisayarın yerel Wi-Fi IP\'si; telefon ile aynı ağda olmalı)');
  }

  final http.Client _client;

  Future<Stats> fetchStats() async {
    final data = await _getJson('/api/istatistikler');
    return Stats.fromJson(data);
  }

  Future<List<AnalysisRecord>> fetchAnalyses() async {
    final data = await _getJson('/api/analizler');
    final kayitlar = data['kayitlar'];
    if (kayitlar is! List) return const [];
    final liste = kayitlar
        .whereType<Map>()
        .map((e) => AnalysisRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    // Backend zaten en yeniden en eskiye (DESC) döndürür; burada da açıkça
    // en yeni kayıt (en büyük id) HER ZAMAN listenin en üstünde olacak
    // şekilde sıralıyoruz. `id` otomatik artan ve tekil olduğu için, aynı
    // görüşmeden çıkan birden fazla kayıt aynı saniyede oluşsa bile sıralama
    // deterministik kalır.
    liste.sort((a, b) => b.id.compareTo(a.id));
    return liste;
  }

  Future<List<TaskItem>> fetchTasks() async {
    final data = await _getJson('/api/gorevler');
    final gorevler = data['gorevler'];
    if (gorevler is! List) return const [];
    final liste = gorevler
        .whereType<Map>()
        .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    // Bkz. fetchAnalyses() açıklaması: en yeni görev her zaman en üstte.
    liste.sort((a, b) => b.id.compareTo(a.id));
    return liste;
  }

  /// Backend'deki katı `enums.GorusmeDurumu` listesini döndürür (Olumlu/
  /// Olumsuz/Karma/Beklemede). İstek başarısız olursa çağıran taraf
  /// `GorusmeDurumu.tumDegerler` sabit listesine düşer (fallback).
  Future<List<String>> fetchGorusmeDurumlari() async {
    final data = await _getJson('/api/gorusme-durumlari');
    final degerler = data['degerler'];
    if (degerler is! List) return const [];
    return degerler.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }

  Future<List<Product>> fetchProducts() async {
    final data = await _getJson('/api/urunler');
    final urunler = data['urunler'];
    if (urunler is! List) return const [];
    return urunler
        .whereType<Map>()
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Product> createProduct({
    required String name,
    String? code,
    int? companyId,
  }) async {
    final data = await _sendJson('POST', '/api/urunler', {
      'name': name,
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
      if (companyId != null) 'company_id': companyId,
    });
    final urun = data['urun'];
    if (urun is Map) return Product.fromJson(Map<String, dynamic>.from(urun));
    return Product.fromJson(data);
  }

  Future<void> deleteProduct(int id) async {
    await _sendJson('DELETE', '/api/urunler/$id', null);
  }

  /// Backend'deki katı `enums.SurecTipi` listesini döndürür (Hiçbiri/Deneme/
  /// Abonelik). Dropdown'un backend ile birebir aynı kalması için tercih
  /// edilen yol budur; çağıran taraf (ör. `EditFormSheet`) istek başarısız
  /// olursa `SurecTipi.tumDegerler` sabit listesine düşer (fallback), böylece
  /// mevcut davranış hiçbir zaman bozulmaz.
  Future<List<String>> fetchSurecTipleri() async {
    final data = await _getJson('/api/surec-tipleri');
    final degerler = data['degerler'];
    if (degerler is! List) return const [];
    return degerler.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }

  Future<AnalysisRecord> fetchAnalysis(int id) async {
    final data = await _getJson('/api/analizler/$id');
    return AnalysisRecord.fromJson(data);
  }

  Future<AnalysisRecord> createAnalysis(AnalysisWrite payload) async {
    final data = await _sendJson('POST', '/api/analizler', payload.toJson());
    final kayit = data['kayit'];
    if (kayit is Map) return AnalysisRecord.fromJson(Map<String, dynamic>.from(kayit));
    return AnalysisRecord.fromJson(data);
  }

  Future<AnalysisRecord> updateAnalysis(int id, AnalysisWrite payload) async {
    final data = await _sendJson('PUT', '/api/analizler/$id', payload.toJson());
    final kayit = data['kayit'];
    if (kayit is Map) return AnalysisRecord.fromJson(Map<String, dynamic>.from(kayit));
    return AnalysisRecord.fromJson(data);
  }

  Future<AnalysisRecord> patchAnalysis(int id, Map<String, dynamic> fields) async {
    final data = await _sendJson('PATCH', '/api/analizler/$id', fields);
    final kayit = data['kayit'];
    if (kayit is Map) return AnalysisRecord.fromJson(Map<String, dynamic>.from(kayit));
    return AnalysisRecord.fromJson(data);
  }

  /// Flutter'da `speech_to_text` ile cihazda üretilen nihai transkripti
  /// Gemini CRM analizine gönderir. Ses dosyası bu akışa hiç girmez.
  Future<TextAnalyzeResult> analyzeText(String text) async {
    print('[ApiService] analyzeText çağrıldı. Metin uzunluğu: ${text.length} karakter, '
        'önizleme: "${text.length > 80 ? text.substring(0, 80) : text}..."');
    final data = await _sendJson(
      'POST',
      '/api/analyze-text',
      {'text': text},
      // Gemini analizi 60sn'yi aşabildiği için burada daha yüksek bir süre tanınıyor.
      timeout: const Duration(seconds: 180),
    );
    return TextAnalyzeResult.fromJson(data);
  }

  Future<void> deleteAnalysis(int id) async {
    await _sendJson('DELETE', '/api/analizler/$id', null);
  }

  Future<List<Institution>> fetchInstitutions() async {
    final data = await _getJson('/kurumlar');
    final list = data['kurum_listesi'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Institution.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<InstitutionDetail> fetchInstitutionDetail({int? id, String? ad}) async {
    final query = <String, String>{
      if (id != null) 'id': '$id',
      if (ad != null && ad.trim().isNotEmpty) 'ad': ad.trim(),
    };
    final data = await _getJson('/api/kurum-detay', query);
    return InstitutionDetail.fromJson(data);
  }

  Future<Institution> createInstitution({required String name, String type = 'UNIVERSITE'}) async {
    final data = await _sendJson('POST', '/kurumlar/', {
      'name': name,
      'type': type,
    });
    final idRaw = data['kurum_id'] ?? data['id'];
    return Institution(
      id: idRaw is int ? idRaw : int.tryParse('$idRaw') ?? 0,
      name: (data['kurum_adi'] as String?) ?? name,
      type: type,
    );
  }

  Future<void> updateInstitution(int id, {String? yeniAd, String? yeniTip}) async {
    await _sendJson('PUT', '/kurum/$id', {
      if (yeniAd != null) 'yeni_ad': yeniAd,
      if (yeniTip != null) 'yeni_tip': yeniTip,
    });
  }

  Future<void> deleteInstitution(int id) async {
    await _sendJson('DELETE', '/kurum/$id', null);
  }

  Future<List<DbTableInfo>> fetchDbTables() async {
    final data = await _getJson('/api/tablolar');
    final list = data['tablolar'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => DbTableInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DbTableData> fetchDbTableRows(String tabloAdi) async {
    final data = await _getJson('/api/tablolar/${Uri.encodeComponent(tabloAdi)}');
    return DbTableData.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> fetchProductUsers(int productId) async {
    final data = await _getJson('/api/urunler/$productId/kullanicilar');
    final liste = data['kullanicilar'];
    if (liste is! List) return const [];
    return liste.whereType<Map>().map((raw) {
      final e = Map<String, dynamic>.from(raw);
      final idRaw = e['id'];
      e['id'] = idRaw is int ? idRaw : int.tryParse('$idRaw');
      return e;
    }).where((e) => e['id'] is int).toList();
  }

  Future<TaskItem> assignTask({
    required String baslik,
    required int assignedUserId,
    required int urunId,
  }) async {
    final data = await _sendJson('POST', '/api/gorevler', {
      'baslik': baslik,
      'description': baslik,
      'assigned_user_id': assignedUserId,
      'urun_id': urunId,
    });
    final gorev = data['gorev'];
    if (gorev is Map) return TaskItem.fromJson(Map<String, dynamic>.from(gorev));
    return TaskItem.fromJson(data);
  }

  Future<TaskItem> createTask(TaskWrite payload) async {
    final data = await _sendJson('POST', '/api/gorevler', {
      'baslik': payload.baslik,
      'kurum_adi': payload.kurumAdi,
    });
    final gorev = data['gorev'];
    if (gorev is Map) return TaskItem.fromJson(Map<String, dynamic>.from(gorev));
    return TaskItem.fromJson(data);
  }

  Future<TaskItem> updateTask(int id, TaskWrite payload) async {
    final data = await _sendJson('PUT', '/api/gorevler/$id', payload.toJson());
    final gorev = data['gorev'];
    if (gorev is Map) return TaskItem.fromJson(Map<String, dynamic>.from(gorev));
    return TaskItem.fromJson(data);
  }

  Future<TaskItem> patchTask(int id, Map<String, dynamic> fields) async {
    final data = await _sendJson('PATCH', '/api/gorevler/$id', fields);
    final gorev = data['gorev'];
    if (gorev is Map) return TaskItem.fromJson(Map<String, dynamic>.from(gorev));
    return TaskItem.fromJson(data);
  }

  Future<void> deleteTask(int id) async {
    await _sendJson('DELETE', '/api/gorevler/$id', null);
  }

  Future<NotificationInbox> fetchNotifications() async {
    final data = await _getJson('/api/bildirimler');
    return NotificationInbox.fromJson(data);
  }

  Future<void> markNotificationRead(int id) async {
    await _sendJson('PUT', '/api/bildirimler/$id/okundu', null);
  }

  Future<void> markAllNotificationsRead() async {
    await _sendJson('PUT', '/api/bildirimler/okundu-hepsi', null);
  }

  Future<void> registerDeviceToken(String token, String platform) async {
    await _sendJson('POST', '/api/cihaz-token', {
      'token': token,
      'platform': platform,
    });
  }

  Future<void> deleteDeviceToken(String token) async {
    final encoded = Uri.encodeQueryComponent(token);
    await _sendJson('DELETE', '/api/cihaz-token?token=$encoded', null);
  }

  /// Mevcut token'ı SharedPreferences'ten alır, Authorization header olarak döndürür.
  Future<Map<String, String>> _authHeaders({bool hasBody = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    return <String, String>{
      'Accept': 'application/json',
      if (hasBody) 'Content-Type': 'application/json; charset=utf-8',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _getJson(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final stopwatch = Stopwatch()..start();
    print('[ApiService] --> GET $uri');
    try {
      final headers = await _authHeaders();
      final response = await _client
          .get(uri, headers: headers)
          .timeout(_defaultTimeout);
      stopwatch.stop();
      print('[ApiService] <-- GET $uri  ${response.statusCode}  (${stopwatch.elapsedMilliseconds} ms)');
      return _decode(response);
    } on SocketException catch (e) {
      print('[ApiService] BAĞLANTI HATASI: GET $uri -> $e');
      throw ApiException(
        'Sunucuya bağlanılamadı. Backend çalışıyor mu ve telefon aynı Wi-Fi ağında mı? '
        '($baseUrl)',
      );
    } on TimeoutException {
      print('[ApiService] ZAMAN AŞIMI: GET $uri, ${_defaultTimeout.inSeconds}sn içinde yanıt gelmedi.');
      throw const ApiException('İstek zaman aşımına uğradı.');
    }
  }

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path,
    Map<String, dynamic>? body, {
    Duration timeout = _defaultTimeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _authHeaders(hasBody: body != null);
    final encoded = body == null ? null : jsonEncode(body);
    final stopwatch = Stopwatch()..start();
    print('[ApiService] --> $method $uri (timeout: ${timeout.inSeconds}sn)');

    try {
      late final http.Response response;
      switch (method) {
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: encoded)
              .timeout(timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: headers, body: encoded)
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: encoded)
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers, body: encoded)
              .timeout(timeout);
          break;
        default:
          throw ApiException('Desteklenmeyen HTTP yöntemi: $method');
      }
      stopwatch.stop();
      print('[ApiService] <-- $method $uri  ${response.statusCode}  (${stopwatch.elapsedMilliseconds} ms)');
      return _decode(response);
    } on SocketException catch (e) {
      print('[ApiService] BAĞLANTI HATASI: $method $uri -> $e');
      throw ApiException(
        'Sunucuya bağlanılamadı. Backend çalışıyor mu ve telefon aynı Wi-Fi ağında mı? '
        '($baseUrl)',
      );
    } on TimeoutException {
      print('[ApiService] ZAMAN AŞIMI: $method $uri, ${timeout.inSeconds}sn içinde yanıt gelmedi. '
          'Backend çok mu yavaş çalışıyor, yoksa bağlantı mı kopuk kontrol edin.');
      throw const ApiException('İstek zaman aşımına uğradı.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final raw = utf8.decode(response.bodyBytes);
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      } else {
        throw const ApiException('Sunucudan geçersiz veya boş yanıt alındı');
      }
    } on FormatException {
      throw const ApiException('Sunucudan geçersiz veya boş yanıt alındı');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        final handler = onUnauthorized;
        if (handler != null) {
          unawaited(handler());
        }
      }
      throw ApiException(
        _errorMessage(data, response.statusCode),
        statusCode: response.statusCode,
      );
    }
    final hata = data['hata'];
    if (hata is String && hata.trim().isNotEmpty) {
      throw ApiException(hata.trim());
    }
    return data;
  }

  String _errorMessage(Map<String, dynamic> data, int status) {
    final detail = data['detail'] ?? data['hata'] ?? data['detay'] ?? data['message'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (detail is List && detail.isNotEmpty) {
      return detail.map((x) => x is Map ? (x['msg'] ?? x) : x).join(' ');
    }
    return 'Sunucu hatası (HTTP $status)';
  }
}
