import { NoticeHeader } from './NoticeHeader';

/**
 * 공지 상세를 받는 동안 보이는 화면.
 *
 * **목록 스켈레톤과 따로 둔다.** `app/notice/loading.tsx` 는 하위 경로인
 * `[id]` 에도 적용되므로, 상세에 자체 `loading.tsx` 가 없으면 상세를 여는
 * 동안 목록 카드 6장이 깜빡인다.
 */
export function NoticeSkeleton() {
  return (
    <>
      <NoticeHeader title="공지사항" />

      <article className="notice" aria-hidden="true">
        <div className="skeleton skeleton--title" />
        <div className="skeleton skeleton--meta" />
        <div className="skeleton skeleton--line" />
        <div className="skeleton skeleton--line" />
        <div className="skeleton skeleton--line skeleton--short" />
      </article>
    </>
  );
}
