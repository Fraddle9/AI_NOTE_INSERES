/// Backend'deki `enums.SurecTipi` (Python) ile BİREBİR aynı katı (strict)
/// sözlük. Serbest metin yerine bu sabitler kullanılarak dropdown/etiket/chip
/// listelerinin backend ile aynı üç değerin dışına çıkması engellenir.
///
/// [tumDegerler] varsayılan (fallback) sırayı temsil eder; ekranlar tercihen
/// `ApiService.fetchSurecTipleri()` ile backend'den DİNAMİK olarak çekilen
/// listeyi kullanır, bu sabitler yalnızca ağ isteği başarısız olursa (ör.
/// bağlantı yok) devreye giren güvenli bir fallback'tir.
abstract class SurecTipi {
  static const String hicbiri = 'Hiçbiri';
  static const String deneme = 'Deneme';
  static const String abonelik = 'Abonelik';

  static const List<String> tumDegerler = [hicbiri, deneme, abonelik];

  static bool gecerliMi(String? deger) => tumDegerler.contains(deger);
}

/// Backend'deki `enums.GorusmeDurumu` (Python) ile BİREBİR aynı katı sözlük.
/// "Karma", metinde bir ürün/konu için olumlu, başka bir ürün/konu için
/// olumsuz sinyal geçtiğinde ya da görüşme genel olarak karışık geribildirim
/// içerdiğinde kullanılır. [tumDegerler] varsayılan/fallback sırayı temsil
/// eder; ekranlar tercihen `ApiService.fetchGorusmeDurumlari()` ile
/// backend'den dinamik olarak çekilen listeyi kullanır.
abstract class GorusmeDurumu {
  static const String beklemede = 'Beklemede';
  static const String olumlu = 'Olumlu';
  static const String olumsuz = 'Olumsuz';
  static const String karma = 'Karma';

  static const List<String> tumDegerler = [beklemede, olumlu, olumsuz, karma];

  static bool gecerliMi(String? deger) => tumDegerler.contains(deger);
}

class Stats {
  final int toplamKurumSayisi;
  final int populerUrunSayisi;
  final int notSayisi;
  final int analizSayisi;
  final int aktifGorevSayisi;
  final SonGorusme? sonGorusme;
  final List<Institution> kurumListesi;
  final List<String> urunListesi;

