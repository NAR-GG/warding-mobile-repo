import type { MyReviewItem } from 'warding-api';

/**
 * 작성일 기준 `YYYY.MM.DD` 로 묶는다 — Flutter
 * `my_review_ui_state.dart` 의 `groupByCreatedDate` 와 같다.
 *
 * **삽입 순서(최신 우선)를 유지한다.** JS `Map` 도 Dart `LinkedHashMap` 과
 * 같이 넣은 순서를 지키므로 정렬을 따로 하지 않는다 — 서버가 이미 최신순으로
 * 준다.
 *
 * 작성일이 없으면 `-` 로 묶는다(Dart 와 같은 키).
 */
export function groupByDate(
  items: MyReviewItem[],
): Map<string, MyReviewItem[]> {
  const map = new Map<string, MyReviewItem[]>();
  for (const item of items) {
    const key = dateKey(item.createdAt);
    const bucket = map.get(key);
    if (bucket === undefined) map.set(key, [item]);
    else bucket.push(item);
  }
  return map;
}

function dateKey(createdAt: Date | null): string {
  if (createdAt === null) return '-';
  const m = String(createdAt.getMonth() + 1).padStart(2, '0');
  const d = String(createdAt.getDate()).padStart(2, '0');
  return `${createdAt.getFullYear()}.${m}.${d}`;
}
