import { fetchNoticeBySlug } from 'warding-api/server';

import { NoticeBody } from '@/widgets/notice-body';

import { AdGuideHeader } from './AdGuideHeader';

/**
 * 광고 안내 — 여덟 번째 웹뷰 전환 화면.
 *
 * **공지 상세와 같은 본문을 그린다.** 백오피스가 `slug=ad-guide` 공지로
 * 관리하고, Flutter 도 `AdGuideScreen` 이 `NoticeDetailScreen` 을 그대로
 * 재사용한다(`landing: true`). 그래서 웹도 `NoticeBody` 를 공유한다.
 *
 * **공지 상세와 다른 점 셋.** Dart 의 `landing` 플래그가 가르는 것과 같다.
 * - 작성자·날짜 줄과 그 아래 구분선이 없다 (안내 페이지라 작성 시점이
 *   의미 없다)
 * - 제목이 20 (상세는 19)
 * - 하단에 신청 버튼이 고정으로 뜬다
 *
 * 비회원 조회가 열려 있어(실측 2026-11-23, HTTP 200) SSR 로 본문까지 그린다.
 */
export async function AdGuidePage() {
  // 백오피스가 이 값으로 공지를 만든다. Dart `AdGuideScreen.slug` 와 같다.
  const result = await fetchNoticeBySlug('ad-guide', { revalidate: 300 });

  if (!result.ok) {
    const { kind } = result.failure;
    const message =
      kind === 'network'
        ? '연결이 불안정합니다. 잠시 후 다시 시도해 주세요.'
        : '광고 안내를 불러오지 못했어요';
    return (
      <>
        <AdGuideHeader />
        <main className="post-error">{message}</main>
      </>
    );
  }

  const notice = result.value;

  return (
    <>
      <AdGuideHeader />

      <article className="notice notice--landing">
        <h1 className="notice__title notice__title--landing">{notice.title}</h1>

        <NoticeBody content={notice.content} />
      </article>

      {/* 본문 스크롤 위에 떠 있는 주 행동. Dart `BottomActionBar` 와 같이
          뒤에 배경색 막을 깔아 마지막 줄이 흐려지며 가려지게 한다.

          **`<a>` 다.** 구글폼이라 바깥 브라우저로 나가야 하고, 그 판정은
          네이티브 `shouldOpenInWebView` 가 호스트로 한다 — 웹이 따로
          브리지를 부르지 않는다. */}
      {notice.actionUrl ? (
        <div className="bottom-action">
          <a
            className="wd-cbtn wd-cbtn--primary bottom-action__button"
            href={notice.actionUrl}
            target="_blank"
            rel="noreferrer noopener"
          >
            광고 신청하기
          </a>
        </div>
      ) : null}
    </>
  );
}
