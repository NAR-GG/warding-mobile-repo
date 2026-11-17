import { headers } from 'next/headers';

/**
 * 스캐폴드 확인용 루트. 실제 전환 대상은 `/community/post/[id]` 다.
 *
 * SSR 이 실제로 도는지(서버에서 HTML 이 완성되는지) 눈으로 확인하려고
 * 요청 시각을 서버에서 찍는다.
 */
export default async function Home() {
  const h = await headers();
  return (
    <main style={{ padding: `calc(20 * var(--scale) * 1px)` }}>
      <h1 style={{ fontSize: `calc(20 * var(--scale) * 1px)` }}>Warding Web</h1>
      <p style={{ marginTop: `calc(12 * var(--scale) * 1px)`, color: 'var(--color-nar-text2)' }}>
        서버 렌더 시각 {new Date().toISOString()}
      </p>
      <p style={{ marginTop: `calc(4 * var(--scale) * 1px)`, color: 'var(--color-nar-text2)' }}>
        UA {h.get('user-agent')?.slice(0, 60) ?? '-'}
      </p>
    </main>
  );
}
