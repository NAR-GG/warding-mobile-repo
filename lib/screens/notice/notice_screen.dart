import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../components/nar_detail_header.dart';
import '../../l10n/app_localizations.dart';
import '../../model/notice.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/notice/notice_viewmodel.dart';
import 'notice_detail_screen.dart';

/// 공지사항 목록 화면. 마이페이지 '공지사항' 행에서 진입한다.
class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  final NoticeViewModel _vm = NoticeViewModel();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _vm.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _openDetail(Notice notice) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoticeDetailScreen(notice: notice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NarDetailHeader(title: l.notice, scale: scale),
            Expanded(
              child: ListenableBuilder(
                listenable: _vm,
                builder: (context, _) {
                  if (_vm.notices.isEmpty) {
                    return Center(
                      child: _vm.loading
                          ? const CircularProgressIndicator(
                              color: AppColors.narText2,
                            )
                          : Text(
                              _vm.failed ? l.noticeLoadFailed : l.noticeEmpty,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14 * scale,
                                color: AppColors.narText2,
                              ),
                            ),
                    );
                  }
                  return ListView.separated(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      16 * scale,
                      12 * scale,
                      16 * scale,
                      24 * scale,
                    ),
                    itemCount: _vm.notices.length,
                    separatorBuilder: (_, _) => SizedBox(height: 10 * scale),
                    itemBuilder: (context, index) {
                      final notice = _vm.notices[index];
                      return _NoticeCard(
                        notice: notice,
                        scale: scale,
                        onTap: () => _openDetail(notice),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 공지 한 건 카드. 고정 공지는 그라데이션 보더 + '📌 고정' 라벨.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.scale,
    required this.onTap,
  });

  final Notice notice;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final inner = Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 14 * scale,
      ),
      decoration: BoxDecoration(
        color: AppColors.narBgSecondary,
        borderRadius: BorderRadius.circular(13 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notice.pinned) ...[
            ShaderMask(
              shaderCallback: (bounds) => AppColors.narBg.createShader(bounds),
              child: Text(
                l.noticePinned,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 11 * scale,
                  color: AppColors.narText,
                ),
              ),
            ),
            SizedBox(height: 6 * scale),
          ],
          Text(
            notice.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 14.5 * scale,
              height: 1.4,
              color: AppColors.narTextTertiary,
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            // 임시저장은 ADMIN 계정 검수용으로만 내려온다 — 날짜 대신 노랗게 표시.
            notice.isDraft
                ? l.noticeDraft
                : DateFormat('yyyy.MM.dd').format(notice.publishedAt!),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
              fontSize: 12 * scale,
              color: notice.isDraft ? AppColors.narYellow6 : AppColors.narText2,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: notice.pinned
          // 고정 공지 — narBg 그라데이션 1px 보더.
          ? Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                gradient: AppColors.narBg,
                borderRadius: BorderRadius.circular(14 * scale),
              ),
              child: inner,
            )
          : Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.narLine),
                borderRadius: BorderRadius.circular(14 * scale),
              ),
              child: inner,
            ),
    );
  }
}
