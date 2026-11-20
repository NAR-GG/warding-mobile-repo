import type { UploadSignature } from 'warding-api';

/**
 * 서명을 들고 Cloudinary 에 **브라우저가 직접** 올린다.
 *
 * 필드 구성은 Flutter `community_image_repository.dart` 와 같다 — `api_key`·
 * `timestamp`·`public_id`·`overwrite`·`signature` + 파일. 서버가 서명을 그
 * 조합으로 만들었으므로 하나라도 빠지거나 더하면 서명이 틀어진다.
 *
 * CORS 설정은 필요 없다 — Cloudinary 가 임의 Origin 을 반사한다(실측
 * 2026-11-20: preflight 200).
 *
 * 돌려주는 것은 `secure_url` 이고, 글 작성 때 `imageUrls` 로 보낸다.
 */
export async function uploadToCloudinary(
  sig: UploadSignature,
  file: Blob,
  filename = 'image.jpg',
): Promise<string> {
  const form = new FormData();
  form.append('api_key', sig.apiKey);
  form.append('timestamp', String(sig.timestamp));
  form.append('public_id', sig.publicId);
  form.append('overwrite', String(sig.overwrite));
  form.append('signature', sig.signature);
  form.append('file', file, filename);

  const res = await fetch(sig.uploadUrl, { method: 'POST', body: form });
  if (!res.ok) {
    throw new Error(`Cloudinary 업로드 실패 (${res.status})`);
  }

  const json: unknown = await res.json();
  const url =
    typeof json === 'object' && json !== null && 'secure_url' in json
      ? (json as { secure_url?: unknown }).secure_url
      : undefined;

  if (typeof url !== 'string' || url === '') {
    throw new Error('Cloudinary 응답에 secure_url 이 없다');
  }
  return url;
}
