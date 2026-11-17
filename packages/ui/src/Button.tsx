import type { ButtonHTMLAttributes, ReactNode } from 'react';

/**
 * 앱 공용 버튼 — Flutter `core/ui/nar_button.dart` 의 웹 구현.
 *
 * variant 이름을 Dart enum 과 **같게 둔다.** 웹에서 더 읽기 좋은 이름
 * (`primary`·`ghost` 등)으로 바꾸면 두 구현을 대조할 때 매번 매핑표를 봐야
 * 하고, 어느 쪽이 바뀌었는지 추적이 끊긴다.
 */
export type ButtonVariant =
  | 'type1'
  | 'type2'
  | 'set1'
  | 'set1Disabled'
  | 'subscribe'
  | 'subscribed';

const CLASS: Record<ButtonVariant, string> = {
  type1: 'wd-button--type1',
  type2: 'wd-button--type2',
  set1: 'wd-button--set1',
  set1Disabled: 'wd-button--set1-disabled',
  subscribe: 'wd-button--subscribe',
  subscribed: 'wd-button--subscribed',
};

export type ButtonProps = {
  variant: ButtonVariant;
  children: ReactNode;
} & Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className'>;

const SUBSCRIBE = new Set<ButtonVariant>(['subscribe', 'subscribed']);

export function Button({ variant, children, ...rest }: ButtonProps) {
  // set1Disabled 는 Dart 에서 '준비중'·'경기 종료' 처럼 **누를 수 없는 상태**를
  // 나타내는 variant 다. 모양만 비활성인 버튼이 눌리면 안 되므로 기본으로
  // disabled 를 건다(호출부가 명시적으로 덮을 수는 있다).
  const disabled = rest.disabled ?? variant === 'set1Disabled';

  // 구독형은 '구독' ↔ '구독중' 으로 라벨이 바뀌어도 폭이 흔들리면 안 된다.
  // CSS 가 더 긴 라벨을 숨겨 깔아 폭을 잡으므로, 실제 라벨은 그 위에 겹치도록
  // 감싼다(→ styles.css 의 `.wd-button__label`).
  const body = SUBSCRIBE.has(variant) ? (
    <span className="wd-button__label">{children}</span>
  ) : (
    children
  );

  return (
    <button
      type="button"
      {...rest}
      disabled={disabled}
      className={`wd-button ${CLASS[variant]}`}
    >
      {body}
    </button>
  );
}