  const Stats({
    this.toplamKurumSayisi = 0,
    this.populerUrunSayisi = 0,
    this.notSayisi = 0,
    this.analizSayisi = 0,
    this.aktifGorevSayisi = 0,
    this.sonGorusme,
    this.kurumListesi = const [],
    this.urunListesi = const [],
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    final son = json['son_gorusme'];
    final kurumlar = json['kurum_listesi'];
    final urunler = json['urun_listesi'];
    return Stats(
      toplamKurumSayisi: _asInt(json['toplam_kurum_sayisi']),
      populerUrunSayisi: _asInt(json['populer_urun_sayisi']),
      notSayisi: _asInt(json['not_sayisi']),
      analizSayisi: _asInt(json['analiz_sayisi']),
      aktifGorevSayisi: _asInt(json['aktif_gorev_sayisi']),
      sonGorusme: son is Map<String, dynamic> ? SonGorusme.fromJson(son) : null,
      kurumListesi: kurumlar is List
          ? kurumlar
              .whereType<Map>()
              .map((e) => Institution.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      urunListesi: urunler is List
          ? urunler.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
          : const [],
    );
  }
}

class SonGorusme {
  final String? tarih;
  final String? kurumAdi;
  final String? durum;
  final int? kurumId;

  const SonGorusme({this.tarih, this.kurumAdi, this.durum, this.kurumId});

  factory SonGorusme.fromJson(Map<String, dynamic> json) {
    return SonGorusme(
      tarih: json['tarih'] as String?,
      kurumAdi: json['kurum_adi'] as String?,
      durum: json['durum'] as String?,
      kurumId: json['kurum_id'] == null ? null : _asInt(json['kurum_id']),
    );
  }
}

class Institution {
  final int id;
  final String name;
  final String? type;
  final String? createdAt;

  const Institution({
    required this.id,
    required this.name,
    this.type,
    this.createdAt,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: _asInt(json['id'] ?? json['kurum_id']),
      name: ((json['name'] ?? json['kurum_adi']) as String?)?.trim() ?? '',
      type: (json['type'] ?? json['kurum_turu']) as String?,
      createdAt: (json['created_at'] ?? json['eklenme_tarihi']) as String?,
    );
  }
}

class InstitutionDetail {
  final int id;
  final String kurumAdi;
  final String? kurumTuru;
  final String? sonGorusmeTarihi;
  final List<String> ilgilenilenUrunler;
  final String? surecTipi;
  final String? gorusmeDurumu;
  final String? gecmisNot;

  const InstitutionDetail({
    required this.id,
    required this.kurumAdi,
    this.kurumTuru,
    this.sonGorusmeTarihi,
    this.ilgilenilenUrunler = const [],
    this.surecTipi,
    this.gorusmeDurumu,
    this.gecmisNot,
  });

  factory InstitutionDetail.fromJson(Map<String, dynamic> json) {
    final urunler = json['ilgilenilen_urunler'];
    return InstitutionDetail(
      id: _asInt(json['id']),
      kurumAdi: (json['kurum_adi'] as String?)?.trim() ?? '',
      kurumTuru: json['kurum_turu'] as String?,
      sonGorusmeTarihi: json['son_gorusme_tarihi'] as String?,
      ilgilenilenUrunler: urunler is List
          ? urunler.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
          : const [],
      surecTipi: (json['surec_tipi'] as String?) ?? json['abonelik_tipi'] as String?,
      gorusmeDurumu: json['gorusme_durumu'] as String?,
      gecmisNot: json['gecmis_not'] as String?,
    );
  }
}

/// Tekil görüşme detayındaki AI görev özeti (`GET /api/analizler/{id}`).
class AnalysisGorev {
  final int? id;
  final String baslik;
  final bool tamamlandi;
  final String? assignedUserName;
  final String? kaynak;
  final String? kurumAdi;

  const AnalysisGorev({
    this.id,
    required this.baslik,
    this.tamamlandi = false,
    this.assignedUserName,
    this.kaynak,
    this.kurumAdi,
  });

  factory AnalysisGorev.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return AnalysisGorev(
      id: rawId == null ? null : _asInt(rawId),
      baslik: (json['baslik'] as String?)?.trim() ?? '',
      tamamlandi: json['tamamlandi'] == true,
      assignedUserName: json['assigned_user_name'] as String?,
      kaynak: json['kaynak'] as String?,
      kurumAdi: json['kurum_adi'] as String?,
    );
  }
}

class AnalysisRecord {
  final int id;
  final String? kurumAdi;
  final String? urunKodu;
  final String? urunAdi;
  final List<String> ilgilenilenUrunler;
  final String? durum;
  final String? surecTipi;
  final String? abonelikTipi;
  final String? notIcerigi;
  final String? kaynak;
  final String? tarih;
  /// Admin görünümünde dolu gelir — kaydı ekleyen personelin adı
  final String? kullaniciAdi;
  /// Yalnızca tekil kayıt cevabında dolu gelir (liste özetinde boş olabilir).
  final List<AnalysisGorev> gorevler;

  const AnalysisRecord({
    required this.id,
    this.kurumAdi,
    this.urunKodu,
    this.urunAdi,
    this.ilgilenilenUrunler = const [],
    this.durum,
    this.surecTipi,
    this.abonelikTipi,
    this.notIcerigi,
    this.kaynak,
    this.tarih,
    this.kullaniciAdi,
    this.gorevler = const [],
  });

  factory AnalysisRecord.fromJson(Map<String, dynamic> json) {
    final urunler = json['ilgilenilen_urunler'];
    final gorevler = json['gorevler'];
    return AnalysisRecord(
      id: _asInt(json['id']),
      kurumAdi: json['kurum_adi'] as String?,
      urunKodu: json['urun_kodu'] as String?,
      urunAdi: json['urun_adi'] as String?,
      ilgilenilenUrunler: urunler is List
          ? urunler.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
          : const [],
      durum: json['durum'] as String?,
      surecTipi: (json['surec_tipi'] as String?) ?? json['abonelik_tipi'] as String?,
      abonelikTipi: (json['surec_tipi'] as String?) ?? json['abonelik_tipi'] as String?,
      notIcerigi: json['not_icerigi'] as String?,
      kaynak: json['kaynak'] as String?,
      tarih: json['tarih'] as String?,
      kullaniciAdi: json['kullanici_adi'] as String?,
      gorevler: gorevler is List
          ? gorevler
              .whereType<Map>()
              .map((e) => AnalysisGorev.fromJson(Map<String, dynamic>.from(e)))
              .where((g) => g.baslik.isNotEmpty)
              .toList()
          : const [],
    );
  }

  List<String> get urunRozetleri {
    if (ilgilenilenUrunler.isNotEmpty) return ilgilenilenUrunler;
    final tek = urunEtiketi;
    return tek.isEmpty ? const [] : [tek];
  }

