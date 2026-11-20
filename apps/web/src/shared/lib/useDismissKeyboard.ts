'use client';

import { useEffect } from 'react';

/**
 * 빈 곳을 탭하거나 스크롤하면 키보드를 내린다.
 *
 * **네이티브와 같은 조작감을 맞춘다.** Dart 글 상세는 바깥 탭에
 * `FocusScope.unfocus()` 를, 스크롤에 `keyboardDismissBehavior.onDrag` 를
 * 걸어 둔다. 웹뷰에는 그게 없어서, iOS 가 자동으로 붙이는 "Done" 툴바가
 * 유일한 닫기 수단이 된다 — 네이티브에는 없던 UI 라 어색하다.
 *
 * `Done` 툴바 자체는 **없앨 수 없다.** WKWebView 의 `inputAccessoryView` 를
 * 바꾸려면 공식 API 가 아닌 우회(스위즐링)가 필요하고, OS 업데이트마다
 * 깨질 수 있다. 대신 **다른 닫기 수단을 주어** 툴바에 의존하지 않게 한다.
 */
export function useDismissKeyboard(): void {
  useEffect(() => {
    const active = (): HTMLElement | null => {
      const el = document.activeElement;
      return el instanceof HTMLElement ? el : null;
    };

    const isInput = (el: Element | null): boolean =>
      el instanceof HTMLInputElement ||
      el instanceof HTMLTextAreaElement ||
      el instanceof HTMLSelectElement;

    const onPointerDown = (e: Event) => {
      const el = active();
      if (el === null || !isInput(el)) return;
      // 입력창 안이나 폼 버튼을 누른 것이면 두 번째 탭을 요구하지 않는다.
      const target = e.target;
      if (target instanceof Element && target.closest('input, textarea, select, button')) {
        return;
      }
      el.blur();
    };

    // 스크롤로도 내린다(Dart `onDrag`). 입력 중 목록을 훑을 때 키보드가
    // 화면 절반을 가리고 있으면 읽을 수가 없다.
    const onScroll = () => {
      const el = active();
      if (el !== null && isInput(el)) el.blur();
    };

    document.addEventListener('pointerdown', onPointerDown);
    // passive: 스크롤을 막지 않는다 — 여기서 preventDefault 할 일이 없다.
    window.addEventListener('scroll', onScroll, { passive: true });

    return () => {
      document.removeEventListener('pointerdown', onPointerDown);
      window.removeEventListener('scroll', onScroll);
    };
  }, []);
}
