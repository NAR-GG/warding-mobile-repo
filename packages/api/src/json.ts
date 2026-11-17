/**
 * JSON 값을 안전하게 꺼내는 헬퍼.
 *
 * Flutter 의 `(json['x'] as num?)?.toInt() ?? 0` 패턴을 그대로 옮긴 것이다 —
 * 서버가 타입을 바꿔 보내거나 필드를 빼도 화면이 터지지 않게 한다.
 * `as` 캐스팅으로 넘기면 TS 는 컴파일만 통과시키고 런타임에 undefined 가
 * 그대로 흘러간다.
 */

export type Json = Record<string, unknown>;

export const isObject = (v: unknown): v is Json =>
  typeof v === 'object' && v !== null && !Array.isArray(v);

/** 숫자로 읽는다. 숫자형이 아니거나 NaN 이면 null. */
export function num(v: unknown): number | null {
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  // 서버가 큰 정수를 문자열로 주는 경우가 있다(int64).
  if (typeof v === 'string' && v.trim() !== '') {
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

export const numOr = (v: unknown, fallback: number): number => num(v) ?? fallback;

/** 문자열로 읽는다. 빈 문자열도 값으로 본다(의도적 공백일 수 있다). */
export function str(v: unknown): string | null {
  return typeof v === 'string' ? v : null;
}

export const strOr = (v: unknown, fallback: string): string => str(v) ?? fallback;

export function bool(v: unknown): boolean | null {
  return typeof v === 'boolean' ? v : null;
}

export const boolOr = (v: unknown, fallback: boolean): boolean => bool(v) ?? fallback;

/** ISO 문자열 → Date. 형식이 틀리면 null (Dart `DateTime.tryParse` 와 같다). */
export function date(v: unknown): Date | null {
  const s = str(v);
  if (s === null || s.trim() === '') return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** 배열을 매핑한다. 배열이 아니면 빈 배열 — 목록이 null 이어도 화면은 그려진다. */
export function list<T>(v: unknown, map: (item: Json) => T): T[] {
  if (!Array.isArray(v)) return [];
  return v.filter(isObject).map(map);
}

/** 숫자 배열. id 목록처럼 원시값이 들어오는 경우용. */
export function numList(v: unknown): number[] {
  if (!Array.isArray(v)) return [];
  return v.map(num).filter((n): n is number => n !== null);
}

/** 중첩 객체. 객체가 아니면 null. */
export function obj<T>(v: unknown, map: (json: Json) => T): T | null {
  return isObject(v) ? map(v) : null;
}
