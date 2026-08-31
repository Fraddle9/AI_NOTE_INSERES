// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'fcm_push_service.dart';

/// Token & kullanıcı bilgisi için localStorage'a karşılık gelen anahtar adları.
const _kToken   = 'crm_auth_token';
const _kUser    = 'crm_auth_user';

/// Oturum açılmış kullanıcıyı temsil eder.
class AuthUser {
  final int? id;
  final String kullaniciAdi;
  final String adSoyad;
  /// "admin" veya "user"
  final String role;

  const AuthUser({
    this.id,
    required this.kullaniciAdi,
    required this.adSoyad,
    this.role = 'user',
  });

  bool get isAdmin => role == 'admin';

  String get gorunenAd =>
      adSoyad.trim().isNotEmpty ? adSoyad.trim() : kullaniciAdi;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] == null ? null : int.tryParse('${j['id']}'),
        kullaniciAdi: j['kullanici_adi'] as String? ?? '',
        adSoyad: j['ad_soyad'] as String? ?? j['kullanici_adi'] as String? ?? '',
        role: j['role'] as String? ?? 'user',
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'kullanici_adi': kullaniciAdi,
        'ad_soyad': adSoyad,
        'role': role,
      };
}

/// Kimlik doğrulama servisi.
///
/// - [login]   → backend'den JWT alır, shared_preferences'e kaydeder
/// - [logout]  → token + kullanıcıyı siler
/// - [getToken]  → saklanan token'ı döndürür (yoksa null)
/// - [getUser]   → saklanan AuthUser'ı döndürür (yoksa null)
class AuthService {
  static String get baseUrl => ApiConfig.baseUrl;

  /// Kullanıcı adı ve şifreyle giriş yapar.
  /// Başarılıysa [AuthUser] döndürür, başarısızsa exception fırlatır.
  static Future<AuthUser> login(String kullaniciAdi, String sifre) async {
    return _kimlikIstek(
      '/login',
      {'kullanici_adi': kullaniciAdi, 'sifre': sifre},
      hataVarsayilan: 'Giriş başarısız',
    );
  }

  /// Özgür kayıt: role=user hesabı açar ve oturumu başlatır.
  static Future<AuthUser> register(
    String kullaniciAdi,
    String sifre, {
    String? adSoyad,
  }) async {
    return _kimlikIstek(
      '/register',
      {
        'kullanici_adi': kullaniciAdi,
        'sifre': sifre,
        'ad_soyad': (adSoyad == null || adSoyad.trim().isEmpty) ? null : adSoyad.trim(),
      },
      hataVarsayilan: 'Kayıt başarısız',
    );
  }

  static Future<AuthUser> _kimlikIstek(
    String yol,
    Map<String, dynamic> govde, {
    required String hataVarsayilan,
  }) async {
    print('[AuthService] POST $baseUrl$yol  user=${govde['kullanici_adi']}');
    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl$yol'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(govde),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Sunucuya bağlanılamadı: $e');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Sunucudan geçersiz yanıt alındı');
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      final detail = data['detail'];
      throw Exception(detail is String ? detail : '$hataVarsayilan (HTTP ${response.statusCode})');
    }

    final token = data['access_token'] as String? ?? '';
    final user  = AuthUser.fromJson(data);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
    print('[AuthService] Oturum açıldı: ${user.kullaniciAdi} (role=${user.role})');
    await FcmPushService.tokenuKaydet();
    return user;
  }

  /// Token ve kullanıcı bilgisini diskten siler.
  static Future<void> logout() async {
    await FcmPushService.tokenuSil();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
    print('[AuthService] Çıkış yapıldı.');
  }

  /// Diskten token okur (yoksa null).
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  /// Diskten kullanıcı bilgisini okur (yoksa null).
  static Future<AuthUser?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Token geçerli mi? (basit null check; JWT expire kontrolü backend'e bırakılır)
  static Future<bool> isAuthenticated() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  /// Giriş ekranı: kayıt açık mı?
  static Future<bool> fetchAllowPublicRegister() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/ayarlar'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return data['allow_public_register'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Oturum açmış kullanıcının şifresini günceller (kullanıcı adı değişmez).
  static Future<void> changePassword({
    required String mevcutSifre,
    required String yeniSifre,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Oturum bulunamadı');
    }

    late final http.Response response;
    try {
      response = await http.put(
        Uri.parse('$baseUrl/api/sifre'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'mevcut_sifre': mevcutSifre,
          'yeni_sifre': yeniSifre,
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Sunucuya bağlanılamadı: $e');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Sunucudan geçersiz yanıt alındı');
    }

    if (response.statusCode != 200) {
      final detail = data['detail'];
      if (detail is List && detail.isNotEmpty) {
        final ilk = detail.first;
        if (ilk is Map && ilk['msg'] != null) {
          throw Exception(ilk['msg'].toString());
        }
      }
      throw Exception(detail is String ? detail : 'Şifre güncellenemedi (HTTP ${response.statusCode})');
    }

    final yeniToken = data['access_token'] as String?;
    if (yeniToken != null && yeniToken.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, yeniToken);
    }
  }

  /// Oturum açmış kullanıcının görünen adını günceller (kullanıcı adı değişmez).
  static Future<AuthUser> updateProfile({required String adSoyad}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Oturum bulunamadı');
    }

    late final http.Response response;
    try {
      response = await http.put(
        Uri.parse('$baseUrl/api/profil'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'ad_soyad': adSoyad.trim()}),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Sunucuya bağlanılamadı: $e');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Sunucudan geçersiz yanıt alındı');
    }

    if (response.statusCode != 200) {
      final detail = data['detail'];
      if (detail is List && detail.isNotEmpty) {
        final ilk = detail.first;
        if (ilk is Map && ilk['msg'] != null) {
          throw Exception(ilk['msg'].toString());
        }
      }
      throw Exception(detail is String ? detail : 'Profil güncellenemedi (HTTP ${response.statusCode})');
    }

    final user = AuthUser.fromJson(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
    return user;
  }
}
