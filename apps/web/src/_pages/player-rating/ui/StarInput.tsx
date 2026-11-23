'use client';

import { StarRating } from 'warding-ui';

/**
 * 별점 입력 — Flutter `core/ui/nar_star_rating_input.dart` 의 웹 구현.
 *
 * **0.5 단위다.** 별의 왼쪽 절반을 누르면 +0.5, 오른쪽 절반이면 +1.0 —
 * Dart 의 `_updateFromDx` 와 같은 판정이다.
 *
 * **`<input type=range>` 를 겹쳐 둔다.** 포인터 좌표만으로 만들면 키보드·
 * 스크린리더로 조작할 수 없다. range 는 그 둘을 공짜로 주고, 보이는 별은
 * 그 값을 따라 그린다.
 */
export function StarInput({
  value,
  onChange,
  starSize = 34,
  gap = 6,
}: {
  value: number;
  onChange: (next: number) => void;
  starSize?: number;
  gap?: number;
}) {
  return (
    <div className="star-input">
      <StarRating rating={value} starSize={starSize} gap={gap} />
      <input
        className="star-input__range"
        type="range"
        min={0.5}
        max={5}
        step={0.5}
        value={value === 0 ? 0.5 : value}
        aria-label={`별점 ${value}점`}
        onChange={(e) => onChange(Number(e.target.value))}
      />
    </div>
  );
}
