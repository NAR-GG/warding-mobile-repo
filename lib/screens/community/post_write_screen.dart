import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/nar_detail_header.dart';
import '../../l10n/app_localizations.dart';
import '../../model/community_post_block.dart';
import '../../model/community_remote_post.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/community/post_write_viewmodel.dart';
import 'community_rules.dart';
import 'component/community_image.dart';
import 'component/community_rules_sheet.dart';

/// 글쓰기 — 제목 + **블록 에디터**(텍스트 사이에 사진·링크·임베드를 끼워 넣는
/// 샌드위치 구성). 본문은 bodyFormat=BLOCKS 로 나간다.
///
/// - 사진/링크는 포커스된 텍스트 블록의 커서 위치에서 텍스트를 쪼개 끼운다
///   (포커스가 없으면 맨 끝). 미디어 블록은 ✕ 삭제, ▲▼ 이동.
/// - URL 이 유튜브·치지직·SOOP·X 면 임베드 블록, 아니면 서버 link-preview 를
///   불러 링크 카드 블록이 된다.
/// - 서식 v1 은 텍스트 블록별 heading 토글 하나다.
///
/// 본문 아래에는 커뮤니티 이용규칙 요약이 연하게 깔린다. 글을 쓰기 직전이
/// 규칙을 읽을 유일한 순간이라, 별도 화면으로 빼면 아무도 안 본다.
///
/// 등록에 성공하면 새 글 id 를 결과로 pop 한다. 수정 모드([edit])면 같은 id 를 pop 한다.
class PostWriteScreen extends StatefulWidget {
  const PostWriteScreen({super.key, required this.boardTeamId, this.edit});

  /// null 이면 전체 게시판(현재는 항상 null — 단일 게시판).
  final int? boardTeamId;

  /// 수정할 글. null 이면 새 글 작성이다. PLAIN 글은 텍스트 블록 하나로 열리고
  /// 수정 등록 시 BLOCKS 로 저장된다(서버 하위호환 유지, 본문 내용은 동일).
  final CommunityRemotePostDetail? edit;

  @override
  State<PostWriteScreen> createState() => _PostWriteScreenState();
}

/// 에디터 블록. 텍스트는 입력 상태(controller·focus)를 들고, 미디어는
/// [DraftBlock] 그대로 든다.
sealed class _EditorBlock {}

class _TextBlock extends _EditorBlock {
  _TextBlock({String text = '', this.heading = false})
    : controller = TextEditingController(text: text);

  final TextEditingController controller;
  final FocusNode focus = FocusNode();
  bool heading = false;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _MediaBlock extends _EditorBlock {
  _MediaBlock(this.draft);

  final DraftBlock draft;
}

class _PostWriteScreenState extends State<PostWriteScreen> {
  late final PostWriteViewModel _vm = PostWriteViewModel(
    boardTeamId: widget.boardTeamId,
    editPostId: widget.edit?.id,
  );

  final TextEditingController _title = TextEditingController();
  final List<_EditorBlock> _blocks = [];

  /// 투표 컴포저(글당 1개, 작성 시에만 — 수정 모드에선 버튼 자체를 숨긴다).
  bool _pollEnabled = false;
  final TextEditingController _pollQuestion = TextEditingController();
  final List<TextEditingController> _pollOptions = [];
  static const int _maxPollOptions = 4;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    if (edit == null) {
      _blocks.add(_TextBlock());
    } else {
      _title.text = edit.title;
      _initFromEdit(edit);
    }
    _title.addListener(_onChanged);
    _vm.addListener(_showError);
  }

