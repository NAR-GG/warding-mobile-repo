/**
 * 웹 ↔ 네이티브 브리지. Flutter 웹뷰가 주입하는 객체를 감싼다.
 *
 * Stage A(웹 → 네이티브 단방향)만 쓴다. 데이터는 이 경로로 받지 않는다 —
 * Next 서버가 API 를 직접 부른다(→ spec "데이터는 웹이 직접 받는다").
 *
 * 일반 브라우저에서는 브리지가 없다. 그때는 네이티브 의존 동작을 비활성화하고
 * 안내를 띄운다 — 같은 URL 을 브라우저로도 열 수 있어야 해서다.
 */

/** Flutter 쪽 `WebViewController` 가 등록하는 채널 이름. */
const CHANNEL = 'WardingBridge';

type BridgeChannel = { postMessage(message: string): void };

declare global {
  interface Window {
    [CHANNEL]?: BridgeChannel;
  }
}

/** 웹뷰 안에서 열렸는지. 브리지 객체 존재로 판별한다. */
export function isInWebView(): boolean {
  return typeof window !== 'undefined' && typeof window[CHANNEL] !== 'undefined';
}

/** Stage A 통지. 웹뷰 밖에서는 조용히 무시한다. */
function notify(type: string, payload?: Record<string, unknown>): void {
  const channel = typeof window !== 'undefined' ? window[CHANNEL] : undefined;
  if (!channel) return;
  channel.postMessage(JSON.stringify({ type, ...payload }));
}

/**
 * 본문 높이를 네이티브에 알린다. 웹뷰가 자기 높이를 콘텐츠에 맞춘다.
 *
 * 웹뷰를 스크롤 가능한 네이티브 화면 안에 끼울 때 필요하다 — 높이를 모르면
 * 웹뷰가 0 이거나 화면 전체를 먹는다.
 */
export function notifyHeight(height: number): void {
  notify('height', { height: Math.ceil(height) });
}

/** 첫 페인트 시각을 알린다. SSR 이득을 네이티브 쪽에서 측정하는 용도다. */
export function notifyReady(): void {
  notify('ready', { at: Date.now() });
}

/** 네이티브 화면으로 이동을 요청한다(예: 글쓴이 프로필). */
export function requestNavigate(route: string): void {
  notify('navigate', { route });
}
