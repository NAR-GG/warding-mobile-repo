'use client';

import { useState } from 'react';
import type { Poll } from 'warding-api';

import { voteAction } from '../api/actions';

/**
 * 투표 카드 — Flutter `features/community/presentation/widgets/poll_card.dart`
 * 의 웹 구현.
 *
 * **분포는 `resultsVisible` 일 때만 그린다.** 비공개면 서버가 `voteCount` 를
 * 주지 않는데(null), 0 으로 메우면 "0표" 로 보여 실제로 아무도 안 고른 것과
 * 구분이 안 된다 — 매퍼가 null 을 유지하는 이유이기도 하다.
 *
 * **투표하면 서버가 상태를 통째로 돌려주므로 그 값으로 교체한다.** 분포가 막
 * 공개되는 경우(투표 뒤에 `resultsVisible` 이 켜진다)까지 한 번에 반영된다 —
 * 낙관적 업데이트를 하면 그 전환을 손으로 흉내내야 한다.
 *
 * 푸터 문구 조합은 Dart `_footer` 와 같다 —
 * "N명 참여 · 복수 선택 · X 후 마감 / 마감됨 · 투표하면 결과를 볼 수 있어요".
 */
export function PollCard({ postId, poll: initial }: { postId: number; poll: Poll }) {
  const [poll, setPoll] = useState(initial);
  const [pending, setPending] = useState<number | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  // 하나라도 골랐으면 투표한 것이다. Dart `voted` 와 같은 파생이다.
  const voted = poll.myOptionIds.length > 0;

  /**
   * 이 선택지를 지금 누를 수 있는가 — Dart `_canVote` 와 같은 규칙이다.
   * 마감 전이고, 복수 선택이면 아직 안 고른 것, 단일 선택이면 아예 미투표.
   */
  function canVote(optionId: number): boolean {
    if (poll.closed) return false;
    return poll.allowMultiple ? !poll.myOptionIds.includes(optionId) : !voted;
  }

  async function onVote(optionId: number) {
    if (!canVote(optionId) || pending !== null) return;

    setPending(optionId);
    setNotice(null);

    const r = await voteAction(postId, optionId);
    setPending(null);

    if (r.kind === 'unauthorized') {
      setNotice('로그인이 필요합니다');
      return;
    }
    if (r.kind === 'failed') {
      setNotice('투표하지 못했어요. 잠시 후 다시 시도해 주세요');
      return;
    }
    // 서버가 돌려준 상태로 통째로 교체한다.
    setPoll(r.value);
  }

  return (
    <section className="poll">
      <h2 className="poll__question">{poll.question}</h2>

      <ul className="poll__options">
        {poll.options.map((option) => {
          const mine = poll.myOptionIds.includes(option.id);
          // 분포 공개 + 표가 있을 때만 비율을 낸다. 셋 중 하나라도 어긋나면
          // 막대를 그리지 않는다(Dart 의 ratio 조건과 같다).
          const ratio =
            poll.resultsVisible && poll.totalVotes > 0 && option.voteCount !== null
              ? option.voteCount / poll.totalVotes
              : 0;
          const tappable = canVote(option.id);

          const inner = (
            <>
              {/* 막대는 배경에 깔고 글자는 그 위에 둔다. 폭을 인라인으로 주는
                  이유는 비율이 데이터라서다 — CSS 로는 표현할 수 없다. */}
              <span className="poll__bar" style={{ width: `${ratio * 100}%` }} />
              <span className="poll__label">{option.label}</span>
              {poll.resultsVisible && option.voteCount !== null ? (
                <span className="poll__count">{option.voteCount}</span>
              ) : null}
            </>
          );

          return (
            <li
              key={option.id}
              className={mine ? 'poll__option poll__option--mine' : 'poll__option'}
            >
              {/* 누를 수 없을 때는 버튼으로 만들지 않는다 — 비활성 버튼이
                  남아 있으면 누를 수 있어 보인다. */}
              {tappable ? (
                <button
                  type="button"
                  className="poll__hit"
                  onClick={() => void onVote(option.id)}
                  disabled={pending !== null}
                >
                  {inner}
                </button>
              ) : (
                inner
              )}
            </li>
          );
        })}
      </ul>

      <p className="poll__footer">{footer(poll)}</p>
      {notice === null ? null : <p className="poll__notice">{notice}</p>}
    </section>
  );
}

function footer(poll: Poll): string {
  const parts = [`${poll.totalVotes}명 참여`];
  if (poll.allowMultiple) parts.push('복수 선택');

  if (poll.closed) {
    parts.push('마감됨');
  } else if (poll.closesAt !== null) {
    parts.push(`${remaining(poll.closesAt)} 후 마감`);
  }

  if (!poll.resultsVisible) parts.push('투표하면 결과를 볼 수 있어요');
  return parts.join(' · ');
}

/** 남은 시간. 1시간 미만은 "1시간" 으로 뭉갠다(Dart `_remaining` 과 같다). */
function remaining(closesAt: Date): string {
  const ms = closesAt.getTime() - Date.now();
  const hours = Math.floor(ms / 3_600_000);
  if (hours >= 24) return `${Math.floor(hours / 24)}일`;
  if (hours >= 1) return `${hours}시간`;
  return '1시간';
}
