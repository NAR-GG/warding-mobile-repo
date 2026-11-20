import { fetchNotices } from 'warding-api/server';

import { formatDate } from '@/shared/lib';

import { NoticeBody } from './NoticeBody';
import { NoticeHeader } from './NoticeHeader';

/**
 * 공지 상세 — 두 번째 웹뷰 전환 화면.
 *
 * **상세 API 를 따로 부르지 않는다.** 목록 응답이 본문(`content`)까지 주므로
 * 목록에서 해당 id 를 찾아 그린다(Flutter 도 같은 구조다 — 상세 화면이
 * 목록에서 받은 객체를 그대로 쓰고 조회 기록만 보낸다).
 *
 * 비회원 조회가 열려 있어(실측 2026-11-18, HTTP 200) SSR 로 본문까지 그린다.
 */
export async function NoticePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const noticeId = Number(id);

  if (!Number.isFinite(noticeId)) {
    return <main className="post-error">잘못된 주소입니다.</main>;
  }

  // 공지는 자주 바뀌지 않는다. 목록 한 번으로 본문까지 얻는다.
  const result = await fetchNotices({ size: 100 }, { revalidate: 300 });

  if (!result.ok) {
    const { kind } = result.failure;
    const message =
      kind === 'network'
        ? '연결이 불안정합니다. 잠시 후 다시 시도해 주세요.'
        : '공지를 불러오지 못했습니다.';
    return <main className="post-error">{message}</main>;
  }

  const notice = result.value.notices.find((n) => n.id === noticeId);
  if (!notice) {
    return <main className="post-error">삭제되었거나 없는 공지입니다.</main>;
  }

  return (
    <>
      <NoticeHeader title="공지사항" />

      <article className="notice">
        <h1 className="notice__title">{notice.title}</h1>
        {notice.publishedAt ? (
          <time className="notice__date" dateTime={notice.publishedAt.toISOString()}>
            {formatDate(notice.publishedAt)}
          </time>
        ) : null}

        <NoticeBody content={notice.content} />

        {notice.actionUrl ? (
          <a className="notice__action" href={notice.actionUrl} target="_blank" rel="noreferrer noopener">
            자세히 보기
          </a>
        ) : null}
      </article>
    </>
  );
}