  void _initFromEdit(CommunityRemotePostDetail edit) {
    if (!edit.isBlocks) {
      // PLAIN 글: 본문 전체를 텍스트 블록 하나로, 기존 첨부는 이미지 블록으로.
      _blocks.add(_TextBlock(text: edit.body));
      for (final img in edit.images) {
        _blocks.add(_MediaBlock(DraftBlock.image(url: img.url)));
      }
      return;
    }
    for (final b in CommunityPostBlock.parseList(edit.body)) {
      switch (b.type) {
        case 'text':
          _blocks.add(_TextBlock(text: b.text ?? '', heading: b.isHeading));
        case 'image':
          if (b.url != null) _blocks.add(_MediaBlock(DraftBlock.image(url: b.url)));
        case 'link':
          _blocks.add(_MediaBlock(DraftBlock.link(
            url: b.url ?? '',
            title: b.title,
            description: b.description,
            imageUrl: b.imageUrl,
            siteName: b.siteName,
          )));
        case 'embed':
          _blocks.add(_MediaBlock(
            DraftBlock.embed(provider: b.provider ?? '', url: b.url ?? ''),
          ));
      }
    }
    // 이미지로 시작하는 글(예: 사진만 올린 글)을 수정할 때도 위에 커서 자리가
    // 있어야 한다 — 삽입·이동과 같은 불변식.
    _ensureTextEdges();
  }

