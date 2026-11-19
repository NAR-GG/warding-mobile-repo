import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

/**
 * `--scale` 에 px 를 또 곱하지 않았는지 지키는 회귀 가드.
 *
 * `--scale` 은 `calc(clamp(320px, 100vw, 430px) / 375)` 라 **이미 px 단위다.**
 * `calc(62 * var(--scale) * 1px)` 로 쓰면 px² 가 되어 **그 선언이 통째로
 * 무효가 되는데, 빌드도 콘솔도 조용하다** — 화면이 무너져야 안다.
 *
 * 실제로 겪었다: 커뮤니티 목록 썸네일이 `width: 62px` 를 못 받아 원본
 * 1080×1350 으로 펼쳐져 화면 하나를 통째로 덮었다. 그때 `globals.css` 61곳이
 * 전부 같은 형태였다. 눈으로는 안 보이므로 테스트로 막는다.
 *
 * 단위가 필요한데 scale 을 안 곱하는 값(테두리 `1px` 등)은 이 검사에 걸리지
 * 않는다 — `var(--scale)` 과 같은 `calc()` 안에 있을 때만 문제다.
 */

const read = (relative: string) =>
  readFileSync(fileURLToPath(new URL(relative, import.meta.url)), 'utf8');

const TARGETS = [
  ['globals.css', './globals.css'],
  ['packages/ui/styles.css', '../../../../../packages/ui/src/styles.css'],
] as const;

for (const [label, path] of TARGETS) {
  test(`${label}: --scale 에 px 를 또 곱하지 않는다`, () => {
    const css = read(path);

    // `calc(...)` 중 var(--scale) 과 px 리터럴이 같이 있는 것을 찾는다.
    const offenders = [...css.matchAll(/calc\([^()]*var\(--scale\)[^()]*\)/g)]
      .map((m) => m[0])
      .filter((expr) => /\d\s*px/.test(expr));

    assert.deepEqual(
      offenders,
      [],
      `px² 가 되어 무효가 되는 선언이 있다 (단위 없이 calc(N * var(--scale)) 로 쓴다):\n${offenders.join('\n')}`,
    );
  });
}
