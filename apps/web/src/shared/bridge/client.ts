'use client';

import {
  CHANNEL,
  EVENT_PREFIX,
  type BroadcastMessage,
  type CallRequest,
  type CallResponse,
  type NativeEnv,
  type OutgoingMessage,
} from './protocol';

/**
 * 브리지 클라이언트. 웹뷰 밖(일반 브라우저)에서는 전부 무해하게 동작한다.
 *
 * 같은 URL 을 브라우저로도 열 수 있어야 하므로, 브리지가 없을 때 던지지
 * 않는다 — Stage A 는 조용히 무시하고, Stage C 는 실패를 돌려준다.
 */

type Channel = { postMessage(message: string): void };

declare global {
  interface Window {
    [CHANNEL]?: Channel;
    /** 네이티브가 Stage B·C 응답을 넣을 때 부르는 함수. */
    __wardingReceive?: (raw: string) => void;
  }
}

const channel = (): Channel | undefined =>
  typeof window === 'undefined' ? undefined : window[CHANNEL];

/** 웹뷰 안에서 열렸는지. 브리지 객체 존재로 판별한다. */
export const isInWebView = (): boolean => channel() !== undefined;

/**
 * 네이티브가 선언한 능력 목록. Stage B `env` 로 온다.
 *
 * 아직 안 받았으면 null 이다 — "모른다" 와 "없다" 는 다르다. 모를 때
 * [isSupported] 가 false 를 주므로 웹 폴백으로 떨어진다.
 */
let capabilities: string[] | null = null;

/** @internal 브로드캐스트 수신기가 채운다. */
export const setCapabilities = (next: string[] | undefined): void => {
  capabilities = next ?? [];
};

/**
 * 이 앱이 해당 브리지 기능을 처리할 수 있는가.
 *
 * **웹은 배포 즉시 전원에게 가지만 앱은 스토어 심사와 사용자 업데이트를
 * 기다린다.** 새 브리지 기능을 쓰기 전에 반드시 묻고, 아니면 **웹 자체
 * 구현으로 그린다** — 조사한 네 사례(Hotwire Native · 토스 · 당근
 * metabridge · Capacitor)가 모두 이 모양이고, 메서드명에 `v2` 를 붙이는
 * 곳은 없었다.
 *
 * **기본값이 웹 폴백이다**(Hotwire 의 핵심 규칙). 모르면 false 라, 구버전
 * 앱도 새 웹도 자동으로 안전한 쪽으로 떨어진다.
 *
 * ```ts
 * if (isSupported('share')) await share(url);
 * else await navigator.share?.({ url });   // 웹 폴백
 * ```
 */
export const isSupported = (name: string): boolean =>
  capabilities !== null && capabilities.includes(name);

function send(message: OutgoingMessage): boolean {
  const c = channel();
  if (!c) return false;
  c.postMessage(JSON.stringify(message));
  return true;
}

// ── Stage A ──────────────────────────────────────────────

/** 본문 높이를 알린다. 소수점은 올려서 잘림을 막는다. */
export const notifyHeight = (height: number): void => {
  send({ stage: 'a', type: 'height', height: Math.ceil(height) });
};

/** 첫 페인트 완료를 알린다. */
export const notifyReady = (at: number): void => {
  send({ stage: 'a', type: 'ready', at });
};

/** 네이티브 화면으로 이동을 요청한다. */
export const requestNavigate = (route: string): void => {
  send({ stage: 'a', type: 'navigate', route });
};

/**
 * 뒤로가기.
 *
 * **웹 히스토리가 먼저다.** 목록 → 상세처럼 웹 안에서 이동한 경우 네이티브
 * 스택에는 아무것도 쌓이지 않아서, 네이티브에 맡기면 `maybePop()` 이 되돌릴
 * 화면을 못 찾아 **아무 일도 일어나지 않는다**(실측으로 겪었다 — 탭 화면은
 * `pushReplacement` 로 열려 스택이 비어 있다).
 *
 * 웹에서 되돌아갈 곳이 없을 때만 네이티브에 넘긴다. 그때는 이 화면이
 * 네이티브가 push 한 첫 화면이므로 `maybePop()` 이 맞게 동작한다.
 *
 * **깊이를 `sessionStorage` 에 센다.** 모듈 변수로는 안 된다 — `<a href>` 가
 * 전체 로드라 값이 날아간다. `history.length` 도 못 쓴다: 웹뷰 세션이 1 에서
 * 시작한다는 보장이 없다.
 */
const DEPTH_KEY = 'warding:webview:depth';

const depth = (): number => {
  if (typeof sessionStorage === 'undefined') return 0;
  const n = Number(sessionStorage.getItem(DEPTH_KEY) ?? '0');
  return Number.isFinite(n) && n > 0 ? n : 0;
};

const setDepth = (n: number): void => {
  if (typeof sessionStorage === 'undefined') return;
  sessionStorage.setItem(DEPTH_KEY, String(Math.max(0, n)));
};

