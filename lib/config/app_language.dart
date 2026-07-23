import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 앱 내 지원 언어.
enum AppLang {
  ko,
  en,
}

/// 앱 언어 설정을 관리한다.
///
/// [FlutterSecureStorage] 에 `app_language` 키로 저장하며,
/// 변경 시 [notifyListeners] 로 구독 위젯에 알린다.
class AppLanguage extends ChangeNotifier {
  AppLanguage._();
  static final AppLanguage instance = AppLanguage._();

  static const _key = 'app_language';
  final _storage = const FlutterSecureStorage();

  AppLang _current = AppLang.ko;

  /// 현재 선택된 언어.
  AppLang get current => _current;

  /// 현재 언어가 한국어인지.
  bool get isKo => _current == AppLang.ko;

  /// 앱 시작 시 저장된 언어를 불러온다.
  Future<void> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == 'en') {
      _current = AppLang.en;
    } else {
      _current = AppLang.ko;
    }
  }

  /// 언어를 변경하고 저장한다.
  Future<void> setLanguage(AppLang lang) async {
    if (_current == lang) return;
    _current = lang;
    await _storage.write(key: _key, value: lang.name);
    notifyListeners();
  }

  /// UI 표시용 라벨에서 [AppLang] 으로 변환.
  static AppLang fromLabel(String label) {
    if (label == 'English') return AppLang.en;
    return AppLang.ko;
  }

  /// [AppLang] 을 UI 표시용 라벨로 변환.
  static String toLabel(AppLang lang) {
    switch (lang) {
      case AppLang.ko:
        return '한국어';
      case AppLang.en:
        return 'English';
    }
  }
}
