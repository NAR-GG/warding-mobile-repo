import { NoticeListHeader } from './NoticeListHeader';

/**
 * 목록을 받는 동안 즉시 보이는 화면.
 *
 * 카드 테두리·패딩을 실제 카드와 같게 둔다 — 다르면 데이터가 들어오는
 * 순간 레이아웃이 튄다. 펄스는 공용 `.skeleton` 을 쓴다(커뮤니티 목록과
 * 같은 애니메이션이라 화면을 오갈 때 리듬이 어긋나지 않는다).
 *
 * **헤더를 포함한다.** 헤더까지 비어 있으면 화면이 통째로 바뀐 것처럼
 * 보이고, 뒤로가기도 이 동안 눌릴 수 있어야 한다.
 */
export function NoticeListSkeleton() {
  return (
    <main>
      <NoticeListHeader />

      <ul className="notice-list" aria-hidden="true">
        {Array.from({ length: 6 }, (_, i) => (
          <li className="notice-card" key={i}>
            <div className="notice-card__inner">
              <div className="skeleton skeleton--title" />
              <div className="skeleton skeleton--meta" />
            </div>
          </li>
        ))}
      </ul>
    </main>
  );
}
