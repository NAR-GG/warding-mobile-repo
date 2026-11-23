import { PlayerRatingHeader } from './PlayerRatingHeader';

/** 선수 평점을 받는 동안 보이는 화면. */
export function PlayerRatingSkeleton() {
  return (
    <>
      <PlayerRatingHeader />
      <section className="player-rating__head" aria-hidden="true">
        <div className="skeleton skeleton--title" />
        <div className="skeleton skeleton--meta" />
      </section>
      <section className="rating-dist" aria-hidden="true">
        <div className="skeleton skeleton--line" />
        <div className="skeleton skeleton--line" />
      </section>
    </>
  );
}
