import type { ReactNode } from 'react';

/**
 * 상세 화면 헤더 — Flutter `core/ui/nar_detail_header.dart` 의 웹 구현.
 *
 * 기본은 제목 가운데 고정이고, `align="start"` 면 뒤로가기 옆에 붙인다
 * (Dart 의 `centerTitle: false`).
 *
 * 뒤로가기는 **네이티브로 위임한다.** 웹뷰 안에서 `history.back()` 을 부르면
 * 웹 라우팅만 되돌아가고 네이티브 화면 스택은 그대로라, 사용자가 보기엔
 * 아무 일도 안 일어난다. 그래서 `onBack` 을 필수로 받아 호출부가
 * 브리지(`requestNavigate`)로 넘기게 한다.
 */
export type DetailHeaderProps = {
  title: string;
  /** 뒤로가기 처리. 웹뷰에서는 브리지로 네이티브에 위임한다. */
  onBack: () => void;
  /** 우측 슬롯 (스포방지 토글 등) */
  trailing?: ReactNode;
  /** 제목 앞에 붙는 요소 (`align="start"` 일 때만 쓴다 — Dart 의 `titleLeading`) */
  titleLeading?: ReactNode;
  align?: 'center' | 'start';
  /** 접근성 라벨. 웹에 번역 리소스가 없어 호출부가 넘긴다. */
  backLabel?: string;
};

function BackIcon() {
  // Flutter 는 svg 에셋을 쓰지만(`assets/icons/back.svg`), 웹은 자산 요청을
  // 한 번 줄이려고 인라인으로 둔다 — 헤더는 모든 화면 최상단이라 이 한 번의
  // 왕복이 첫 페인트에 그대로 보인다.
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M15 19l-7-7 7-7"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function DetailHeader({
  title,
  onBack,
  trailing,
  titleLeading,
  align = 'center',
  backLabel = '뒤로',
}: DetailHeaderProps) {
  const back = (
    <button
      type="button"
      className="wd-detail-header__back"
      onClick={onBack}
      aria-label={backLabel}
    >
      <BackIcon />
    </button>
  );

  const titleEl = <h1 className="wd-detail-header__title">{title}</h1>;
  const trailingEl = trailing ? (
    <div className="wd-detail-header__trailing">{trailing}</div>
  ) : null;

  if (align === 'start') {
    return (
      <header className="wd-detail-header wd-detail-header--start">
        <div className="wd-detail-header__lead">
          {back}
          {titleLeading ? (
            <div className="wd-detail-header__leading">{titleLeading}</div>
          ) : null}
          {titleEl}
        </div>
        {trailingEl}
      </header>
    );
  }

  return (
    <header className="wd-detail-header">
      {titleEl}
      {back}
      {trailingEl}
    </header>
  );
}
