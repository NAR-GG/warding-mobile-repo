package com.warding.app

import io.flutter.embedding.android.FlutterFragmentActivity

// flutter_naver_login 이 Activity 를 FlutterFragmentActivity 로 캐스팅하므로
// FlutterActivity 를 쓰면 플러그인 등록이 실패한다(네이버 로그인 전체 불능).
class MainActivity : FlutterFragmentActivity()
