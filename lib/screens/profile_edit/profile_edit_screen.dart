import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/common_button.dart';
import '../../components/nar_detail_header.dart';
import '../../components/nar_input.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/profile_edit/profile_edit_viewmodel.dart';
import 'component/cheer_team_section.dart';

/// 프로필 수정 화면.
///
/// 마이페이지 프로필 섹션의 '프로필 수정' 또는 응원팀 안내 배너에서 진입한다.
/// 헤더는 공용 [NarDetailHeader] 로 chevron-left 뒤로가기 + '프로필 수정' 타이틀.
/// 저장 성공 시 pop 결과로 `true` 를 반환해 호출자가 새로고침할 수 있게 한다.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final ProfileEditViewModel _viewModel = ProfileEditViewModel();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  /// 초기 이름·태그를 컨트롤러에 단 1회만 채우기 위한 가드.
  bool _initializedFields = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_syncFieldsOnce);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_syncFieldsOnce);
    _nameController.dispose();
    _tagController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// 프로필이 로드되면 이름·태그 컨트롤러를 채운다(이후 사용자 입력 보호).
  void _syncFieldsOnce() {
    if (_initializedFields) return;
    final profile = _viewModel.profile;
    if (profile == null) return;
    _nameController.text = profile.name;
    _tagController.text = profile.tag;
    _initializedFields = true;
  }

  Future<void> _onDone() async {
    final ok = await _viewModel.save();
    if (!ok || !mounted) return;
    Navigator.of(context).pop(true);
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
          listenable: _viewModel,
          builder: (context, _) {
            // API 팀 → 컴포넌트용 CheerTeam.
            final cheerTeams = [
              for (final t in _viewModel.teams)
                CheerTeam(name: t.name, imageUrl: t.imageUrl),
            ];
            // favoriteTeamId → 리스트 인덱스 매핑.
            int? selectedIndex;
            final favId = _viewModel.favoriteTeamId;
            if (favId != null) {
              final idx = _viewModel.teams.indexWhere((t) => t.id == favId);
              if (idx >= 0) selectedIndex = idx;
            }

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NarDetailHeader(
                          title: l.profileEditTitle,
                          backIconAsset: 'assets/icons/chevron-left.svg',
                          scale: scale,
                        ),
                        SizedBox(height: 39 * scale),
                        Center(
                          child: _ProfileAvatar(
                            scale: scale,
                            imageUrl: _viewModel.profile?.profileImageUrl,
                            localPath: _viewModel.pendingImagePath,
                            onEditTap: _viewModel.pickProfileImage,
                          ),
                        ),
                        SizedBox(height: 55 * scale),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20 * scale,
                          ),
                          // 닉네임 = 이름 + 태그(영문/숫자 2~5자) 분리 입력.
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: NarInput(
                                  controller: _nameController,
                                  label: l.nameLabel,
                                  hintText: l.nameHint,
                                  errorText: _viewModel.nameError,
                                  onChanged: _viewModel.updateName,
                                  scale: scale,
                                ),
                              ),
                              SizedBox(width: 12 * scale),
                              SizedBox(
                                width: 120 * scale,
                                child: NarInput(
                                  controller: _tagController,
                                  label: l.tagLabel,
                                  hintText: l.tagHint,
                                  errorText: _viewModel.tagError,
                                  onChanged: _viewModel.updateTag,
                                  scale: scale,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20 * scale,
                          ),
                          child: CheerTeamSettingRow(
                            selectedTeam: selectedIndex == null
                                ? null
                                : cheerTeams[selectedIndex],
                            scale: scale,
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20 * scale,
                          ),
                          child: CheerTeamList(
                            teams: cheerTeams,
                            selectedIndex: selectedIndex,
                            onSelect: (i) =>
                                _viewModel.selectTeam(_viewModel.teams[i].id),
                            scale: scale,
                          ),
                        ),
                        SizedBox(height: 40 * scale),
                      ],
                    ),
                  ),
                ),
                // 하단 완료 버튼 (온보딩과 동일 — 좌우 24, 하단 32).
                Padding(
                  padding: EdgeInsets.only(
                    left: 24 * scale,
                    right: 24 * scale,
                    top: 16 * scale,
                    bottom: 32 * scale,
                  ),
                  child: CommonButton(
                    label: l.done,
                    variant: CommonButtonVariant.light,
                    scale: scale,
                    onPressed: _viewModel.canSubmit ? _onDone : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 프로필 이미지(113) + 우측 하단 사진 수정 버튼.
///
/// 우선순위: [localPath] (갤러리에서 방금 고른 파일) > [imageUrl] > placeholder.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.scale,
    this.imageUrl,
    this.localPath,
    this.onEditTap,
  });

  final double scale;
  final String? imageUrl;
  final String? localPath;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    final size = 113 * scale;
    final fallback = Image.asset(
      'assets/images/person.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    final Widget avatar;
    if (localPath != null && localPath!.isNotEmpty) {
      avatar = Image.file(
        File(localPath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        errorWidget: (_, _, _) => fallback,
      );
    } else {
      avatar = fallback;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipOval(child: avatar),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEditTap,
              child: Container(
                width: 35 * scale,
                height: 35 * scale,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.narGray100,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/icons/photo-edit.svg',
                  width: 20 * scale,
                  height: 20 * scale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
