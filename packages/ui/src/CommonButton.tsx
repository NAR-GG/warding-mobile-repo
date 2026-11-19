import type { ButtonHTMLAttributes, ReactNode } from 'react';

/**
 * 앱 공용 버튼 — Flutter `core/ui/nar_button.dart` 와 다른 계열이다.
 * 이쪽은 `core/ui/common_button.dart`(소비처 13곳)의 웹 구현이다.
 *
 * **두 버튼 계열이 공존하는 것은 Dart 쪽 사정 그대로다.** `NarButton` 은
 * 시안 `nar_button_*` 을 옮긴 작은 버튼(높이 34)이고, 이쪽은 온보딩·마이페이지
 * 계열의 큰 버튼(높이 50)이다. 웹에서 합치면 두 디자인이 섞이므로 그대로 둔다.
 *
 * variant 이름을 Dart enum 과 같게 둔다 — 두 구현을 대조할 때 매핑표를 보지
 * 않아도 되게 하려는 것이다.
 */
export type CommonButtonVariant =
  /** 전체 폭 그라데이션. 비활성이면 반투명 다크. */
  | 'primary'
  /** 전체 폭 솔리드 (온보딩 '완료/다음'). */
  | 'light'
  /** 다크 배경 + 로그아웃 아이콘, 내용 폭. */
  | 'logout'
  /** 다크 배경 + 흰 텍스트, 아이콘 없는 내용 폭. */
  | 'dark'
  /** 배경 없는 텍스트 버튼 (회원탈퇴·리뷰삭제). */
  | 'text';

const CLASS: Record<CommonButtonVariant, string> = {
  primary: 'wd-cbtn--primary',
  light: 'wd-cbtn--light',
  logout: 'wd-cbtn--logout',
  dark: 'wd-cbtn--dark',
  text: 'wd-cbtn--text',
};

/** 내용 폭 variant. 전체 폭(primary·light)과 치수가 다르다. */
const COMPACT = new Set<CommonButtonVariant>(['logout', 'dark', 'text']);

function LogoutIcon() {
  // Flutter 는 svg 에셋을 쓰지만 웹은 자산 요청을 한 번 줄이려고 인라인으로 둔다.
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true" className="wd-cbtn__icon">
      <path
        d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export type CommonButtonProps = {
  variant?: CommonButtonVariant;
  children: ReactNode;
} & Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className'>;

export function CommonButton({
  variant = 'primary',
  children,
  ...rest
}: CommonButtonProps) {
  const compact = COMPACT.has(variant) ? ' wd-cbtn--compact' : '';

  return (
    <button type="button" {...rest} className={`wd-cbtn ${CLASS[variant]}${compact}`}>
      {variant === 'logout' ? <LogoutIcon /> : null}
      {children}
    </button>
  );
}
