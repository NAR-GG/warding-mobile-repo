import { SearchBody } from './SearchBody';

/**
 * 커뮤니티 검색 화면.
 *
 * **SSR 로 그릴 것이 없다** — 결과가 입력에 따라 바뀐다. 서버 컴포넌트는
 * 껍데기만 두고 본문은 클라이언트가 맡되, 결과 카드는 Server Action 이
 * 그려서 넘긴다(→ `searchAction`).
 */
export function CommunitySearchPage() {
  return (
    <main>
      <SearchBody />
    </main>
  );
}
