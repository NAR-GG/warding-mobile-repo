#!/usr/bin/env node
// build/app_colors.dart → apps/mobile/lib/core/theme/app_colors.dart 복사.
//
// `build.mjs` 와 분리한 이유: turbo 의 `outputs` 는 패키지 밖을 캐시하지 못한다.
// Dart 를 패키지 밖에 바로 쓰면 캐시 적중 시 그 파일이 복원되지 않아,
// `app_colors.dart` 가 사라진 상태로 FULL TURBO 가 보고된다(실측으로 재현했다).
// 그래서 생성은 패키지 안(`build/`)에 하고 — 그건 캐시된다 — 복사만 매번 돈다.

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const src = join(root, 'build', 'app_colors.dart');
const dest = join(root, '..', '..', 'apps', 'mobile', 'lib', 'core', 'theme', 'app_colors.dart');

const next = readFileSync(src, 'utf8');
let prev = null;
try {
  prev = readFileSync(dest, 'utf8');
} catch {
  // 없으면 새로 쓴다
}
if (prev === next) {
  console.log('app_colors.dart 변화 없음');
} else {
  writeFileSync(dest, next);
  console.log('app_colors.dart 갱신 → apps/mobile/lib/core/theme/');
}
