/**
 * "내 활동" 탭 — Dart `MyCommunityActivityTab` 과 같은 셋이다.
 *
 * **탭을 URL 로 가른다**(`/my-activity/posts|comments|scraps`). 네이티브는 한
 * 화면 안의 `PageView` 라 스와이프로 넘기는데, 웹은 그렇게 하면 탭마다
 * 클라이언트에서 받아와야 해서 SSR 이득이 사라진다 — 라우트로 가르면 각
 * 탭이 자기 데이터를 서버에서 그려 온다.
 *
 * **스와이프가 빠진다**(감수한 차이다). 네이티브 진입점 3개가 각각 초기 탭만
 * 달리 주던 구조라 URL 3개와 1:1 로 맞고, 탭 버튼은 그대로 있다.
 */
export const MY_ACTIVITY_TABS = ['posts', 'comments', 'scraps'] as const;

export type MyActivityTab = (typeof MY_ACTIVITY_TABS)[number];

export function isMyActivityTab(v: string): v is MyActivityTab {
  return (MY_ACTIVITY_TABS as readonly string[]).includes(v);
}

/** 탭 라벨. Dart 의 `app_ko.arb` 값과 같은 문자열이다. */
export const TAB_LABELS: Record<MyActivityTab, string> = {
  posts: '내가 쓴 글',
  comments: '내가 쓴 댓글',
  scraps: '스크랩',
};

/** 비었을 때의 안내. 역시 Dart arb 와 같다. */
export const TAB_EMPTY: Record<MyActivityTab, string> = {
  posts: '아직 쓴 글이 없어요',
  comments: '아직 쓴 댓글이 없어요',
  scraps: '스크랩한 글이 없어요',
};
