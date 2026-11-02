#!/usr/bin/env bash
# patch-deploy.yml 의 가드 로직 회귀 테스트.
#
# 패치는 스토어 심사를 거치지 않고 사용자에게 바로 간다. 그래서 "나가면 안 되는
# 것이 나가는 일"을 파이프라인이 막아야 하는데, 워크플로우는 태그를 밀어 봐야
# 돌아서 가드가 실제로 거르는지 확인하기 어렵다. 가드와 **같은 로직**을 여기서
# 돌려 기대값을 박아 둔다.
#
# 특히 네이티브·에셋 차단은 조용히 실패하는 종류다 — 통과시키면 패치는 성공한
# 것처럼 나가고, 그 코드를 기대하는 Dart 가 사용자 기기에서 깨진다.
#
# 실행: .github/workflows/patch-deploy-test.sh
set -euo pipefail

cd "$(dirname "$0")/../.."

fail=0
check() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $label"
  else
    echo "  🔴 $label — 기대: $expected / 실제: $actual"
    fail=1
  fi
}

# ── 태그 파싱 (patch/<릴리즈 버전>/<번호>) ─────────────────────────────────
# workflow 의 'parse' 스텝과 같은 로직.
parse_tag() {
  local ref_name="$1"
  local ref release_version patch_number
  ref="${ref_name#patch/}"
  release_version="${ref%/*}"
  patch_number="${ref##*/}"

  if [ "$release_version" = "$ref" ] || [ -z "$patch_number" ]; then
    echo "INVALID_FORMAT"
    return
  fi
  if ! printf '%s' "$patch_number" | grep -qE '^[0-9]+$'; then
    echo "INVALID_NUMBER"
    return
  fi
  if ! printf '%s' "$release_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$'; then
    echo "INVALID_VERSION"
    return
  fi
  echo "$release_version|$patch_number"
}

echo "태그 파싱"
check "정상 태그" "1.0.42+92|1" "$(parse_tag 'patch/1.0.42+92/1')"
check "두 자리 패치 번호" "1.0.42+92|12" "$(parse_tag 'patch/1.0.42+92/12')"
check "구버전 릴리즈 패치" "1.0.33+73|5" "$(parse_tag 'patch/1.0.33+73/5')"
# 번호를 빼먹으면 release_version 이 통째로 들어와 엉뚱한 릴리즈를 패치하게 된다.
check "번호 누락" "INVALID_FORMAT" "$(parse_tag 'patch/1.0.42+92')"
check "번호가 숫자가 아님" "INVALID_NUMBER" "$(parse_tag 'patch/1.0.42+92/v1')"
# 빌드 번호(+92)가 없으면 shorebird 가 릴리즈를 못 찾는다.
check "빌드 번호 누락" "INVALID_VERSION" "$(parse_tag 'patch/1.0.42/1')"
check "버전 형식 깨짐" "INVALID_VERSION" "$(parse_tag 'patch/1.0+92/1')"

# ── 패치로 나갈 수 없는 변경 차단 ──────────────────────────────────────────
# workflow 의 '패치로 나갈 수 없는 변경이 섞였는지 확인' 스텝과 같은 패턴.
blocked_paths() {
  grep -E '^(ios/|android/|assets/|macos/|windows/|linux/)' || true
}

echo
echo "네이티브·에셋 변경 차단"
check "Dart 만 바뀌면 통과" "" \
  "$(printf 'lib/screens/home/home_screen.dart\nlib/util/update_prompt.dart\ntest/util/x_test.dart\n' | blocked_paths)"
check "iOS 네이티브 차단" "ios/Runner/Info.plist" \
  "$(printf 'lib/a.dart\nios/Runner/Info.plist\n' | blocked_paths)"
check "Android 네이티브 차단" "android/app/build.gradle.kts" \
  "$(printf 'android/app/build.gradle.kts\nlib/a.dart\n' | blocked_paths)"
# 에셋은 패치에 안 실린다 — 티어 엠블럼처럼 이미지를 추가한 변경이 해당.
check "에셋 추가 차단" "assets/images/tier.png" \
  "$(printf 'assets/images/tier.png\nlib/a.dart\n' | blocked_paths)"
# iOS 홈 위젯 extension 도 네이티브 타깃이다.
check "홈 위젯 extension 차단" "ios/WardingScheduleWidget/Info.plist" \
  "$(printf 'ios/WardingScheduleWidget/Info.plist\n' | blocked_paths)"
