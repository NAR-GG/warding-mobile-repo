import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../model/community_remote_post.dart';
import '../../repository/community/community_api_exception.dart';
import '../../repository/community/community_repository.dart';
import '../../styles/app_colors.dart';
import 'component/post_list_item.dart';
import 'post_detail_screen.dart';

/// 커뮤니티 검색 — 제목·본문 키워드.
///
/// 결과는 목록과 같은 카드([PostListItem])로 그린다. 서버가 목록과 같은 응답
/// 모양을 주므로 카드·페이징 로직을 그대로 재사용한다.
///
/// 입력마다 요청하지 않고 **350ms 디바운스** 한다 — 검색은 LIKE 스캔이라 한 글자
/// 칠 때마다 쏘면 서버 CPU 를 태운다. 2자 미만은 서버가 400 이므로 아예 안 쏜다.
class CommunitySearchScreen extends StatefulWidget {
  const CommunitySearchScreen({super.key});

  @override
  State<CommunitySearchScreen> createState() => _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends State<CommunitySearchScreen> {
  static const int _minLength = 2;
  static const Duration _debounce = Duration(milliseconds: 350);

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final CommunityRepository _repository = CommunityRepository.instance;

  Timer? _timer;
  String _query = '';
  final List<CommunityRemotePost> _results = [];
  int? _nextCursor;
  bool _loading = false;
  bool _loadingMore = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 300) _loadMore();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < _minLength) {
      setState(() {
        _query = trimmed;
        _results.clear();
        _nextCursor = null;
        _searched = false;
        _error = null;
      });
      return;
    }
    _timer = Timer(_debounce, () => _search(trimmed));
  }

  Future<void> _search(String q) async {
    setState(() {
      _query = q;
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repository.searchPosts(q);
      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(page.posts);
        _nextCursor = page.nextCursor;
        _searched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results.clear();
        _searched = true;
        _error = e is CommunityApiException ? e.message : null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore || _loading || _query.length < _minLength) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final page = await _repository.searchPosts(_query, cursor: cursor);
      if (!mounted) return;
      // 이어받는 사이 새 글이 쌓이면 같은 건이 다시 올 수 있다 — id 로 걸러낸다.
      final seen = _results.map((p) => p.id).toSet();
      setState(() {
        _results.addAll(page.posts.where((p) => !seen.contains(p.id)));
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      // 더 받기 실패는 조용히 넘긴다 — 이미 받은 결과는 그대로 보이는 게 낫다.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openPost(CommunityRemotePost post) async {
    final result = await Navigator.of(context).push<PostDetailResult>(
      MaterialPageRoute<PostDetailResult>(
        builder: (_) => PostDetailScreen(postId: post.id),
      ),
    );
    if (result == null || !mounted) return;
    // 삭제·차단된 글은 결과 목록에서도 뺀다.
    if (result.removed) {
      setState(() => _results.removeWhere((p) => p.id == post.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(l, scale),
            Expanded(child: _body(l, scale)),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(AppLocalizations l, double scale) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8 * scale, 8 * scale, 16 * scale, 10 * scale),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: EdgeInsets.all(8 * scale),
              child: Icon(Icons.arrow_back_ios_new,
                  size: 20 * scale, color: AppColors.narText),
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12 * scale),
              decoration: BoxDecoration(
                color: AppColors.narDark600,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18 * scale, color: AppColors.narText2),
                  SizedBox(width: 6 * scale),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      onSubmitted: (v) {
                        final trimmed = v.trim();
                        if (trimmed.length >= _minLength) _search(trimmed);
                      },
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14 * scale,
                        height: 1.4,
                        color: AppColors.narText,
                      ),
                      cursorColor: AppColors.narViolet3,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: l.communitySearchHint,
                        hintStyle: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14 * scale,
                          height: 1.4,
                          color: AppColors.narDark300,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 11 * scale,
                        ),
                      ),
                    ),
                  ),
                  if (_input.text.isNotEmpty)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _input.clear();
                        _onChanged('');
                      },
                      child: Icon(Icons.close,
                          size: 17 * scale, color: AppColors.narText2),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l, double scale) {
    if (_loading && _results.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.narText2,
          ),
        ),
      );
    }
    if (_query.length < _minLength) {
      return _message(l.communitySearchGuide, scale);
    }
    if (_results.isEmpty && _searched) {
      return _message(_error ?? l.communitySearchEmpty, scale);
    }

    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.only(bottom: 24 * scale),
      itemCount: _results.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _results.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16 * scale),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.narText2,
                ),
              ),
            ),
          );
        }
        return PostListItem(
          post: _results[i],
          scale: scale,
          onTap: () => _openPost(_results[i]),
        );
      },
    );
  }

  Widget _message(String text, double scale) => Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 40 * scale),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w400,
          fontSize: 13.5 * scale,
          height: 1.5,
          color: AppColors.narText2,
        ),
      ),
    ),
  );
}
