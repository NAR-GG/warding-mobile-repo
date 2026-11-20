/**
 * Cloudinary 업로드 URL 에 표시용 변환을 끼운다 — Flutter
 * `core/util/app_image.dart` 의 `cloudinaryScaled` 를 복제한 것이다.
 *
 * **서버는 변환 없는 `secure_url` 을 그대로 저장한다**(원본 보존). 그래서 그
 * URL 을 그대로 쓰면 아이폰 원본(4032×3024, 수백 KB~수 MB)을 받아 62px 칸에
 * 그리게 된다 — Dart 주석이 같은 사고를 적어 뒀고, 웹도 똑같이 겪었다
 * (실측 2026-11-20: 목록 썸네일 141KB → 변환 후 6.6KB, **21배**).
 *
 * 폭을 버킷으로 끊는 이유는 **CDN 캐시 적중률**이다. 기기 폭마다 다른 URL 을
 * 만들면 변환본이 사용자 수만큼 생겨 첫 요청이 매번 느리다.
 */

/** 폭 버킷. Dart `kCloudinaryWidthBuckets` 와 같은 값이다. */
const WIDTH_BUCKETS = [200, 400, 800, 1200];

/**
 * 표시 폭(CSS px)과 기기 픽셀 비율로 변환 URL 을 만든다.
 *
 * Cloudinary 업로드 URL 이 아니거나 **이미 변환이 끼어 있으면 그대로 둔다** —
 * 버전 세그먼트(`v123.../`)로 시작해야 변환 없는 원본이다.
 */
export function cloudinaryScaled(url: string, targetPixelWidth: number): string {
  const marker = '/image/upload/';
  const at = url.indexOf(marker);
  if (at < 0 || !url.startsWith('https://res.cloudinary.com/')) return url;

  const rest = url.slice(at + marker.length);
  if (!/^v\d+\//.test(rest)) return url;

  const width =
    WIDTH_BUCKETS.find((b) => b >= targetPixelWidth) ??
    WIDTH_BUCKETS[WIDTH_BUCKETS.length - 1]!;

  return `${url.slice(0, at + marker.length)}f_webp,q_auto,w_${width},c_limit/${rest}`;
}
