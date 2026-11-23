import { MyReviewHeader } from './MyReviewHeader';

/** 내 리뷰 목록을 받는 동안 보이는 화면. */
export function MyReviewSkeleton() {
  return (
    <>
      <MyReviewHeader />
      <div className="review-count" aria-hidden="true">
        <span className="skeleton skeleton--meta" />
      </div>
      <ul className="review-list" aria-hidden="true">
        {[0, 1, 2].map((i) => (
          <li key={i} className="review-card">
            <div className="skeleton skeleton--meta" />
            <div className="skeleton skeleton--line" />
            <div className="skeleton skeleton--line skeleton--short" />
          </li>
        ))}
      </ul>
    </>
  );
}
