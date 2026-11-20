'use client';

import { isHeading, type PostBlock } from 'warding-api';

import { cloudinaryScaled } from '@/shared/lib';

import { openPhotoViewer } from '@/shared/bridge';

/**
 * 블록 본문 렌더러 — Flutter `post_block_renderer.dart` 의 웹 구현.
 *
 * **`images` 배열이 아니라 `body` 블록을 그린다.** 두 곳에 같은 이미지가 오는데
 * 둘 다 그리면 사진이 두 번 나온다(실측으로 겪었다). Flutter 도 블록만 쓴다.
 *
 * 모르는 타입은 건너뛴다 — 서버가 블록 타입을 추가해도 화면이 안 깨진다.
 */
export function PostBody({ blocks }: { blocks: PostBlock[] }) {
  if (blocks.length === 0) return null;

  // 사진 뷰어에 넘길 전체 목록. 네이티브가 좌우 스와이프로 넘기므로
  // 탭한 한 장이 아니라 글 전체의 이미지를 준다(Flutter 도 같다).
  const imageUrls = blocks
    .filter((b) => b.type === 'image' && b.url)
    .map((b) => b.url as string);

  return (
    <div className="post__body">
      {blocks.map((b, i) => {
        const key = `${b.type}-${i}`;

        if (b.type === 'text') {
          return isHeading(b) ? (
            <h2 key={key} className="post__heading">
              {b.text ?? ''}
            </h2>
          ) : (
            <p key={key} className="post__text">
              {b.text ?? ''}
            </p>
          );
        }

        if (b.type === 'image' && b.url) {
          const at = imageUrls.indexOf(b.url);
          return (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              key={key}
              src={cloudinaryScaled(b.url, 800)}
              alt=""
              className="post__image"
              onClick={() => {
                // 웹뷰 밖에서는 브리지가 없어 거부된다 — 그때는 아무 일도
                // 일어나지 않는 편이 낫다. 웹 자체 뷰어를 만들면 네이티브와
                // 동작이 갈린다.
                void openPhotoViewer(imageUrls, at < 0 ? 0 : at).catch(() => {});
              }}
            />
          );
        }

        if ((b.type === 'link' || b.type === 'embed') && b.url) {
          // Flutter v1 은 탭하면 외부 브라우저로 연다. 웹은 그냥 링크다.
          return (
            <a
              key={key}
              className="post__link"
              href={b.url}
              target="_blank"
              rel="noreferrer noopener"
            >
              {b.imageUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={cloudinaryScaled(b.imageUrl, 128)} alt="" className="post__link-thumb" />
              ) : null}
              <span className="post__link-text">
                <span className="post__link-title">{b.title ?? b.url}</span>
                {b.description ? (
                  <span className="post__link-desc">{b.description}</span>
                ) : null}
                {b.siteName ? (
                  <span className="post__link-site">{b.siteName}</span>
                ) : null}
              </span>
            </a>
          );
        }

        return null;
      })}
    </div>
  );
}
