import { WriteForm } from './WriteForm';

/**
 * 글쓰기 화면.
 *
 * **SSR 로 그릴 것이 없다** — 빈 폼이고 임시저장은 브라우저 저장소에 있다.
 * 서버 컴포넌트는 껍데기만 두고 본문은 클라이언트가 맡는다.
 */
export function CommunityWritePage() {
  return (
    <main>
      <WriteForm />
    </main>
  );
}
