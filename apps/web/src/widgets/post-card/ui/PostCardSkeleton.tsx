/**
 * 목록 카드 스켈레톤 — Flutter `post_list_item_skeleton.dart` 의 웹 구현.
 *
 * **SSR 이라 서버가 글을 받을 때까지 화면에 아무것도 없다.** 네이티브는 탭을
 * 누르는 즉시 스켈레톤을 그리는데, 웹뷰는 그 사이 멈춘 것처럼 보인다 —
 * 실제로 "너무 늦게 이동된다" 는 피드백을 받았다.
 *
 * `PostCard` 와 **같은 패딩·구분선**을 쓴다. 실데이터로 바뀔 때 목록이
 * 튀지 않아야 한다(Dart 주석과 같은 이유).
 */
export function PostCardSkeleton() {
  return (
    <li className="post-item">
      <div className="post-item__link">
        <div className="post-item__main">
          <div className="skeleton skeleton--title" />
          <div className="skeleton skeleton--line" />
          <div className="skeleton skeleton--line skeleton--short" />
          <div className="skeleton skeleton--meta" />
        </div>
        <div className="skeleton skeleton--thumb" />
      </div>
    </li>
  );
}

/** 목록 한 화면 분량. 6개는 Dart 와 같은 수다. */
export function PostListSkeleton() {
  return (
    <main>
      <ul className="post-list">
        {Array.from({ length: 6 }, (_, i) => (
          <PostCardSkeleton key={i} />
        ))}
      </ul>
    </main>
  );
}
