import { fetchPlayerRatingDetail } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';
import { positionFromRole } from '@/shared/lib';

import { PlayedChampCard } from './PlayedChampCard';
import { PlayerRatingHeader } from './PlayerRatingHeader';
import { RatingDistribution } from './RatingDistribution';
import { RatingSheet } from './RatingSheet';
import { ReviewList } from './ReviewList';

/**
 * 선수 평점 상세 — 열 번째 웹뷰 전환 화면.
 *
 * **비회원 조회가 열려 있다**(실측 2026-11-23, HTTP 200). 그래서 본문·분포·
 * 한줄평은 토큰 없이도 SSR 로 그려지고, 로그인했을 때만 `myRating` 과
 * `reviews[].mine` 이 채워진다.
 *
 * **토큰이 있으면 캐시하지 않는다.** `myRating` 이 사용자마다 달라 공유
 * 캐시에 담으면 남의 "내 평점" 이 보인다 — 커뮤니티 상세의 `viewer` 와 같은
 * 이유다. 비로그인 응답은 누구에게나 같아 짧게 캐시한다.
 *
 * **URL 이 `gameId`·`participantId` 둘뿐이다.** 네이티브는
 * `PlayerRatingScreen` 에 인자를 8개 넘겨야 했는데(팀명·진영·세트 목록…),
 * 웹은 상세 응답이 그 값을 전부 들고 있어 호출부가 알 필요가 없다. 그래서
 * 내 평점 목록에서 **브리지 없이 `<Link>` 하나로** 이어진다.
 *
 * **세트 드롭다운은 아직 없다.** 네이티브는 헤더에서 세트를 바꿀 수 있는데,
 * 그러려면 같은 매치의 세트 목록(`games`)이 필요하고 그건 경기 상세가
 * 들고 있는 값이다. 경기 상세가 웹으로 오기 전까지는 진입 시 세트에
 * 고정한다 — 내 평점 목록에서 들어오는 경로는 애초에 그 세트 하나다.
 */
export async function PlayerRatingPage({
  params,
}: {
  params: Promise<{ gameId: string; participantId: string }>;
}) {
  const { gameId, participantId: raw } = await params;
  const participantId = Number(raw);

  if (!Number.isFinite(participantId)) {
    return <main className="post-error">잘못된 주소입니다.</main>;
  }

  const token = await readAuthToken();

  const result = await fetchPlayerRatingDetail(
    { gameId, participantId },
    token === null
      ? { revalidate: 60 }
      : { token, cache: 'no-store' as const },
  );

  if (!result.ok) {
    const { kind } = result.failure;
    const message =
      kind === 'network'
        ? '연결이 불안정합니다. 잠시 후 다시 시도해 주세요.'
        : '평점을 불러오지 못했어요.';
    return (
      <>
        <PlayerRatingHeader />
        <p className="activity-empty">{message}</p>
      </>
    );
  }

  const d = result.value;
  const position = positionFromRole(d.player.role);

  return (
    <>
      <PlayerRatingHeader />

      {/* 챔피언 스플래시 아트 카드. 네이티브 화면의 첫인상을 만드는 요소라
          텍스트 줄로 대체하지 않는다. */}
      <PlayedChampCard player={d.player} />

      <RatingDistribution
        rating={d.averageRating}
        raterCount={d.ratingCount}
        distribution={d.distribution}
      />

      <RatingSheet
        gameId={gameId}
        participantId={participantId}
        playerName={d.player.playerName}
        position={position}
        signedIn={token !== null}
        rateable={d.rateable}
        myRating={d.myRating}
      />

      <ReviewList reviews={d.reviews} />
    </>
  );
}
