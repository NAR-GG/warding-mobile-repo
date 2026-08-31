import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/secure_storage.dart';
import '../../model/community_draft.dart';

/// 커뮤니티 글쓰기 임시저장 목록 — 기기 로컬(로그인 여부 무관), 여러 개 보관.
///
/// 회원 서버 연동 없이 [FlutterSecureStorage] 하나에 JSON 배열로 저장한다
/// (기존 관례, [CalendarWeekStartPreferenceRepository] 참고).
class CommunityDraftRepository {
  CommunityDraftRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? secureStorage;

  static final CommunityDraftRepository instance = CommunityDraftRepository();

  static const String _key = 'community_post_drafts';

  /// 개수 상한 — 무한정 쌓이는 것을 막는다. 초과분은 가장 오래된 것부터 버린다.
  static const int maxDrafts = 20;

  final FlutterSecureStorage _storage;

  Future<List<CommunityDraft>> loadAll() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is Map<String, dynamic>) CommunityDraft.fromJson(e),
      ];
    } catch (e) {
      debugPrint('[CommunityDraftRepository] 목록 읽기 실패: $e');
      return const [];
    }
  }

  /// id 가 없으면 새로 채번해 맨 앞에 추가한다. 있으면 기존 자리를 지우고 맨 앞으로
  /// 올린다(upsert) — 방금 손댄 드래프트가 항상 목록 위쪽에 오게.
  Future<CommunityDraft> save(CommunityDraft draft) async {
    // loadAll()은 저장값이 없거나 손상됐을 때 const [] (불변)를 줄 수 있다 —
    // removeWhere 로 바로 건드리면 UnmodifiableListMixin 이 던진다.
    final list = List<CommunityDraft>.of(await loadAll());
    final saved = draft.id == null
        ? draft.copyWith(id: DateTime.now().microsecondsSinceEpoch)
        : draft;
    list.removeWhere((d) => d.id == saved.id);
    list.insert(0, saved);
    while (list.length > maxDrafts) {
      list.removeLast();
    }
    await _write(list);
    return saved;
  }

  Future<void> delete(int id) async {
    final list = List<CommunityDraft>.of(await loadAll());
    list.removeWhere((d) => d.id == id);
    await _write(list);
  }

  Future<void> _write(List<CommunityDraft> list) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode([for (final d in list) d.toJson()]),
      );
    } catch (e) {
      debugPrint('[CommunityDraftRepository] 저장 실패: $e');
    }
  }
}
