import type { MyReviewItem } from 'warding-api';
import { StarRating } from 'warding-ui';

import { cloudinaryScaled, timeAgo } from '@/shared/lib';
import { WebLink } from '@/shared/ui';

import { Avatar } from './Avatar';
import { DeleteReviewButton } from './DeleteReviewButton';

/**
 * 내 리뷰 한 건 — Flutter `features/my_review/presentation/widgets/
 * review_card.dart` 의 웹 구현.
 *
 * 수치는 Dart 와 맞춘다 — 배경 `nar-dark600`, 패딩 20/10, 리그·선수 14/w500,
 * 닉네임 14/w600, 시각 11/w400, 아바타 37, 구독 뱃지 21.
 *
 * **'리뷰보기' 가 `<a>` 다.** 선수 평점도 웹이라 브리지를 거치지 않는다.
 * `WebLink` 를 쓰는 이유는 **이동 깊이를 기록**해야 상세의 뒤로가기가
 * 네이티브가 아니라 웹 히스토리를 되돌리기 때문이다.
 *
 * **삭제만 클라이언트 경계다.** 확인 후 서버 액션을 부르므로 카드 본체는
 * 서버 컴포넌트로 남는다.
 */
export function ReviewCard({ item }: { item: MyReviewItem }) {
  // 매핑이 없으면 리그·팀 줄을 비운다(Dart 와 같다).
  const league = item.match?.leagueName ?? '';

  return (
    <li className="review-card">
      <p className="review-card__meta">
        {league ? <span>{league}</span> : null}
        <span>{item.playerName}</span>
      </p>

      <div className="review-card__author">
        <Avatar url={item.profileImageUrl} size={37} />
        <span className="review-card__nickname">나</span>
        {/* 구독 뱃지 — 없으면 회색 원. Dart 도 placeholder 를 그린다. */}
        {item.teamImageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            className="review-card__badge"
            src={cloudinaryScaled(item.teamImageUrl, 42)}
            alt=""
            aria-hidden="true"
          />
        ) : (
          <span className="review-card__badge review-card__badge--empty" />
        )}
        {item.createdAt ? (
          <time
            className="review-card__time"
            dateTime={item.createdAt.toISOString()}
          >
            {timeAgo(item.createdAt)}
          </time>
        ) : null}
      </div>

      <StarRating
        rating={item.rating}
        label={`별점 ${item.rating}점`}
      />

      {item.comment ? (
        <p className="review-card__comment">{item.comment}</p>
      ) : null}

      <div className="review-card__actions">
        <WebLink
          className="wd-cbtn wd-cbtn--compact wd-cbtn--dark review-card__view"
          href={`/rating/${encodeURIComponent(item.gameId)}/${item.participantId}`}
        >
          리뷰보기
        </WebLink>
        <DeleteReviewButton
          gameId={item.gameId}
          participantId={item.participantId}
        />
      </div>
    </li>
  );
}
