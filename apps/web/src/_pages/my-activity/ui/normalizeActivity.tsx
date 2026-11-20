import type { ReactNode } from 'react';
import type { MyCommentPage, MyPostPage, ScrapPage } from 'warding-api';

import { PostCard } from '@/widgets/post-card';

import { MyCommentRow } from './MyCommentRow';

/**
 * 탭별 응답을 **그려진 항목 + 커서**로 통일한다.
 *
 * 세 응답은 모양이 다르다(글 배열 / 댓글 배열 / 스크랩 래퍼). 화면이 그
 * 차이를 알 필요는 없고, 커서의 의미도 여기서 닫힌다.
 *
 * **첫 페이지와 더보기가 같은 함수를 쓴다** — 따로 그리면 스크롤하다 카드
 * 모양이 바뀐다. 그래서 페이지 컴포넌트가 아니라 별도 파일에 있다(서버
 * 액션 파일은 async 함수만 내보낼 수 있어 거기 둘 수도 없다).
 */
export function normalizeActivity(
  page: MyPostPage | MyCommentPage | ScrapPage,
): { items: ReactNode[]; nextCursor: number | null } {
  if ('comments' in page) {
    return {
      items: page.comments.map((c) => <MyCommentRow key={c.id} comment={c} />),
      nextCursor: page.nextCursor,
    };
  }

  if ('items' in page) {
    return {
      // key 는 scrapId 다 — 커서가 scrapId 라 그쪽이 목록의 신원에 맞다.
      items: page.items.map((s) => <PostCard key={s.scrapId} post={s.post} />),
      nextCursor: page.nextCursor,
    };
  }

  return {
    items: page.posts.map((p) => <PostCard key={p.id} post={p} />),
    nextCursor: page.nextCursor,
  };
}
