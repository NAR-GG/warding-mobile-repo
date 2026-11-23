import { cloudinaryScaled } from '@/shared/lib';

/**
 * 작성자 아바타 — Flutter `review_card.dart` 의 `_Avatar` 와 같은 자리.
 *
 * **기본 이미지가 자산이 아니라 CSS 다.** Dart 는 `assets/images/person.png`
 * 를 쓰는데, 웹에 같은 자산이 없고 placeholder 하나 때문에 이미지를 더
 * 받을 이유가 없다 — 원형 실루엣을 인라인 SVG 로 그린다.
 */
export function Avatar({
  url,
  size,
  className = 'review-card__avatar',
}: {
  url: string | null;
  /** 375 기준 원시값. */
  size: number;
  className?: string;
}) {
  if (url === null || url === '') {
    return (
      <span className={`${className} ${className}--empty`} aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none">
          <circle cx="12" cy="9" r="4" fill="currentColor" />
          <path
            d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7"
            fill="currentColor"
          />
        </svg>
      </span>
    );
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      className={className}
      // 2배까지 선명하게 — 37px 칸에 원본을 받으면 수백 KB 다.
      src={cloudinaryScaled(url, size * 2)}
      alt=""
      aria-hidden="true"
    />
  );
}