# 'lib/' 안에 ios 라는 글자가 들어가도 걸리면 안 된다(앵커가 ^ 여야 한다).
check "경로 중간의 ios 는 통과" "" \
  "$(printf 'lib/util/ios_helper.dart\nlib/screens/android_tip.dart\n' | blocked_paths)"

# ── pubspec 의존성 변경 감지 ───────────────────────────────────────────────
# version 줄만 바뀐 건 통과, dependencies 가 바뀌면 걸린다.
dep_changes() {
  grep -E '^[+-][[:space:]]+[a-z_0-9]+:' || true
}

echo
echo "pubspec 의존성 감지"
check "version 줄만 바뀌면 통과" "" \
  "$(printf -- '--- a/pubspec.yaml\n+++ b/pubspec.yaml\n-version: 1.0.42+92\n+version: 1.0.43+93\n' | dep_changes)"
check "의존성 추가는 걸린다" "+  sentry_flutter: ^8.0.0" \
  "$(printf -- '--- a/pubspec.yaml\n+++ b/pubspec.yaml\n+  sentry_flutter: ^8.0.0\n' | dep_changes)"
check "의존성 버전 변경도 걸린다" "$(printf -- '-  upgrader: ^11.0.0\n+  upgrader: ^12.0.0')" \
  "$(printf -- '-  upgrader: ^11.0.0\n+  upgrader: ^12.0.0\n' | dep_changes)"

# ── 실제 워크플로우 파일 정합성 ────────────────────────────────────────────
echo
echo "워크플로우 파일"
WF=.github/workflows/patch-deploy.yml
check "patch 태그로 트리거된다" "yes" \
  "$(grep -q "tags: \['patch/\*'\]" "$WF" && echo yes || echo no)"
# 릴리즈는 e2e 와 빌드를 병렬로 돌리지만, 패치는 올리면 바로 사용자에게 가므로
# e2e 통과를 기다려야 한다.
check "패치 잡이 e2e 를 기다린다 (iOS)" "yes" \
  "$(python3 -c "
import yaml; d=yaml.safe_load(open('$WF'))
print('yes' if 'e2e' in (d['jobs']['patch-ios'].get('needs') or []) else 'no')")"
check "패치 잡이 e2e 를 기다린다 (Android)" "yes" \
  "$(python3 -c "
import yaml; d=yaml.safe_load(open('$WF'))
print('yes' if 'e2e' in (d['jobs']['patch-android'].get('needs') or []) else 'no')")"
# CI 에 사람이 없다 — 확인 프롬프트에서 멈추면 잡이 타임아웃까지 매달린다.
# 주석이 아니라 액션에 실제로 넘어가는 args 를 본다.
check "두 플랫폼 모두 --no-confirm 을 넘긴다" "ios:yes android:yes" \
  "$(python3 -c "
import yaml; d=yaml.safe_load(open('$WF'))
out=[]
for plat, job in (('ios','patch-ios'), ('android','patch-android')):
    args=''
    for st in d['jobs'][job]['steps']:
        if 'shorebird-patch' in str(st.get('uses','')):
            args=str((st.get('with') or {}).get('args',''))
    out.append(f'{plat}:' + ('yes' if '--no-confirm' in args else 'no'))
print(' '.join(out))")"
# 패치는 릴리즈를 뽑을 때 쓴 Flutter 와 같은 버전으로 만들어야 붙는다.
check "shorebird Flutter 버전이 릴리즈와 같다" "same" \
  "$(python3 -c "
import yaml
p=yaml.safe_load(open('$WF'))['env']['SHOREBIRD_FLUTTER_VERSION']
r=yaml.safe_load(open('.github/workflows/release-deploy.yml'))['env']['SHOREBIRD_FLUTTER_VERSION']
print('same' if p==r else f'{p} != {r}')")"
# 서명 키 파일명이 다르면 build.gradle.kts 가 조용히 debug 서명으로 떨어진다.
check "서명 키 경로가 릴리즈와 같다" "yes" \
  "$(grep -q 'android/upload-keystore.jks' "$WF" && echo yes || echo no)"
check "Secrets.xcconfig 경로가 릴리즈와 같다" "yes" \
  "$(grep -q 'ios/Flutter/Secrets.xcconfig' "$WF" && echo yes || echo no)"

echo
if [ "$fail" -eq 0 ]; then
  echo "✅ 전부 통과"
else
  echo "🔴 실패한 항목이 있다"
fi
exit "$fail"
