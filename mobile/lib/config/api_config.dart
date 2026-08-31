/// Backend kök adresi — tek kaynak.
///
/// Farklı IP için derleme:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.x:8000`
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.107:8000',
  );
}
