import 'package:flutter/material.dart';

import '../schedule/schedule_screen.dart';

/// 경기 리스트 화면 — 지금은 경기일정 화면 그 자체다.
///
/// 예전에는 하단 네비의 독립 탭이었다. 캘린더와 리스트를 한 화면에 세로로
/// 합치면서([ScheduleScreen]) 하단 네비에서 '경기리스트' 탭을 뺐고, 리스트는
/// 그 화면의 아래 절반이 됐다.
///
/// 클래스를 지우지 않고 남겨 둔 이유: 홈 '전체 대진' 처럼 "경기 목록을 보여
/// 달라"는 진입 경로가 여럿 있고, 그쪽에서 일일이 경기일정 화면으로 고쳐
/// 부르게 할 이유가 없다.
class MatchListScreen extends StatelessWidget {
  const MatchListScreen({super.key});

  @override
  Widget build(BuildContext context) => const ScheduleScreen();
}