/**
 * 웹 내부 이동 한 단계를 기록한다.
 *
 * 링크를 눌러 다른 화면으로 갈 때 호출한다 — 그래야 뒤로가기가 네이티브가
 * 아니라 웹 히스토리를 되돌린다.
 */
export const pushWebDepth = (): void => setDepth(depth() + 1);

export const goBack = (): void => {
  if (typeof window === 'undefined') return;

  if (depth() > 0) {
    setDepth(depth() - 1);
    window.history.back();
    return;
  }

  // 웹에서 되돌아갈 곳이 없다 — 네이티브 스택을 되돌린다.
  if (send({ stage: 'a', type: 'back' })) return;
  // 브라우저로 직접 연 경우. 평소대로 히스토리를 쓴다.
  window.history.back();
};

// ── Stage C — 요청·응답 ──────────────────────────────────

type Pending = {
  resolve: (value: unknown) => void;
  reject: (reason: Error) => void;
  timer: ReturnType<typeof setTimeout>;
};

const pending = new Map<string, Pending>();
let seq = 0;

/** 응답을 기다리는 최대 시간. 네이티브가 조용히 죽어도 영원히 걸리지 않게 한다. */
const CALL_TIMEOUT_MS = 10_000;

function settle(res: CallResponse): void {
  const p = pending.get(res.id);
  if (!p) return;
  pending.delete(res.id);
  clearTimeout(p.timer);
  if (res.ok) p.resolve(res.value);
  else p.reject(new Error(res.error));
}

/**
 * 네이티브 기능을 부르고 결과를 기다린다.
 *
 * 웹뷰 밖에서는 즉시 실패한다 — 호출부가 `catch` 로 대체 동작(새 탭 열기 등)을
 * 고르게 한다.
 */
export function call(request: CallRequest): Promise<unknown> {
  const c = channel();
  if (!c) return Promise.reject(new Error('브리지 없음'));

  seq += 1;
  const id = `c${seq}`;

  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error('응답 시간 초과'));
    }, CALL_TIMEOUT_MS);

    pending.set(id, { resolve, reject, timer });
    c.postMessage(JSON.stringify({ stage: 'c', id, ...request }));
  });
}

/** 사진 전체화면 뷰어를 연다. 네이티브가 스와이프·줌을 맡는다. */
export const openPhotoViewer = (urls: string[], index: number): Promise<unknown> =>
  call({ method: 'openPhotoViewer', urls, index });

/** 시스템 공유 시트를 연다. */
export const share = (url: string, title?: string): Promise<unknown> =>
  call(title === undefined ? { method: 'share', url } : { method: 'share', url, title });

// ── Stage B — 네이티브 브로드캐스트 수신 ──────────────────

/**
 * 네이티브가 부르는 진입점을 설치한다.
 *
 * Stage B(브로드캐스트)와 Stage C 응답이 **같은 함수로 들어온다** — 네이티브가
 * JS 를 실행할 통로는 하나뿐이라, 봉투에 `id` 가 있으면 응답, 없으면
 * 브로드캐스트로 가른다.
 *
 * 브로드캐스트는 DOM 커스텀 이벤트로 다시 뿌린다. 구독자가 여럿일 수 있고
 * (화면·헤더·배너), 각자 `addEventListener` 로 붙었다 떨어지는 게 자연스럽다.
 */
export function installBridgeReceiver(): () => void {
  if (typeof window === 'undefined') return () => {};

  window.__wardingReceive = (raw: string) => {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      // 네이티브가 깨진 문자열을 보내도 페이지를 죽이지 않는다.
      return;
    }
    if (typeof parsed !== 'object' || parsed === null) return;

    if ('id' in parsed) {
      settle(parsed as CallResponse);
      return;
    }

    const msg = parsed as BroadcastMessage;
    if (typeof msg.type !== 'string') return;

    // 능력 목록은 이벤트로 뿌리기 전에 먼저 기록한다 — 구독자가 그걸 보고
    // 바로 분기할 수 있어야 한다.
    if (msg.type === 'env') setCapabilities(msg.env.supports);

    window.dispatchEvent(new CustomEvent(`${EVENT_PREFIX}${msg.type}`, { detail: msg }));
  };

  return () => {
    delete window.__wardingReceive;
  };
}

/** Stage B 구독. 해제 함수를 돌려준다. */
export function onBroadcast<T extends BroadcastMessage['type']>(
  type: T,
  handler: (message: Extract<BroadcastMessage, { type: T }>) => void,
): () => void {
  if (typeof window === 'undefined') return () => {};
  const listener = (e: Event) => {
    handler((e as CustomEvent).detail);
  };
  window.addEventListener(`${EVENT_PREFIX}${type}`, listener);
  return () => window.removeEventListener(`${EVENT_PREFIX}${type}`, listener);
}

export type { NativeEnv };
