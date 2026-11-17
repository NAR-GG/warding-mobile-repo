// 웹뷰 화면이 쓰는 공용 컴포넌트.
//
// 각 컴포넌트는 Flutter `core/ui/` 의 대응 위젯과 **수치를 맞춘다.** 파일 머리
// 주석에 어느 Dart 파일에서 왔는지 적어 두었으니, 한쪽을 고칠 때 다른 쪽도 본다.
// 색·간격은 `warding-design-tokens` 가 단일 출처다.

export { BoardBadge } from './BoardBadge';
export type { BoardBadgeProps } from './BoardBadge';

export { Button } from './Button';
export type { ButtonProps, ButtonVariant } from './Button';

export { DetailHeader } from './DetailHeader';
export type { DetailHeaderProps } from './DetailHeader';
