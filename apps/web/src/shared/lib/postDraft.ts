/**
 * 글쓰기 임시저장.
 *
 * **이미지는 URL 만 담는다.** 사진은 고르는 즉시 Cloudinary 에 올라가므로
 * 드래프트는 순수 문자열 JSON 이 된다 — localStorage 로 충분하고 IndexedDB·
 * Blob·쿼터 문제를 통째로 피한다.
 *
 * 덤으로 네이티브의 약점이 사라진다. Dart 드래프트는 **기기 로컬 파일 경로**를
 * 저장해서, 복원할 때 그 파일이 사라졌으면 사진을 조용히 건너뛴다
 * (`resumePreuploads` 의 `existsSync` 검사). URL 은 그럴 일이 없다.
 *
 * **최대 7일만 남는다.** Safari 는 크로스사이트 추적 방지가 켜져 있을 때
 * "최근 7일간 클릭·탭이 없는 origin 의 **스크립트가 만든 데이터**" 를
 * 지운다(MDN Storage quotas and eviction criteria). 서버가 심은 쿠키는
 * 예외지만 localStorage 는 대상이다. 그래서 화면이 사용자에게 이 사실을
 * 알린다 — 네이티브(Keychain)보다 보존 기간이 짧은 것은 **감수한 선택**이지
 * 사고가 아니다.
 *
 * 서버 드래프트로 옮기면 해결되지만 백엔드에 해당 API 가 없다(경로 144개 중
 * `draft` 0건, 실측 2026-11-20).
 */

const KEY = 'warding:community:draft';

/** 보존 기간. 이 날짜를 넘긴 드래프트는 읽을 때 버린다. */
export const DRAFT_MAX_AGE_DAYS = 7;

export type PostDraft = {
  title: string;
  body: string;
  /** 이미 업로드된 사진의 `secure_url`. 로컬 경로가 아니다. */
  imageUrls: string[];
  /** 저장 시각(epoch ms). 화면이 "N분 전 저장" 을 띄우는 데 쓴다. */
  savedAt: number;
};

/**
 * 드래프트를 읽는다. 없거나 깨졌으면 null.
 *
 * **7일이 지난 것은 버린다.** 브라우저가 지우기 전이라도 그만큼 오래된 초안은
 * 사용자가 기억하지 못한다 — 보존 기간을 화면에 알린 것과 동작을 맞춘다.
 */
export function loadDraft(): PostDraft | null {
  if (typeof localStorage === 'undefined') return null;

  const raw = localStorage.getItem(KEY);
  if (raw === null) return null;

  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null) return null;

    const d = parsed as Partial<PostDraft>;
    if (typeof d.savedAt !== 'number') return null;

    const ageDays = (Date.now() - d.savedAt) / 86_400_000;
    if (ageDays > DRAFT_MAX_AGE_DAYS) {
      clearDraft();
      return null;
    }

    return {
      title: typeof d.title === 'string' ? d.title : '',
      body: typeof d.body === 'string' ? d.body : '',
      imageUrls: Array.isArray(d.imageUrls)
        ? d.imageUrls.filter((u): u is string => typeof u === 'string')
        : [],
      savedAt: d.savedAt,
    };
  } catch {
    // 깨진 값은 지우고 없는 것으로 본다 — 매번 같은 에러를 만나지 않게.
    clearDraft();
    return null;
  }
}

export function saveDraft(draft: Omit<PostDraft, 'savedAt'>): void {
  if (typeof localStorage === 'undefined') return;
  try {
    const payload: PostDraft = { ...draft, savedAt: Date.now() };
    localStorage.setItem(KEY, JSON.stringify(payload));
  } catch {
    // 쿼터 초과·프라이빗 모드 등. 저장 실패로 글쓰기를 막지는 않는다.
  }
}

export function clearDraft(): void {
  if (typeof localStorage === 'undefined') return;
  try {
    localStorage.removeItem(KEY);
  } catch {
    // 지우기 실패도 무시한다.
  }
}
