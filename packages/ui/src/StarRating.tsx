/**
 * 별점 표시(읽기 전용) — Flutter `core/ui/nar_star_rating.dart` 의 웹 구현.
 *
 * **회색 빈 별 위에 노란 별을 채움 비율만큼 좌측 클립해 덮는다.** Dart 가
 * 같은 방식을 쓰는 이유가 그대로 적용된다 — 반 별 마스크를 쓰면 반투명하게
 * 뭉개져 탁해 보인다.
 *
 * `packages/ui` 에 있는 이유: Dart 원본이 `core/ui/` 다(기능 폴더가 아니다).
 */

/** 별 하나의 패스. `assets/icons/star.svg` 와 같은 좌표다. */
const STAR_PATH =
  'M7.00015 10.3543L3.39982 12.2472L4.08756 8.23797L1.1709 5.39889L5.1959 ' +
  '4.81555L6.99607 1.16797L8.79623 4.81555L12.8212 5.39889L9.90456 ' +
  '8.23797L10.5923 12.2472L7.00015 10.3543Z';

function Star({ fill, size }: { fill: number; size: number }) {
  // 비율이 0·1 이면 클립이 필요 없다 — 불필요한 clipPath 를 만들지 않는다.
  const clipped = fill > 0 && fill < 1;
  // id 가 문서에서 겹치면 다른 별의 클립을 쓴다. 비율·크기로 가른다.
  const clipId = `wd-star-${Math.round(fill * 100)}-${size}`;

  return (
    <svg
      className="wd-star"
      // **`width` 속성이 아니라 CSS 다.** 속성은 raw number 만 받아
      // `calc(n * var(--scale))` 를 못 쓴다 — 스케일이 안 먹으면 기기 폭이
      // 달라져도 별만 고정 크기로 남는다.
      style={{
        width: `calc(${size} * var(--scale))`,
        height: `calc(${size} * var(--scale))`,
      }}
      viewBox="0 0 14 14"
      fill="none"
      aria-hidden="true"
    >
      {clipped ? (
        <defs>
          <clipPath id={clipId}>
            <rect x="0" y="0" width={14 * fill} height="14" />
          </clipPath>
        </defs>
      ) : null}

      {/* 빈 별은 항상 깔고, 채운 별을 그 위에 덮는다. */}
      <path
        d={STAR_PATH}
        className="wd-star__empty"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      {fill > 0 ? (
        <path
          d={STAR_PATH}
          className="wd-star__full"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          {...(clipped ? { clipPath: `url(#${clipId})` } : {})}
        />
      ) : null}
    </svg>
  );
}

export type StarRatingProps = {
  /** 0 ~ maxStars. 소수면 그 비율만큼 채운다. */
  rating: number;
  maxStars?: number;
  /** 별 한 변(375 기준 원시값). `calc(n * var(--scale))` 로 쓰인다. */
  starSize?: number;
  gap?: number;
  /** 스크린리더용 라벨. 없으면 장식으로 본다. */
  label?: string;
};

export function StarRating({
  rating,
  maxStars = 5,
  starSize = 14,
  gap = 4,
  label,
}: StarRatingProps) {
  return (
    <span
      className="wd-stars"
      style={{
        gap: `calc(${gap} * var(--scale))`,
      }}
      {...(label
        ? { role: 'img', 'aria-label': label }
        : { 'aria-hidden': true })}
    >
      {Array.from({ length: maxStars }, (_, i) => (
        <Star
          key={i}
          fill={Math.max(0, Math.min(1, rating - i))}
          size={starSize}
        />
      ))}
    </span>
  );
}
