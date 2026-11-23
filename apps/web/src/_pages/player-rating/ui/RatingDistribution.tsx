import type { RatingDistribution as Row } from 'warding-api';
import { StarRating } from 'warding-ui';

/**
 * 평균 평점 + 점수별 분포 — Flutter
 * `features/player_rating/presentation/widgets/
 * rating_distribution_section.dart` 의 웹 구현.
 *
 * 수치는 Dart 와 맞춘다 — padding 20, 평균 32/w500, 별 20, 좌측 블록 최대
 * 폭 116, 바 높이 4 · radius 5, 점수 라벨 폭 10, 퍼센트 폭 28.
 */
export function RatingDistribution({
  rating,
  raterCount,
  distribution,
}: {
  rating: number;
  raterCount: number;
  distribution: Row[];
}) {
  return (
    <section className="rating-dist">
      <div className="rating-dist__summary">
        <strong className="rating-dist__average">{rating.toFixed(1)}</strong>
        <StarRating
          rating={rating}
          starSize={20}
          label={`평균 별점 ${rating.toFixed(1)}점`}
        />
        <span className="rating-dist__count">총 {raterCount}명 참여</span>
      </div>

      <ul className="rating-dist__rows">
        {distribution.map((row) => (
          <li key={row.rating} className="rating-dist__row">
            <span className="rating-dist__score">{row.rating}</span>
            <span className="rating-dist__track">
              <span
                className="rating-dist__fill"
                // 퍼센트를 0~100 으로 가둔다 — 서버가 반올림으로 100 을
                // 넘겨도 바가 트랙 밖으로 나가지 않는다.
                style={{
                  width: `${Math.max(0, Math.min(100, row.percentage))}%`,
                }}
              />
            </span>
            <span className="rating-dist__percent">
              {Math.round(row.percentage)}%
            </span>
          </li>
        ))}
      </ul>
    </section>
  );
}
