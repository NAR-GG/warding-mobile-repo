import type { RatingPlayerDetail } from 'warding-api';

import {
  championSplashUrl,
  cloudinaryScaled,
  laneIconPath,
  positionFromRole,
} from '@/shared/lib';

/**
 * '플레이한 챔프' 카드 — Flutter `features/player_rating/presentation/
 * widgets/played_champ_card.dart` 의 웹 구현.
 *
 * 수치는 Dart 와 맞춘다 — 카드 높이 101 · radius 10 · 좌우 여백 10,
 * 선수 사진 62 · radius 8, 이름 18/w600, 포지션 16/w600 + 라인 아이콘 14,
 * KDA 라벨/값, 콘텐츠는 **하단 정렬**(패딩 좌 8 · 우 7 · 아래 10).
 *
 * **배경은 챔피언 스플래시 아트다.** 그 위에 어두운 세로 그라데이션을 덧대
 * 글자가 읽히게 한다(`narPlayedChampOverlay`, stops 0/0.45/1).
 *
 * 이미지를 카드보다 6px 씩 크게 그린다(overscan) — Dart 주석 그대로다.
 * 스플래시 원본(1215×717)보다 카드가 훨씬 가로로 길쭉해 `cover` 크롭 여유가
 * 거의 없고, 서브픽셀 반올림으로 가장자리에 카드 배경이 얇은 선으로 비친다.
 */
export function PlayedChampCard({ player }: { player: RatingPlayerDetail }) {
  const splash = championSplashUrl(player.championName);
  const position = positionFromRole(player.role);
  const lane = laneIconPath(player.role);

  return (
    <section className="champ-card">
      {splash !== null ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img className="champ-card__splash" src={splash} alt="" aria-hidden="true" />
      ) : null}
      <span className="champ-card__overlay" aria-hidden="true" />

      <div className="champ-card__content">
        <div className="champ-card__left">
          {player.playerImageUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              className="champ-card__photo"
              src={cloudinaryScaled(player.playerImageUrl, 124)}
              alt=""
              aria-hidden="true"
            />
          ) : (
            // 사진이 없어도 자리를 비운다 — Dart 도 빈 SizedBox 를 둔다
            // (레이아웃이 흔들리지 않게).
            <span className="champ-card__photo champ-card__photo--empty" />
          )}

          <div className="champ-card__text">
            <strong className="champ-card__name">{player.playerName}</strong>
            <span className="champ-card__pos">
              {lane !== null ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img className="champ-card__lane" src={lane} alt="" aria-hidden="true" />
              ) : (
                <span className="champ-card__lane champ-card__lane--empty" />
              )}
              {position}
            </span>
          </div>
        </div>

        <div className="champ-card__kda">
          <span className="champ-card__kda-label">KDA</span>
          <strong className="champ-card__kda-value">
            {player.kills}/{player.deaths}/{player.assists}
          </strong>
        </div>
      </div>
    </section>
  );
}
