import type { ReactNode } from 'react';

/**
 * 뱃지 3종 — Flutter `core/ui/nar_badge.dart` 의 웹 구현.
 *
 * 셋 다 **높이 24 로 같다.** 시간 뱃지와 LIVE 뱃지가 자리를 교체할 수 있어야
 * 하기 때문이다(Dart 주석에 명시돼 있다).
 *
 * **radius 8 은 scale 을 곱하지 않는다.** Dart 도 `BorderRadius.circular(8)` 로
 * 고정이다 — 작은 모서리는 화면 폭에 따라 커지면 오히려 어색해진다.
 */

/** 기본 뱃지. 시간 표시 등에 쓴다 (시안 `nar_badge`). */
export function Badge({ children }: { children: ReactNode }) {
  return <span className="wd-badge">{children}</span>;
}

export type BadgeSideValue = 'blue' | 'red';

/**
 * 진영 뱃지. **폭 59 고정**이다 — 'BLUE'/'RED' 중 긴 쪽에 맞춰 두 진영이
 * 나란히 놓였을 때 어긋나지 않게 한다.
 */
export function BadgeSide({
  side,
  label,
}: {
  side: BadgeSideValue;
  label?: string;
}) {
  return (
    <span className={`wd-badge wd-badge--side wd-badge--${side}`}>
      {label ?? (side === 'blue' ? 'BLUE' : 'RED')}
    </span>
  );
}

/**
 * LIVE 뱃지. 옅은 빨강 배경 + 깜박이는 점.
 *
 * 점은 Flutter 의 `NarLiveDot`(1.2초 주기)과 같은 주기로 깜박인다. **동작
 * 줄이기 설정이면 고정**한다 — CSS `prefers-reduced-motion` 이 맡는다.
 */
export function BadgeLive({ label = 'LIVE' }: { label?: string }) {
  return (
    <span className="wd-badge wd-badge--live">
      <span className="wd-badge__dot" aria-hidden="true" />
      {label}
    </span>
  );
}
