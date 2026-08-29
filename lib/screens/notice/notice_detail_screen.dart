import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/nar_detail_header.dart';
import '../../l10n/app_localizations.dart';
import '../../model/notice.dart';
import '../../repository/notice/notice_repository.dart';
import '../../styles/app_colors.dart';
import 'notice_screen.dart';

/// 공지사항 상세 화면. 목록/띠배너에서 [Notice]를 통째로 받아 그린다
/// (목록 응답에 본문이 포함되므로 재조회하지 않는다).
class NoticeDetailScreen extends StatefulWidget {
  const NoticeDetailScreen({
    super.key,
    required this.notice,
    this.showListButton = false,
  });

  final Notice notice;

  /// 헤더 우측에 공지 목록 이동 아이콘 표시 여부.
  /// 띠배너처럼 목록을 거치지 않고 진입한 경우에만 켠다
  /// (목록에서 들어왔을 땐 뒤로가기가 곧 목록이라 불필요).
  final bool showListButton;

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 조회수 집계 — 화면 진입 1회. 임시저장은 ADMIN 검수 열람이라 세지 않는다.
    // 응답을 기다리지 않는다(실패해도 화면은 그대로).
    if (!widget.notice.isDraft) {
      NoticeRepository.instance.markViewed(widget.notice.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final showListButton = widget.showListButton;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NarDetailHeader(
              title: l.notice,
              scale: scale,
              trailing: showListButton
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        // 상세를 목록으로 대체 — 목록에서 뒤로가면 원래 화면(캘린더).
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const NoticeScreen(),
                          ),
                        );
                      },
                      // 아이콘 폰트는 릴리즈 트리셰이킹 때문에 shorebird 패치로
                      // 새 글리프를 못 실어서 텍스트 버튼을 쓴다.
                      child: Text(
                        l.noticeListButton,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          fontSize: 14 * scale,
                          height: 1.55,
                          color: AppColors.narTextTertiary,
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20 * scale,
                  8 * scale,
                  20 * scale,
                  40 * scale,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        fontSize: 19 * scale,
                        height: 1.35,
                        color: AppColors.narTextTertiary,
                      ),
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      '${l.noticeAdmin} · '
                      '${notice.isDraft ? l.noticeDraft : DateFormat('yyyy.MM.dd HH:mm').format(notice.publishedAt!)}',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5 * scale,
                        color: AppColors.narText2,
                      ),
                    ),
                    SizedBox(height: 14 * scale),
                    const Divider(color: AppColors.narLine, height: 1),
                    SizedBox(height: 16 * scale),
                    ..._buildContent(notice.content, scale),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 단순 마크다운 렌더링 — `# 제목`, `## 소제목`, `- 리스트`, `![](url)` 이미지,
  /// 인라인 `**굵게**`, 나머지는 문단. 백오피스 에디터가 내보내는 문법 범위와 맞춘다.
  /// 이미지 alt 뒤의 `|px` 는 백오피스에서 리사이즈한 폭 — `![스크린샷|400](url)`.
  // ponytail: 링크·기울임 등 나머지 인라인 문법은 미지원, 필요해지면 마크다운 패키지로 교체.
  static final _imagePattern = RegExp(r'^!\[([^\]]*)\]\((.+)\)$');
  static final _imageWidthPattern = RegExp(r'\|(\d+)$');

  /// 인라인 문법: `**굵게**`, `[텍스트](url)` 링크.
  static final _inlinePattern = RegExp(
    r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)]+)\)',
  );

  /// 인라인 마크다운(`**굵게**`, 링크)을 span 으로 바꾼 Text 를 만든다.
  /// 링크는 탭하면 외부 브라우저로 연다.
  static Widget _inlineText(String text, TextStyle base) {
    if (!text.contains('**') && !text.contains('](')) {
      return Text(text, style: base);
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _inlinePattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        final url = match.group(3)!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                match.group(2)!,
                style: base.copyWith(
                  color: AppColors.narLinkText,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.narLinkText,
                ),
              ),
            ),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(style: base, children: spans));
  }

  List<Widget> _buildContent(String content, double scale) {
    final body = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
      fontSize: 14 * scale,
      height: 1.6,
      color: AppColors.narText3,
    );
    final heading = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w700,
      fontSize: 15 * scale,
      height: 1.5,
      color: AppColors.narTextTertiary,
    );

    final title = TextStyle(
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w700,
      fontSize: 17 * scale,
      height: 1.45,
      color: AppColors.narTextTertiary,
    );

    final widgets = <Widget>[];
    for (final line in content.split('\n')) {
      // 에디터(tiptap-markdown)가 넣는 이스케이프 정리:
      // 단독 '\' 줄은 hard break — 빈 줄 취급, '\~' 같은 이스케이프는 원문자로.
      final trimmed = line.trim() == r'\'
          ? ''
          : line.trim().replaceAllMapped(
              RegExp(r'\\([\\`*_{}\[\]()#+\-.!~<>])'),
              (m) => m.group(1)!,
            );
      final image = _imagePattern.firstMatch(trimmed);
      if (trimmed.isEmpty) {
        widgets.add(SizedBox(height: 10 * scale));
      } else if (image != null) {
        // alt 꼬리의 `|px` → 백오피스에서 지정한 폭 (375 기준 시안 폭에 scale 적용).
        final widthPx = _imageWidthPattern
            .firstMatch(image.group(1)!)
            ?.group(1);
        final width = widthPx != null ? double.parse(widthPx) * scale : null;
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6 * scale),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10 * scale),
                child: CachedNetworkImage(
                  imageUrl: image.group(2)!,
                  width: width ?? double.infinity,
                  fit: BoxFit.fitWidth,
                  // 로드 실패(잘못된 URL 등) 시 빈 공간 대신 조용히 생략.
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 4 * scale, bottom: 2 * scale),
            child: Text(
              trimmed.substring(4),
              style: heading.copyWith(fontSize: 14 * scale, height: 1.55),
            ),
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 4 * scale, bottom: 4 * scale),
            child: Text(trimmed.substring(3), style: heading),
          ),
        );
      } else if (trimmed.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 6 * scale, bottom: 4 * scale),
            child: Text(trimmed.substring(2), style: title),
          ),
        );
      } else if (trimmed.startsWith('- ')) {
        widgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: body),
              Expanded(child: _inlineText(trimmed.substring(2), body)),
            ],
          ),
        );
      } else {
        widgets.add(_inlineText(trimmed, body));
      }
    }
    return widgets;
  }
}
