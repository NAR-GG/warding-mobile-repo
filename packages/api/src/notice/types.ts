/**
 * 공지 도메인 타입.
 *
 * Flutter `features/notice/domain/notice.dart` 의 널 판단을 복제한다.
 * 목록 응답이 `content`(본문)까지 통째로 주므로 **상세 조회 API 가 따로
 * 필요 없다** — 목록에서 받은 항목을 그대로 그린다(Flutter 도 같다).
 */
export type Notice = {
  id: number;
  title: string;
  /** 마크다운 본문. 서버 에디터(tiptap-markdown)가 만든 형식이다. */
  content: string;
  /** 상단 고정 여부. */
  pinned: boolean;
  publishedAt: Date | null;
  /**
   * 누르면 이동할 외부 링크. 공백 문자열은 null 로 본다
   * (Dart `_nonBlank` 과 같은 처리).
   */
  actionUrl: string | null;
};

/** Spring Pageable 응답. */
export type NoticePage = {
  notices: Notice[];
  /** 마지막 페이지인가. */
  last: boolean;
  totalElements: number;
};