  String get urunEtiketi {
    if (ilgilenilenUrunler.isNotEmpty) return ilgilenilenUrunler.first;
    final ad = (urunAdi ?? '').trim();
    if (ad.isNotEmpty) return ad;
    return (urunKodu ?? '').trim();
  }

  String get kaynakEtiketi => kaynak == 'manuel' ? 'Manuel' : 'AI';

  static String normalizeDurum(String? durum) {
    final d = (durum ?? '').toLowerCase();
    if (d.contains('karma')) return 'Karma';
    if (d.contains('olumsuz')) return 'Olumsuz';
    if (d.contains('olumlu')) return 'Olumlu';
    return 'Beklemede';
  }

  static String normalizeSurecTipi(String? deger) {
    if (SurecTipi.gecerliMi(deger)) return deger!;
    final d = (deger ?? '').toLowerCase();
    if (d.contains('deneme') || d.contains('demo') || d.contains('trial') || d.contains('pilot')) {
      return SurecTipi.deneme;
    }
    if (d.contains('abone') ||
        d.contains('satın') ||
        d.contains('satin') ||
        d.contains('lisans') ||
        d.contains('kontrat') ||
        d.contains('sözleşme') ||
        d.contains('sozlesme')) {
      return SurecTipi.abonelik;
    }
    return SurecTipi.hicbiri;
  }

  static String normalizeAbonelikTipi(String? abonelikTipi) {
    return normalizeSurecTipi(abonelikTipi);
  }
}

class Product {
  final int id;
  final String code;
  final String name;
  final bool isActive;

  const Product({
    required this.id,
    required this.code,
    required this.name,
    this.isActive = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: _asInt(json['id']),
      code: (json['code'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      isActive: json['is_active'] != false,
    );
  }
}

class AnalysisWrite {
  final String kurumAdi;
  final String? urunKodu;
  final String? urunAdi;
  /// Görüşmede geçen TÜM ürünlerin adları (birden fazla olabilir). Boş
  /// bırakılırsa geriye dönük uyumluluk için sadece [urunAdi] (tek ürün)
  /// gönderilir.
  final List<String> ilgilenilenUrunAdlari;
  final String durum;
  final String surecTipi;
  final String abonelikTipi;
  final String? notIcerigi;

  const AnalysisWrite({
    required this.kurumAdi,
    this.urunKodu,
    this.urunAdi,
    this.ilgilenilenUrunAdlari = const [],
    this.durum = 'Beklemede',
    this.surecTipi = SurecTipi.hicbiri,
    this.abonelikTipi = SurecTipi.hicbiri,
    this.notIcerigi,
  });

  Map<String, dynamic> toJson() {
    final surec = surecTipi.isNotEmpty ? surecTipi : abonelikTipi;
    final urunler = ilgilenilenUrunAdlari.isNotEmpty
        ? ilgilenilenUrunAdlari
        : ((urunAdi ?? '').trim().isEmpty ? const <String>[] : [urunAdi!.trim()]);
    return {
      'kurum_adi': kurumAdi,
      'urun_kodu': urunKodu,
      'urun_adi': urunAdi,
      'durum': durum,
      'surec_tipi': surec,
      'abonelik_tipi': surec,
      'ilgilenilen_urunler': urunler,
      'not_icerigi': notIcerigi,
    };
  }
}

class TaskItem {
  final int id;
  final String baslik;
  final String? kaynak;
  final bool tamamlandi;
  final String? tarih;
  final String? kurumAdi;
  final int? userId;
  final int? assignedUserId;
  final String? assignedUserName;
  final String? olusturanAdi;

  const TaskItem({
    required this.id,
    required this.baslik,
    this.kaynak,
    this.tamamlandi = false,
    this.tarih,
    this.kurumAdi,
    this.userId,
    this.assignedUserId,
    this.assignedUserName,
    this.olusturanAdi,
  });

  /// Başkası tarafından bir kullanıcıya atanmış görev mi? (oluşturan ≠ atanan)
  bool get atamaGoreviMi {
    final atanan = assignedUserId ?? userId;
    final olusturan = userId;
    if (olusturan == null || atanan == null) return false;
    return olusturan != atanan;
  }

  /// Bu kullanıcının yöneticiden aldığı görev mi?
  bool yoneticiAtamasiMi(int? mevcutKullaniciId) {
    if (mevcutKullaniciId == null || !atamaGoreviMi) return false;
    final atanan = assignedUserId ?? userId;
    return atanan == mevcutKullaniciId;
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: _asInt(json['id']),
      baslik: (json['baslik'] as String?)?.trim() ?? '',
      kaynak: json['kaynak'] as String?,
      tamamlandi: json['tamamlandi'] == true,
      tarih: json['tarih'] as String?,
      kurumAdi: json['kurum_adi'] as String?,
      userId: json['user_id'] == null ? null : _asInt(json['user_id']),
      assignedUserId:
          json['assigned_user_id'] == null ? null : _asInt(json['assigned_user_id']),
      assignedUserName: json['assigned_user_name'] as String?,
      olusturanAdi: json['olusturan_adi'] as String?,
    );
  }
}

class TaskWrite {
  final String? baslik;
  final String? kurumAdi;
  final bool? tamamlandi;

