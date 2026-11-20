'use server';

import type { UploadSignature } from 'warding-api';
import { createPost, fetchUploadSignature } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';

export type WriteResult<T> =
  | { kind: 'ok'; value: T }
  | { kind: 'unauthorized' }
  | { kind: 'failed' };

/**
 * Cloudinary 업로드 서명을 받아 브라우저에 넘긴다.
 *
 * **파일은 이 서버를 거치지 않는다.** 브라우저가 서명을 들고 Cloudinary 로
 * 직접 올린다 — Next Server Action 의 본문 한도(기본 1MB)와 Vercel Functions
 * 한도(4.5MB)를 아예 비껴간다. 폰 사진은 장당 3~5MB 라 중계하면 바로 걸린다.
 *
 * 서명에 `api_secret` 은 들어 있지 않다. 노출되는 것은 `apiKey`·`signature`
 * 뿐이고, 이는 Flutter 앱도 똑같이 들고 있는 값이다.
 */
export async function signUploadAction(): Promise<WriteResult<UploadSignature>> {
  const token = await readAuthToken();
  if (token === null) return { kind: 'unauthorized' };

  const r = await fetchUploadSignature({ token });
  if (!r.ok) {
    return r.failure.kind === 'unauthorized'
      ? { kind: 'unauthorized' }
      : { kind: 'failed' };
  }
  return { kind: 'ok', value: r.value };
}

/**
 * 글 등록.
 *
 * 사진은 이미 Cloudinary 에 올라간 뒤라 URL 만 싣는다 — Flutter 의 선업로드와
 * 같은 구조다(사진 고르는 즉시 올려서 등록은 한 번에 끝낸다).
 */
export async function createPostAction({
  title,
  body,
  bodyFormat = 'PLAIN',
  imageUrls,
}: {
  title: string;
  body: string;
  /** 'BLOCKS' 면 `body` 가 블록 JSON 문자열이다. */
  bodyFormat?: string;
  imageUrls: string[];
}): Promise<WriteResult<number>> {
  const t = title.trim();
  const b = body.trim();
  // 서버도 막지만 왕복을 아낀다. 버튼이 비활성이라 정상 경로로는 오지 않는다.
  // 블록 본문은 사진만 있어도 성립하므로 빈 배열(`[]`)만 거른다.
  if (t === '') return { kind: 'failed' };
  if (bodyFormat === 'BLOCKS' ? b === '[]' : b === '') return { kind: 'failed' };

  const token = await readAuthToken();
  if (token === null) return { kind: 'unauthorized' };

  const r = await createPost({ title: t, body: b, bodyFormat, imageUrls }, { token });
  if (!r.ok) {
    return r.failure.kind === 'unauthorized'
      ? { kind: 'unauthorized' }
      : { kind: 'failed' };
  }
  return { kind: 'ok', value: r.value };
}
