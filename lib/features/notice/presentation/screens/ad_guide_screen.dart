import 'package:flutter/material.dart';

import 'package:warding/core/ui/nar_detail_header.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/features/notice/domain/notice.dart';
import 'package:warding/core/di_container.dart';
import 'package:warding/features/notice/domain/repositories/notice_repository.dart';
import 'package:warding/core/theme/app_colors.dart';
import 'package:warding/features/notice/presentation/screens/notice_detail_screen.dart';

/// 광고 안내 화면. 마이페이지 > 고객 지원에서 연다.
///
/// 본문은 백오피스 공지 화면에서 `slug=ad-guide` 공지로 관리하고, 공지 상세와
/// 같은 마크다운 렌더러로 그린다. 하단 고정 "광고 신청하기" 버튼은 그 공지의
/// 버튼 주소(구글폼)를 외부 브라우저로 연다.
class AdGuideScreen extends StatefulWidget {
  const AdGuideScreen({super.key});

  /// 백오피스에서 이 값으로 공지를 만든다. 서버·앱이 같은 값을 쓴다.
  static const String slug = 'ad-guide';

  @override
  State<AdGuideScreen> createState() => _AdGuideScreenState();
}

class _AdGuideScreenState extends State<AdGuideScreen> {
  late Future<Notice> _page;

  @override
  void initState() {
    super.initState();
    _page = _load();
  }

  /// `FutureBuilder` 는 에러를 예외로 받으므로 Left 를 예외로 되돌린다.
  /// 이 화면은 실패 종류를 구분하지 않고 재시도 버튼만 보여준다.
  Future<Notice> _load() async {
    final result = await di<NoticeRepository>().fetchPage(AdGuideScreen.slug);
    return result.getOrElse((failure) => throw StateError('$failure'));
  }

  void _retry() {
    setState(() {
      _page = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FutureBuilder<Notice>(
      future: _page,
      builder: (context, snapshot) {
        final notice = snapshot.data;
        if (notice != null) {
          // 로드가 끝나면 공지 상세 화면이 헤더부터 통째로 이어받는다.
          return NoticeDetailScreen(
            notice: notice,
            headerTitle: l.adGuide,
            actionLabel: l.adGuideApply,
            landing: true,
          );
        }
        final width = MediaQuery.of(context).size.width;
        final scale = width.clamp(320.0, 430.0) / 375;
        final failed = snapshot.hasError;
        return Scaffold(
          backgroundColor: AppColors.narDark800,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NarDetailHeader(title: l.adGuide, scale: scale),
                Expanded(
                  child: Center(
                    child: failed
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l.adGuideLoadFailed,
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 14 * scale,
                                  color: AppColors.narText2,
                                ),
                              ),
                              SizedBox(height: 12 * scale),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _retry,
                                child: Padding(
                                  padding: EdgeInsets.all(8 * scale),
                                  child: Text(
                                    l.retry,
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14 * scale,
                                      color: AppColors.narTextTertiary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const CircularProgressIndicator(
                            color: AppColors.narText2,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
