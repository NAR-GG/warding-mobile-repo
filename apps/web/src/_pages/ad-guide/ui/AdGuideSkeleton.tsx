import { AdGuideHeader } from './AdGuideHeader';

/**
 * 광고 안내를 받는 동안 보이는 화면.
 *
 * 공지 상세 스켈레톤과 따로 둔다 — 날짜 줄이 없어 한 줄 적고, 하단 버튼
 * 자리만큼 아래가 비어 있다.
 */
export function AdGuideSkeleton() {
  return (
    <>
      <AdGuideHeader />

      <article className="notice notice--landing" aria-hidden="true">
        <div className="skeleton skeleton--title" />
        <div className="skeleton skeleton--line" />
        <div className="skeleton skeleton--line" />
        <div className="skeleton skeleton--line skeleton--short" />
      </article>
    </>
  );
}
