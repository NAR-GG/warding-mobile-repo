import Link from 'next/link';
import type { Notice } from 'warding-api';

import { formatDate } from '@/shared/lib';

/**
 * 공지 한 줄 — Flutter `notice_screen.dart` 의 `_NoticeCard` 와 같은 모양이다.
 *
 * 고정 공지는 `narBg` 그라데이션 1px 보더, 아니면 `narLine` 1px 보더다.
 * Dart 는 그라데이션 보더를 바깥 Container 의 1px 패딩으로 만드는데, 웹은
 * `border-image` 가 `border-radius` 를 못 따라가서 같은 방식(패딩 1px +
 * 안쪽 배경)으로 맞춘다.
 *
 * 상세는 이미 웹이라(`/notice/:id`) 브리지를 거치지 않고 `Link` 로 간다 —
 * `<a href>` 를 쓰면 문서 전체가 다시 로드돼 `loading.tsx` 가 뜨지 않는다.
 */
export function NoticeCard({ notice }: { notice: Notice }) {
  // Dart 의 `isDraft` 와 같은 판단이다 — 임시저장은 ADMIN 검수용으로만
  // 내려오고, 발행일이 없다.
  const draft = notice.publishedAt === null;

  return (
    <li className={notice.pinned ? 'notice-card notice-card--pinned' : 'notice-card'}>
      <Link className="notice-card__inner" href={`/notice/${notice.id}`}>
        {notice.pinned ? <span className="notice-card__pin">📌 고정</span> : null}

        <h2 className="notice-card__title">{notice.title}</h2>

        <p
          className={
            draft ? 'notice-card__date notice-card__date--draft' : 'notice-card__date'
          }
        >
          {draft ? '임시저장' : formatDate(notice.publishedAt!)}
        </p>
      </Link>
    </li>
  );
}