  const TaskWrite({this.baslik, this.kurumAdi, this.tamamlandi});

  Map<String, dynamic> toJson() {
    return {
      if (baslik != null) 'baslik': baslik,
      if (kurumAdi != null) 'kurum_adi': kurumAdi,
      if (tamamlandi != null) 'tamamlandi': tamamlandi,
    };
  }
}

class TextAnalyzeResult {
  final String mesaj;
  final String? kurumAdi;
  final String? durum;
  final String? urunAdi;
  final String? surecTipi;
  final String? abonelikTipi;
  final int? analizId;
  final int kayitliGorevSayisi;
  final List<String> gorevler;

  const TextAnalyzeResult({
    this.mesaj = 'Analiz tamamlandı',
    this.kurumAdi,
    this.durum,
    this.urunAdi,
    this.surecTipi,
    this.abonelikTipi,
    this.analizId,
    this.kayitliGorevSayisi = 0,
    this.gorevler = const [],
  });

  factory TextAnalyzeResult.fromJson(Map<String, dynamic> json) {
    final gorevler = json['gorevler'];
    return TextAnalyzeResult(
      mesaj: (json['mesaj'] as String?) ?? 'Analiz tamamlandı',
      kurumAdi: json['kurum_adi'] as String?,
      durum: json['durum'] as String?,
      urunAdi: json['urun_adi'] as String?,
      surecTipi: (json['surec_tipi'] as String?) ?? json['abonelik_tipi'] as String?,
      abonelikTipi: (json['surec_tipi'] as String?) ?? json['abonelik_tipi'] as String?,
      analizId: json['analiz_id'] == null ? null : _asInt(json['analiz_id']),
      kayitliGorevSayisi: _asInt(json['kayitli_gorev_sayisi']),
      gorevler: gorevler is List
          ? gorevler.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
          : const [],
    );
  }
}

class NotificationItem {
  final int id;
  final String title;
  final String? body;
  final String? actorName;
  final int? taskId;
  final String kind;
  final bool isRead;
  final String? createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    this.body,
    this.actorName,
    this.taskId,
    this.kind = 'gorev_atama',
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: _asInt(json['id']),
      title: (json['title'] as String?)?.trim() ?? 'Bildirim',
      body: (json['body'] as String?)?.trim(),
      actorName: (json['actor_name'] as String?)?.trim(),
      taskId: json['task_id'] == null ? null : _asInt(json['task_id']),
      kind: (json['kind'] as String?)?.trim() ?? 'gorev_atama',
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] as String?,
    );
  }
}

class NotificationInbox {
  final int unread;
  final List<NotificationItem> items;

  const NotificationInbox({this.unread = 0, this.items = const []});

  factory NotificationInbox.fromJson(Map<String, dynamic> json) {
    final liste = json['bildirimler'];
    return NotificationInbox(
      unread: _asInt(json['okunmamis']),
      items: liste is List
          ? liste
              .whereType<Map>()
              .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

class DbTableInfo {
  final String ad;
  final String baslik;

  const DbTableInfo({required this.ad, required this.baslik});

  factory DbTableInfo.fromJson(Map<String, dynamic> json) {
    final ad = (json['ad'] as String?)?.trim() ?? '';
    return DbTableInfo(
      ad: ad,
      baslik: ((json['baslik'] as String?)?.trim().isNotEmpty ?? false)
          ? (json['baslik'] as String).trim()
          : ad,
    );
  }
}

class DbTableData {
  final String ad;
  final String baslik;
  final List<String> kolonlar;
  final List<Map<String, dynamic>> kayitlar;

  const DbTableData({
    required this.ad,
    required this.baslik,
    this.kolonlar = const [],
    this.kayitlar = const [],
  });

  factory DbTableData.fromJson(Map<String, dynamic> json) {
    final kolonlar = json['kolonlar'];
    final kayitlar = json['kayitlar'];
    return DbTableData(
      ad: (json['ad'] as String?)?.trim() ?? '',
      baslik: (json['baslik'] as String?)?.trim() ?? '',
      kolonlar: kolonlar is List
          ? kolonlar.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      kayitlar: kayitlar is List
          ? kayitlar
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
    );
  }
}

