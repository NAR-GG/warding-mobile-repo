import {
  type Json,
  boolOr,
  date,
  isObject,
  list,
  numOr,
  str,
  strOr,
} from '../json';
import type { Notice, NoticePage } from './types';

/** 공백만 있는 문자열은 값이 아니다 — Dart `Notice._nonBlank` 과 같다. */
function nonBlank(v: unknown): string | null {
  const s = str(v);
  if (s === null) return null;
  const t = s.trim();
  return t === '' ? null : t;
}

export function toNotice(json: Json): Notice {
  return {
    id: numOr(json.id, 0),
    title: strOr(json.title, ''),
    content: strOr(json.content, ''),
    pinned: boolOr(json.pinned, false),
    publishedAt: date(json.publishedAt),
    actionUrl: nonBlank(json.actionUrl),
  };
}

export function toNoticePage(json: unknown): NoticePage {
  if (!isObject(json)) throw new TypeError('NoticePage: 객체가 아니다');
  return {
    notices: list(json.content, toNotice),
    // 마지막 페이지 여부를 모르면 더 불러오지 않는 쪽이 안전하다 —
    // 잘못 true 로 보면 멈추지만, false 로 보면 무한히 요청한다.
    last: boolOr(json.last, true),
    totalElements: numOr(json.totalElements, 0),
  };
}