  @override
  void dispose() {
    _vm.removeListener(_showError);
    _title.dispose();
    _pollQuestion.dispose();
    for (final option in _pollOptions) {
      option.dispose();
    }
    for (final block in _blocks) {
      if (block is _TextBlock) block.dispose();
    }
    _vm.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _showError() {
    final message = _vm.error;
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _hasContent => _blocks.any(
    (b) =>
        b is _MediaBlock ||
        (b is _TextBlock && b.controller.text.trim().isNotEmpty),
  );

  /// 투표를 켰으면 질문과 선택지 2개 이상이 차야 등록이 열린다.
  bool get _pollValid =>
      !_pollEnabled ||
      (_pollQuestion.text.trim().isNotEmpty &&
          _pollOptions.where((o) => o.text.trim().isNotEmpty).length >= 2);

  /// 투표만 있는 글도 허용한다 — 질문이 곧 내용이다.
  bool get _submittable =>
      _title.text.trim().isNotEmpty &&
      (_hasContent || _pollEnabled) &&
      _pollValid &&
      !_vm.submitting;

  void _togglePoll() {
    setState(() {
      _pollEnabled = !_pollEnabled;
      if (_pollEnabled && _pollOptions.isEmpty) {
        _pollOptions.addAll([TextEditingController(), TextEditingController()]);
      }
    });
  }

  int get _imageCount => _blocks
      .whereType<_MediaBlock>()
      .where((b) => b.draft.type == 'image')
      .length;

  _TextBlock? get _focusedText {
    for (final block in _blocks) {
      if (block is _TextBlock && block.focus.hasFocus) return block;
    }
    return null;
  }

  /// 블록 배열 불변식 — **맨 위와 맨 아래는 항상 텍스트 블록**이어야 한다.
  /// 이미지가 첫 블록이 되면 그 위에 커서를 둘 자리가 없어 "사진 위에
  /// 첫 줄 쓰기"가 불가능해진다(1.0.23 피드백). 삽입·이동·삭제 후마다 부른다.
  void _ensureTextEdges() {
    if (_blocks.isEmpty || _blocks.first is! _TextBlock) {
      _blocks.insert(0, _TextBlock());
    }
    if (_blocks.last is! _TextBlock) {
      _blocks.add(_TextBlock());
    }
  }

  /// 미디어 블록들을 포커스된 텍스트 블록의 커서에서 텍스트를 쪼개 끼운다.
  /// 포커스가 없으면 맨 끝. 항상 이어서 쓸 텍스트 블록이 뒤따르게 한다.
  void _insertMedia(List<_MediaBlock> media) {
    if (media.isEmpty) return;
    setState(() {
      final focused = _focusedText;
      if (focused == null) {
        if (_blocks.isNotEmpty &&
            _blocks.last is _TextBlock &&
            (_blocks.last as _TextBlock).controller.text.trim().isEmpty) {
          // 끝의 빈 텍스트 블록 앞에 끼워 커서 자리를 보존한다.
          _blocks.insertAll(_blocks.length - 1, media);
        } else {
          _blocks.addAll(media);
          _blocks.add(_TextBlock());
        }
        _ensureTextEdges();
        return;
      }
      final index = _blocks.indexOf(focused);
      final text = focused.controller.text;
      final cursor = focused.controller.selection.isValid
          ? focused.controller.selection.start
          : text.length;
      // 커서 주변의 빈 줄은 걷어낸다 — "글 쓰고 엔터 → 사진"이 이미지 위아래
      // 공백 줄로 남으면 안 된다(블록 간격이 이미 여백을 준다).
      final before = text.substring(0, cursor).trimRight();
      final after = text.substring(cursor).trimLeft();
      focused.controller.text = before;
      final tail = _TextBlock(text: after, heading: false);
      _blocks.insertAll(index + 1, [...media, tail]);
      _ensureTextEdges();
      tail.focus.requestFocus();
    });
  }

  Future<void> _pickPhotos() async {
    final remaining = PostWriteViewModel.maxPhotos - _imageCount;
    final paths = await _vm.pickPhotosForBlocks(remaining);
    if (paths.isEmpty || !mounted) return;
    _insertMedia([
      for (final path in paths) _MediaBlock(DraftBlock.image(localPath: path)),
    ]);
  }

  Future<void> _addLink() async {
    final l = AppLocalizations.of(context)!;
    final input = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.narDark600,
        title: Text(
          l.communityLinkDialogTitle,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.narText,
          ),
        ),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            color: AppColors.narText,
          ),
          cursorColor: AppColors.narViolet3,
          decoration: InputDecoration(
            hintText: l.communityLinkHint,
            hintStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.narDark300,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.cancel,
                style: const TextStyle(color: AppColors.narText2)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(input.text.trim()),
            child: Text(l.communityLinkConfirm,
                style: const TextStyle(color: AppColors.narViolet3)),
          ),
        ],
      ),
    );
    input.dispose();
    if (url == null || url.isEmpty || !mounted) return;

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.communityLinkInvalid)));
      return;
    }
    final provider = CommunityPostBlock.embedProviderOf(url);
    if (provider != null) {
      _insertMedia([_MediaBlock(DraftBlock.embed(provider: provider, url: url))]);
      return;
    }
    // 일반 링크 — 서버 OG 스냅샷을 붙인 카드. 실패해도 맨 링크 카드로 들어간다.
    final preview = await _vm.fetchLinkPreview(url);
    if (!mounted) return;
    _insertMedia([
      _MediaBlock(DraftBlock.link(
        url: url,
        title: preview.title,
        description: preview.description,
        imageUrl: preview.imageUrl,
        siteName: preview.siteName,
      )),
    ]);
  }

  void _removeBlock(_MediaBlock block) {
    setState(() {
      final index = _blocks.indexOf(block);
      _blocks.remove(block);
      // 미디어를 지워 텍스트 블록이 연달아 남으면 하나로 합친다 — 안 그러면
      // 보이지 않는 경계가 남아 커서가 두 자리를 오간다.
      if (index > 0 &&
          index < _blocks.length &&
          _blocks[index - 1] is _TextBlock &&
          _blocks[index] is _TextBlock) {
        final head = _blocks[index - 1] as _TextBlock;
        final tail = _blocks[index] as _TextBlock;
        final joined = [head.controller.text, tail.controller.text]
            .where((t) => t.isNotEmpty)
            .join('\n');
        head.controller.text = joined;
        _blocks.removeAt(index);
        tail.dispose();
      }
      _ensureTextEdges();
    });
  }

  void _moveBlock(_MediaBlock block, int delta) {
    setState(() {
      final index = _blocks.indexOf(block);
      final target = index + delta;
      if (index < 0 || target < 0 || target >= _blocks.length) return;
      _blocks.removeAt(index);
      _blocks.insert(target, block);
      // 미디어가 맨 위/아래로 가면 커서 둘 텍스트 자리를 만들어 준다.
      _ensureTextEdges();
    });
  }

  Future<void> _submit() async {
    final drafts = <DraftBlock>[
      for (final block in _blocks)
        if (block is _TextBlock)
          DraftBlock.text(block.controller.text, heading: block.heading)
        else if (block is _MediaBlock)
          block.draft,
    ];
    final id = await _vm.submitBlocks(
      title: _title.text,
      blocks: drafts,
      poll: _pollEnabled
          ? (
              question: _pollQuestion.text.trim(),
              options: [
                for (final option in _pollOptions)
                  if (option.text.trim().isNotEmpty) option.text.trim(),
              ],
            )
          : null,
    );
    if (id == null || !mounted) return;
    Navigator.of(context).pop<int>(id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => Column(
            children: [
              NarDetailHeader(
                title: l.communityBoardAll,
                scale: scale,
                trailing: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _submittable ? _submit : null,
                  // NarDetailHeader 의 슬롯 높이가 34*scale 이라 세로 패딩을
                  // 주면 글자가 위아래로 잘린다. 좌우로만 넓혀 탭 영역을
                  // 확보한다.
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                    child: Text(
                      _vm.submitting
                          ? l.communityWriteSubmitting
                          : l.communityWriteSubmit,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        fontSize: 14 * scale,
                        height: 1.45,
                        color: _submittable
                            ? AppColors.narViolet3
                            : AppColors.narDark300,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    20 * scale,
                    10 * scale,
                    20 * scale,
                    20 * scale,
                  ),
                  children: [
                    TextField(
                      controller: _title,
                      maxLength: 100,
                      style: _inputStyle(scale, 16, weight: FontWeight.w700),
                      cursorColor: AppColors.narViolet3,
                      decoration: _underlined(
                        l.communityWriteTitleHint,
                        scale,
                        16,
                        weight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 14 * scale),
                    for (final block in _blocks) _blockWidget(l, scale, block),
                    if (_pollEnabled) ...[
                      SizedBox(height: 12 * scale),
                      _pollComposer(l, scale),
                    ],
                    SizedBox(height: 24 * scale),
                    _rules(l, scale),
                  ],
                ),
              ),
              _toolbar(l, scale),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blockWidget(AppLocalizations l, double scale, _EditorBlock block) {
    if (block is _TextBlock) {
      final first = _blocks.isNotEmpty && identical(_blocks.first, block);
      return TextField(
        controller: block.controller,
        focusNode: block.focus,
        // 4줄 예약은 블록이 하나뿐인 빈 화면용(placeholder 자리) — 미디어를
        // 끼운 뒤에도 유지하면 짧은 문단 밑에 빈 3줄이 공백으로 남는다.
        minLines: first && _blocks.length == 1 ? 4 : 1,
        maxLines: null,
        onChanged: (_) => _onChanged(),
        onTap: _onChanged, // 포커스 이동 시 heading 토글 활성 상태 갱신
        style: _inputStyle(
          scale,
          block.heading ? 16 : 14,
          weight: block.heading ? FontWeight.w700 : FontWeight.w400,
        ),
        cursorColor: AppColors.narViolet3,
        decoration: InputDecoration(
          // 안내 문구는 본문이 완전히 빈 상태에서만 — 사진·링크·투표 등 내용이
          // 하나라도 생기면 걷는다. 안 그러면 빈 첫 블록에 안내가 남아
          // 콘텐츠 사이에 떠 있는 문장처럼 보인다.
          hintText:
              first && !_hasContent && !_pollEnabled
                  ? l.communityWriteBodyHint
                  : null,
          hintStyle: _inputStyle(
            scale,
            14,
          ).copyWith(color: AppColors.narDark300),
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 4 * scale),
        ),
      );
    }
    final media = block as _MediaBlock;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * scale),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _mediaPreview(scale, media.draft),
          Positioned(
            top: 6 * scale,
            right: 6 * scale,
            child: Row(
              children: [
                _mediaAction(
                  scale,
                  icon: Icons.keyboard_arrow_up,
                  onTap: () => _moveBlock(media, -1),
                ),
                SizedBox(width: 5 * scale),
                _mediaAction(
                  scale,
                  icon: Icons.keyboard_arrow_down,
                  onTap: () => _moveBlock(media, 1),
                ),
                SizedBox(width: 5 * scale),
                _mediaAction(
                  scale,
                  icon: Icons.close,
                  onTap: () => _removeBlock(media),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaAction(
    double scale, {
    required IconData icon,
    required VoidCallback onTap,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 26 * scale,
      height: 26 * scale,
      decoration: BoxDecoration(
        color: AppColors.narDark800.withValues(alpha: 0.75),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16 * scale, color: AppColors.narText),
    ),
  );

  Widget _mediaPreview(double scale, DraftBlock draft) {
    switch (draft.type) {
      case 'image':
        final radius = BorderRadius.circular(10 * scale);
        if (draft.localPath != null) {
          return ClipRRect(
            borderRadius: radius,
            child: Image.file(
              File(draft.localPath!),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: double.infinity,
                height: 160 * scale,
                color: AppColors.narDark500,
              ),
            ),
          );
        }
        return CommunityImage(
          source: draft.url ?? '',
          width: double.infinity,
          height: null,
          maxHeight: 320 * scale,
          radius: 10 * scale,
        );
      case 'embed':
        final videoId = draft.provider == 'youtube'
            ? CommunityPostBlock.youtubeVideoId(draft.url ?? '')
            : null;
        return _card(
          scale,
          image: videoId == null
              ? null
              : CommunityImage(
                  source: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                  width: double.infinity,
                  height: 160 * scale,
                ),
          title: switch (draft.provider) {
            'youtube' => 'YouTube',
            'chzzk' => '치지직',
            'soop' => 'SOOP',
            'x' => 'X',
            _ => draft.provider ?? '',
          },
          subtitle: draft.url ?? '',
        );
      default: // link
        return _card(
          scale,
          image: draft.imageUrl == null
              ? null
              : CommunityImage(
                  source: draft.imageUrl!,
                  width: double.infinity,
                  height: 140 * scale,
                ),
          title: (draft.title == null || draft.title!.isEmpty)
              ? (draft.url ?? '')
              : draft.title!,
          subtitle: draft.siteName ??
              (Uri.tryParse(draft.url ?? '')?.host ?? ''),
        );
    }
  }

  Widget _card(
    double scale, {
    Widget? image,
    required String title,
    required String subtitle,
  }) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.narDark600,
      borderRadius: BorderRadius.circular(10 * scale),
      border: Border.all(color: AppColors.narLine2, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image != null) image,
        Padding(
          padding: EdgeInsets.all(12 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 13 * scale,
                  height: 1.45,
                  color: AppColors.narText,
                ),
              ),
              SizedBox(height: 3 * scale),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  fontSize: 11 * scale,
                  height: 1.4,
                  color: AppColors.narText2,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// 투표 컴포저 — 질문 + 선택지 2~4개. 우측 상단 ✕로 통째로 제거.
  Widget _pollComposer(AppLocalizations l, double scale) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine2, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_outlined,
                  size: 15 * scale, color: AppColors.narViolet3),
              SizedBox(width: 5 * scale),
              Expanded(
                child: Text(
                  l.communityPollLabel,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 13 * scale,
                    height: 1.45,
                    color: AppColors.narText,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePoll,
                child: Icon(Icons.close,
                    size: 16 * scale, color: AppColors.narText2),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          TextField(
            controller: _pollQuestion,
            maxLength: 100,
            onChanged: (_) => _onChanged(),
            style: _inputStyle(scale, 13.5, weight: FontWeight.w600),
            cursorColor: AppColors.narViolet3,
            decoration: _pollFieldDecoration(l.communityPollQuestionHint, scale),
          ),
          SizedBox(height: 8 * scale),
          for (var i = 0; i < _pollOptions.length; i++) ...[
            if (i > 0) SizedBox(height: 6 * scale),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pollOptions[i],
                    maxLength: 50,
                    onChanged: (_) => _onChanged(),
                    style: _inputStyle(scale, 13),
                    cursorColor: AppColors.narViolet3,
                    decoration: _pollFieldDecoration(
                        '${l.communityPollOptionHint} ${i + 1}', scale),
                  ),
                ),
                if (_pollOptions.length > 2)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _pollOptions.removeAt(i).dispose();
                    }),
                    child: Padding(
                      padding: EdgeInsets.only(left: 8 * scale),
                      child: Icon(Icons.remove_circle_outline,
                          size: 17 * scale, color: AppColors.narText2),
                    ),
                  ),
              ],
            ),
          ],
          if (_pollOptions.length < _maxPollOptions) ...[
            SizedBox(height: 8 * scale),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => _pollOptions.add(TextEditingController())),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add,
                      size: 15 * scale, color: AppColors.narViolet3),
                  SizedBox(width: 4 * scale),
                  Text(
                    l.communityPollAddOption,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5 * scale,
                      height: 1.4,
                      color: AppColors.narViolet3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _pollFieldDecoration(String hint, double scale) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            _inputStyle(scale, 13).copyWith(color: AppColors.narDark300),
        isDense: true,
        counterText: '',
        filled: true,
        fillColor: AppColors.narDark500,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: 9 * scale,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9 * scale),
          borderSide: BorderSide.none,
        ),
      );

  /// 규칙 요약 + 전문 보기. 본문 아래에 연하게 깔아 방해하지 않되, 스크롤하면
  /// 반드시 지나가도록 둔다.
  Widget _rules(AppLocalizations l, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showCommunityRulesSheet(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 9 * scale,
            ),
            decoration: BoxDecoration(
              color: AppColors.narDark600,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.communityRulesSeeAll,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 12 * scale,
                    height: 1.45,
                    color: AppColors.narText3,
                  ),
                ),
                SizedBox(width: 4 * scale),
                Icon(
                  Icons.chevron_right,
                  size: 15 * scale,
                  color: AppColors.narText3,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12 * scale),
        Text(
          kCommunityRulesSummary.trim(),
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 12 * scale,
            height: 1.7,
            color: AppColors.narDark300,
          ),
        ),
      ],
    );
  }

  Widget _toolbar(AppLocalizations l, double scale) {
    final count = _imageCount;
    final full = count >= PostWriteViewModel.maxPhotos;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 10 * scale,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.narLine, width: 1)),
      ),
      child: Row(
        children: [
          _ToolButton(
            asset: 'assets/icons/photo-edit.svg',
            label: count == 0
                ? l.communityAttachPhoto
                : l.communityPhotoCount(count),
            active: count > 0,
            scale: scale,
            onTap: full ? null : _pickPhotos,
          ),
          SizedBox(width: 8 * scale),
          _ToolButton(
            icon: Icons.link,
            label: l.communityAddLink,
            active: false,
            scale: scale,
            onTap: _addLink,
          ),
          // 투표는 작성 시에만 붙는다(서버 계약) — 수정 모드에선 숨긴다.
          if (widget.edit == null) ...[
            SizedBox(width: 8 * scale),
            _ToolButton(
              icon: Icons.poll_outlined,
              label: l.communityPollLabel,
              active: _pollEnabled,
              scale: scale,
              onTap: _togglePoll,
            ),
          ],
        ],
      ),
    );
  }

  TextStyle _inputStyle(
    double scale,
    double size, {
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: 'Pretendard',
    fontWeight: weight,
    fontSize: size * scale,
    height: 1.55,
    color: AppColors.narText,
  );

  InputDecoration _underlined(
    String hint,
    double scale,
    double size, {
    FontWeight weight = FontWeight.w400,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: _inputStyle(
      scale,
      size,
      weight: weight,
    ).copyWith(color: AppColors.narDark300),
    isDense: true,
    counterText: '',
    contentPadding: EdgeInsets.symmetric(vertical: 10 * scale),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.narLine2, width: 1),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.narChipActive, width: 1),
    ),
  );
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    this.asset,
    this.icon,
    required this.label,
    required this.active,
    required this.scale,
    required this.onTap,
  });

  final String? asset;
  final IconData? icon;
  final String label;
  final bool active;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? AppColors.narDark300
        : active
        ? AppColors.narViolet3
        : AppColors.narText3;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 38 * scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.narChipBadgeBg : null,
            borderRadius: BorderRadius.circular(9 * scale),
            border: Border.all(
              color: active ? AppColors.narChipActive : AppColors.narLine2,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (asset != null)
                SvgPicture.asset(
                  asset!,
                  width: 15 * scale,
                  height: 15 * scale,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                )
              else
                Icon(icon, size: 16 * scale, color: color),
              SizedBox(width: 6 * scale),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5 * scale,
                  height: 1.45,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
