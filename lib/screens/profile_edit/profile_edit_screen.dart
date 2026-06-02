import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/common_button.dart';
import '../../components/nar_detail_header.dart';
import '../../components/nar_input.dart';
import '../../styles/app_colors.dart';
import 'component/cheer_team_section.dart';

/// 프로필 수정 화면.
///
/// 마이페이지 프로필 섹션의 '프로필 수정' 또는 응원팀 안내 배너에서 진입한다.
/// 헤더는 공용 [NarDetailHeader] 로 chevron-left 뒤로가기 + '프로필 수정' 타이틀.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  // TODO: API 연결 후 실제 닉네임으로 초기화 (현재 mock).
  final TextEditingController _nicknameController = TextEditingController();

  /// 닉네임 에러 메시지. null 이면 정상.
  String? _nicknameError;

  // TODO: API 연결 후 실제 구독 팀 목록·로고로 교체 (현재 mock).
  final List<CheerTeam> _teams = const [
    CheerTeam(name: 'T1'),
    CheerTeam(name: 'DN SOOPers'),
    CheerTeam(name: 'Hanwha Life Esports'),
    CheerTeam(name: 'Gen.G'),
    CheerTeam(name: 'KT Rolster'),
    CheerTeam(name: 'Dplus KIA'),
    CheerTeam(name: 'Nongshim RedForce'),
    CheerTeam(name: 'DRX'),
    CheerTeam(name: 'BNK FEARX'),
    CheerTeam(name: 'HANJIN BRLON'),
  ];

  /// 현재 응원(선택) 팀 인덱스. null 이면 미설정.
  int? _cheerTeamIndex;

  /// 사용자가 무언가 변경했는지 여부(변경 없으면 완료 비활성).
  bool _dirty = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  /// 닉네임 유효성 검사. 비어 있으면 에러 메시지를 세팅한다.
  void _validateNickname(String value) {
    setState(() {
      _dirty = true;
      _nicknameError = value.trim().isEmpty ? '필수 입력 항목입니다.' : null;
    });
  }

  /// 응원 팀 선택.
  void _selectTeam(int index) {
    setState(() {
      _dirty = true;
      _cheerTeamIndex = index;
    });
  }

  /// 완료 가능 여부.
  /// 변경사항이 있고 + 닉네임이 유효하고 + 응원 팀이 설정돼 있어야 한다.
  bool get _canSubmit {
    final nickname = _nicknameController.text.trim();
    return _dirty &&
        nickname.isNotEmpty &&
        _nicknameError == null &&
        _cheerTeamIndex != null;
  }

  /// 완료 — 프로필 저장.
  void _onDone() {
    // TODO: API 연결 후 닉네임·응원 팀 저장 요청 후 뒤로가기.
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NarDetailHeader(
                      title: '프로필 수정',
                      backIconAsset: 'assets/icons/chevron-left.svg',
                      scale: scale,
                    ),
                    SizedBox(height: 39 * scale),
                    // 기본 프로필 이미지(113) + 우측 하단 사진 수정 버튼.
                    Center(
                      child: SizedBox(
                        width: 113 * scale,
                        height: 113 * scale,
                        child: Stack(
                          children: [
                            ClipOval(
                              child: Image.asset(
                                'assets/images/person.png',
                                width: 113 * scale,
                                height: 113 * scale,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  // TODO: 프로필 사진 변경(갤러리/카메라) 연결
                                },
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
                      ),
                    ),
                    SizedBox(height: 55 * scale),
                    // 닉네임 입력 박스 (라벨 + 필드, 양옆 20 패딩).
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                      child: NarInput(
                        controller: _nicknameController,
                        label: '닉네임',
                        hintText: '닉네임을 입력하세요',
                        errorText: _nicknameError,
                        onChanged: _validateNickname,
                        scale: scale,
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    // 응원 팀 설정 요약 행 (양옆 20 패딩).
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                      child: CheerTeamSettingRow(
                        selectedTeam:
                            _cheerTeamIndex == null
                                ? null
                                : _teams[_cheerTeamIndex!],
                        scale: scale,
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    // 응원 팀 선택 리스트 (하트 토글, 양옆 20 패딩).
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                      child: CheerTeamList(
                        teams: _teams,
                        selectedIndex: _cheerTeamIndex,
                        onSelect: _selectTeam,
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
                label: '완료',
                variant: CommonButtonVariant.light,
                scale: scale,
                onPressed: _canSubmit ? _onDone : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
