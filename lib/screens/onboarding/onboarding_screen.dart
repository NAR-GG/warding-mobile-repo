import 'package:flutter/material.dart';

import '../../components/common_button.dart';
import '../../repository/onboarding/onboarding_repository.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/onboarding/onboarding_viewmodel.dart';
import '../home/home_screen.dart';
import 'component/onboarding_header.dart';
import 'component/onboarding_progress_bar.dart';
import 'step/league_step.dart';
import 'step/notification_step.dart';
import 'step/player_step.dart';
import 'step/team_step.dart';

/// 디자인 시안 기준 화면 너비.
const double _designWidth = 375;

/// 진행도 바 점 개수.
const int _progressDotCount = 5;

/// 온보딩 화면 (View).
///
/// 상태·로직은 [OnboardingViewModel] 이 담당하고, 이 위젯은
/// ViewModel 을 구독해 헤더·진행도 바·단계별 본문·하단 버튼을 그린다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  late final OnboardingViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = OnboardingViewModel(
      repository: OnboardingRepository.instance,
      onFinish: _finish,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 알림 설정 화면을 다녀온 경우 권한을 다시 확인한다.
    if (state == AppLifecycleState.resumed) {
      _viewModel.recheckNotificationPermission();
    }
  }

  void _finish() {
    // TODO: 백엔드 온보딩 완료 / 비회원 로컬 저장 처리 후 이동
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  /// 헤더 뒤로가기 — 첫 단계면 화면을 닫는다.
  void _onBack() {
    if (_viewModel.canGoBack) {
      _viewModel.goBack();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / _designWidth;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnboardingHeader(
                  title: _headerTitle(_viewModel.currentStep),
                  onBack: _onBack,
                  onSkip: _viewModel.skip,
                ),
                const SizedBox(height: 4),
                OnboardingProgressBar(
                  totalSteps: _progressDotCount,
                  currentStep: _viewModel.stepIndex,
                ),
                Expanded(child: _buildStep(scale)),
                Padding(
                  padding: EdgeInsets.only(
                    left: 24 * scale,
                    right: 24 * scale,
                    top: 16 * scale,
                    bottom: 32 * scale,
                  ),
                  child: CommonButton(
                    label: _viewModel.isLastStep ? '와딩 시작하기' : '다음',
                    scale: scale,
                    onPressed: _viewModel.canProceed
                        ? _viewModel.goNext
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 현재 단계에 해당하는 본문 View.
  Widget _buildStep(double scale) {
    switch (_viewModel.currentStep) {
      case OnboardingStep.league:
        return LeagueStep(scale: scale);
      case OnboardingStep.team:
        return TeamStep(viewModel: _viewModel, scale: scale);
      case OnboardingStep.player:
        return PlayerStep(scale: scale);
      case OnboardingStep.notification:
        return NotificationStep(viewModel: _viewModel, scale: scale);
    }
  }

  String _headerTitle(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.league:
        return '선호 리그';
      case OnboardingStep.team:
        return '선호 팀';
      case OnboardingStep.player:
        return '선호 선수';
      case OnboardingStep.notification:
        return '알림 권한';
    }
  }
}
