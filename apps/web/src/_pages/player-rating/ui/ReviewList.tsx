import type { Review } from 'warding-api';
import { StarRating } from 'warding-ui';

import { cloudinaryScaled, timeAgo } from '@/shared/lib';
import { Avatar } from '@/widgets/review-card';

/**
 * 평점·코멘트 — Flutter `player_comment_section.dart` 의 웹 구현.
 *
 * 수치는 Dart 와 맞춘다 — 헤더 상하 16, '평점·코멘트' 14/w600,
 * '총 N개' 14/w400, 타일 상하 16 + **하단 `narLine2` 구분선**, gap 8,
 * 양옆 19.5.
 *
 * **카드 배경이 없다.** 내 리뷰 카드(`review-card`)는 `narDark600` 배경을
 * 깔지만 이쪽은 구분선으로만 나눈다 — 네이티브가 그렇다.
 */
export function ReviewList({ reviews }: { reviews: Review[] }) {
  return (
    <section className="comment-section">
      <header className="comment-section__head">
        <h2 className="comment-section__title">평점·코멘트</h2>
        <span className="comment-section__count">총 {reviews.length}개</span>
      </header>

      {reviews.length === 0 ? (
        <p className="activity-empty">아직 한줄평이 없어요</p>
      ) : (
        <ul>
          {reviews.map((r) => (
            <li key={r.ratingId} className="comment-tile">
              <div className="review-card__author">
                <Avatar url={r.profileImageUrl} size={37} />
                <span className="review-card__nickname">{r.nickname}</span>
                {r.teamImageUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    className="review-card__badge"
                    src={cloudinaryScaled(r.teamImageUrl, 42)}
                    alt=""
                    aria-hidden="true"
                  />
                ) : (
                  <span className="review-card__badge review-card__badge--empty" />
                )}
                {r.createdAt ? (
                  <time
                    className="review-card__time"
                    dateTime={r.createdAt.toISOString()}
                  >
                    {timeAgo(r.createdAt)}
                  </time>
                ) : null}
              </div>

              <StarRating rating={r.rating} label={`별점 ${r.rating}점`} />

              {r.comment ? (
                <p className="review-card__comment">{r.comment}</p>
              ) : null}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
