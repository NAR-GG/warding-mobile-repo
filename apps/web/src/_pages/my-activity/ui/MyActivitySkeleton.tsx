import { PostCardSkeleton } from '@/widgets/post-card';

import { MyActivityHeader } from './MyActivityHeader';

/**
 * 목록을 받는 동안 보이는 화면.
 *
 * **헤더와 탭을 포함한다.** 탭까지 비면 화면이 통째로 바뀐 것처럼 보이고,
 * 탭 전환이 곧 페이지 이동이라 전환 중에도 눌릴 수 있어야 한다.
 *
 * **어느 탭인지는 헤더가 스스로 읽는다.** Next 의 `loading.tsx` 는 props 를
 * 받지 못해서(라우트 params 가 오지 않는다) 여기서 넘겨줄 수가 없다.
 *
 * 카드는 글 탭 기준(`PostCardSkeleton`)으로 그린다. 댓글 줄은 썸네일이
 * 없어 모양이 다르지만, 셋을 따로 만들 만큼 차이가 크지 않다.
 */
export function MyActivitySkeleton() {
  return (
    <main>
      <MyActivityHeader />

      <ul className="post-list" aria-hidden="true">
        {Array.from({ length: 6 }, (_, i) => (
          <PostCardSkeleton key={i} />
        ))}
      </ul>
    </main>
  );
}
