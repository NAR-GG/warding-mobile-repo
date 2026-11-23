import { fetchMyRatings } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';
import { ReviewCard } from '@/widgets/review-card';

import { groupByDate } from '../lib/groupByDate';
import { MyReviewHeader } from './MyReviewHeader';

/**
 * 마이페이지 "내 리뷰/평점" — 아홉 번째 웹뷰 전환 화면.
 *
 * **로그인 필수다**(실측 2026-11-23, 무인증 401). 네이티브가 쿠키를 심고
 * 나서 로드하므로 정상 경로에서는 토큰이 늘 있지만, 만료된 채 들어올 수
 * 있어 안내를 그린다.
 *
 * **캐시하지 않는다.** 사용자마다 다른 목록이라 공유 캐시에 담으면 남의
 * 평가가 보인다(내 활동과 같은 이유).
 *
 * **항목의 '리뷰보기' 가 선수 평점으로 가는데 그것도 웹이다** — 브리지를
 * 거치지 않고 `<Link>` 로 이어진다. 네이티브는 `PlayerRatingScreen` 에
 * 인자를 8개 넘겨야 했는데, 웹은 URL 두 조각(`gameId`·`participantId`)이면
 * 상세가 나머지를 스스로 받는다.
 *
 * **무한 스크롤은 아직 없다.** 첫 페이지(20건)만 그린다 — 커뮤니티 목록을
 * 옮길 때와 같은 판단이다(SSR 이득을 먼저 재고 붙인다). 네이티브는
 * `loadMore` 가 있으므로 **평가가 20건을 넘는 사용자는 뒤쪽을 못 본다** —
 * 붙일 때는 `LoadMoreActivity` 와 같은 구조를 쓰면 된다(그쪽은 커서,
 * 이쪽은 `page` 라는 것만 다르다).
 */
export async function MyReviewPage() {
  const token = await readAuthToken();

  if (token === null) {
    return (
      <>
        <MyReviewHeader />
        <p className="activity-empty">로그인이 필요합니다</p>
      </>
    );
  }

  const result = await fetchMyRatings({}, { token, cache: 'no-store' });

  if (!result.ok) {
    const { kind } = result.failure;
    const message =
      kind === 'unauthorized'
        ? '로그인이 필요합니다'
        : kind === 'network'
          ? '연결이 불안정합니다. 잠시 후 다시 시도해 주세요.'
          : '내 리뷰를 불러오지 못했어요.';
    return (
      <>
        <MyReviewHeader />
        <p className="activity-empty">{message}</p>
      </>
    );
  }

  const { ratings, totalElements } = result.value;
  const groups = groupByDate(ratings);

  return (
    <>
      <MyReviewHeader />

      {/* 누적 건수. 숫자만 그라데이션이다 — Dart 의 `ShaderMask` 자리다. */}
      <div className="review-count">
        <span className="review-count__label">누적 리뷰/평점</span>
        <span className="review-count__value">{totalElements}건</span>
      </div>

      {ratings.length === 0 ? (
        <p className="activity-empty">작성한 리뷰가 없어요</p>
      ) : (
        [...groups].map(([date, items]) => (
          <section key={date}>
            <h2 className="review-date">{date}</h2>
            <ul className="review-list">
              {items.map((item) => (
                <ReviewCard key={item.ratingId} item={item} />
              ))}
            </ul>
          </section>
        ))
      )}
    </>
  );
}
