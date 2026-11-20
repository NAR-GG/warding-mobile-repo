/**
 * 글 상세 스켈레톤 — Flutter `post_detail_skeleton.dart` 의 웹 구현.
 *
 * 본문 자리만 비운다. 목록에서 글을 눌렀을 때 화면이 멈춘 것처럼 보이지
 * 않게 하는 것이 목적이라, 모양을 정확히 흉내 내지는 않는다.
 */
export function PostDetailSkeleton() {
  return (
    <article className="post">
      <div className="skeleton skeleton--meta" />
      <div className="skeleton skeleton--title" />
      <div className="skeleton skeleton--line" />
      <div className="skeleton skeleton--line" />
      <div className="skeleton skeleton--line skeleton--short" />
    </article>
  );
}
