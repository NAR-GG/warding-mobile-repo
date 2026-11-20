import { fetchNotices } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';

import { LoadMoreNotices } from './LoadMoreNotices';
import { NoticeCard } from './NoticeCard';
import { NoticeListHeader } from './NoticeListHeader';

/**
 * 공지 목록 — Flutter `notice_screen.dart` 의 웹 구현.
 *
 * **비회원도 볼 수 있다**(Dart 가 토큰 없이 부른다). 그래서 첫 페이지를
 * SSR 로 그린다.
 *
 * 마이페이지 '공지사항' 행에서 들어오고, 항목을 누르면 이미 웹인 상세
 * (`/notice/:id`)로 간다 — 둘 다 웹이라 브리지를 거치지 않는다.
 */
export async function NoticeListPage() {
  const token = await readAuthToken();

  // 공지는 자주 바뀌지 않는다. 비로그인은 캐시를 태우고, 로그인은 임시저장
  // (ADMIN 검수용)이 섞일 수 있어 캐시하지 않는다.
  const result = await fetchNotices(
    {},
    token === null ? { revalidate: 60 } : { token, cache: 'no-store' },
  );

  // 문구는 Dart 의 `app_ko.arb` 와 같은 것을 쓴다 — 웹에 번역 리소스가
  // 없어 한국어를 직접 적지만, 값이 어긋나면 같은 화면이 둘로 보인다.
  if (!result.ok) {
    return (
      <main>
        <NoticeListHeader />
        <p className="notice-list__empty">공지사항을 불러오지 못했어요</p>
      </main>
    );
  }

  const { notices, last } = result.value;

  return (
    <main>
      <NoticeListHeader />

      {notices.length === 0 ? (
        <p className="notice-list__empty">공지사항이 없어요</p>
      ) : (
        <ul className="notice-list">
          {notices.map((notice) => (
            <NoticeCard key={notice.id} notice={notice} />
          ))}

          {/* 첫 페이지가 0 이므로 다음은 1 이다. 마지막이면 센티넬 자체를
              만들지 않는다. */}
          {last ? null : <LoadMoreNotices page={1} />}
        </ul>
      )}
    </main>
  );
}
