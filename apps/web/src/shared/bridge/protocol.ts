/**
 * 웹 ↔ 네이티브 브리지 규약.
 *
 * **이 파일이 양쪽의 계약이다.** Dart 쪽 `app/bridge/bridge_protocol.dart` 와
 * 메시지 이름·필드를 같게 유지한다 — 코드 생성이 없으므로 둘이 어긋나면
 * 런타임에야 드러난다. 한쪽을 고치면 반드시 다른 쪽도 본다.
 *
 * | 단계 | 방향 | 용도 |
 * |---|---|---|
 * | A | 웹 → 네이티브 | 단방향 통지 (높이·준비완료·화면이동·뒤로가기) |
 * | B | 네이티브 → 웹 | 브로드캐스트 (환경·인증 변경) |
 * | C | 웹 ↔ 네이티브 | 요청·응답 (사진 뷰어·공유 — 결과를 기다린다) |
 */

/** Flutter `WebViewController` 가 등록하는 JS 채널 이름. */
export const CHANNEL = 'WardingBridge';

/** 네이티브가 Stage B 를 뿌릴 때 쓰는 DOM 이벤트 접두사. */
export const EVENT_PREFIX = 'warding:';

// ── Stage A — 웹이 알리기만 한다 ─────────────────────────

export type NotifyMessage =
  /** 본문 높이. 웹뷰를 네이티브 스크롤 안에 끼울 때 필요하다. */
  | { stage: 'a'; type: 'height'; height: number }
  /** 첫 페인트 완료. SSR 이득 측정과 로딩 가림막 해제에 쓴다. */
  | { stage: 'a'; type: 'ready'; at: number }
  /** 네이티브 화면으로 이동 요청 (예: 글쓴이 프로필). */
  | { stage: 'a'; type: 'navigate'; route: string }
  /** 뒤로가기. 웹 히스토리가 아니라 네이티브 스택을 되돌려야 한다. */
  | { stage: 'a'; type: 'back' };

// ── Stage B — 네이티브가 뿌린다 ──────────────────────────

/** 네이티브가 알려 주는 환경. 웹이 이걸 보고 UI 를 맞춘다. */
export type NativeEnv = {
  /** 로그인 여부. 토큰 자체는 쿠키로 오고 여기엔 담지 않는다. */
  signedIn: boolean;
  /** 기기 "동작 줄이기" 설정. 애니메이션을 끌지 정한다. */
  reduceMotion: boolean;
  /** 세이프 에어리어(px). 네이티브가 웹뷰를 전체화면으로 띄울 때 쓴다. */
  safeAreaTop: number;
  safeAreaBottom: number;
  /**
   * 이 앱이 처리할 수 있는 메시지 이름.
   *
   * **웹은 배포 즉시 전원에게 가지만 앱은 업데이트를 기다린다.** 새 메시지를
   * 쓰기 전에 여기 있는지 확인하고, 없으면 웹 자체 구현으로 그린다
   * (→ [isSupported]).
   *
   * 구버전 앱은 이 필드를 안 보내므로 **없으면 빈 배열**로 본다 — 그러면
   * 모든 기능이 "미지원" 이 되어 웹 폴백으로 떨어진다. 조용히 깨지는 것보다
   * 낫다.
   */
  supports?: string[];
  /**
   * 앱 버전(`1.0.42+92`). **기능 판정에 쓰지 않는다** — 그건 [supports] 가
   * 한다. 버전 문자열 비교는 `1.0.9` vs `1.1.0` 처럼 자릿수를 독립 비교하다
   * 틀리는 사고가 흔하다. 로그·문의 대응용이다.
   */
  appVersion?: string;
};

export type BroadcastMessage =
  /** 환경 변경 (로그인·로그아웃·설정 변경). */
  | { type: 'env'; env: NativeEnv }
  /**
   * 토큰이 갱신됐다. 쿠키는 네이티브가 이미 다시 심은 뒤라,
   * 웹은 서버 데이터를 다시 받기만 하면 된다.
   */
  | { type: 'auth-changed' }
  /**
   * 방금 보낸 Stage A 메시지를 앱이 모른다.
   *
   * **구버전 앱이 새 메시지를 받았을 때 온다.** 전에는 네이티브가 조용히
   * 삼켜서, 웹은 보냈다고 믿고 사용자는 버튼이 안 먹는 이유를 몰랐다.
   * 받으면 폴백을 고르거나 안내를 띄운다.
   */
  | { type: 'unsupported'; name: string | null };

// ── Stage C — 요청하고 응답을 기다린다 ────────────────────

export type CallRequest =
  /** 사진 전체화면 뷰어. 네이티브가 좌우 스와이프·핀치줌을 맡는다. */
  | { method: 'openPhotoViewer'; urls: string[]; index: number }
  /** 시스템 공유 시트. */
  | { method: 'share'; url: string; title?: string };

/** 성공하면 `ok`, 실패하면 `error`. Dart 쪽도 같은 형태로 돌려준다. */
export type CallResponse =
  | { id: string; ok: true; value: unknown }
  | { id: string; ok: false; error: string };

/** 웹이 보내는 Stage C 요청 봉투. */
export type CallEnvelope = { stage: 'c'; id: string } & CallRequest;

/** 채널로 나가는 모든 메시지. */
export type OutgoingMessage = NotifyMessage | CallEnvelope;
