import type { Review } from 'warding-api';
import { StarRating } from 'warding-ui';

import { cloudinaryScaled, timeAgo } from '@/shared/lib';
import { Avatar } from '@/widgets/review-card';

/**
 * 다른 사용자의 한줄평 목록 — Flutter `player_comment_section.dart` 의
 * 웹 구현.
 *
 * **내 리뷰 카드와 다른 컴포넌트다.** 저쪽은 리그·선수와 버튼 두 개가
 * 붙고, 이쪽은 닉네임·별점·본문만이다. 합치면 분기가 반반 섞인다.
 */
export function ReviewList({ reviews }: { reviews: Review[] }) {
  if (reviews.length === 0) {
    return <p className="activity-empty">아직 한줄평이 없어요</p>;
  }

  return (
    <ul className="review-list">
      {reviews.map((r) => (
        <li key={r.ratingId} className="player-review">
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
  );
}
