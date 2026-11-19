import type { Poll } from 'warding-api';

/**
 * 투표 카드 — Flutter `features/community/presentation/widgets/poll_card.dart`
 * 의 웹 구현. **지금은 결과 표시 전용이다**(투표하기는 다음 단계).
 *
 * **분포는 `resultsVisible` 일 때만 그린다.** 비공개면 서버가 `voteCount` 를
 * 주지 않는데(null), 0 으로 메우면 "0표" 로 보여 실제로 아무도 안 고른 것과
 * 구분이 안 된다 — 매퍼가 null 을 유지하는 이유이기도 하다.
 *
 * 푸터 문구 조합은 Dart `_footer` 와 같다 —
 * "N명 참여 · 복수 선택 · X 후 마감 / 마감됨 · 투표하면 결과를 볼 수 있어요".
 */
export function PollCard({ poll }: { poll: Poll }) {
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

          return (
            <li
              key={option.id}
              className={mine ? 'poll__option poll__option--mine' : 'poll__option'}
            >
              {/* 막대는 배경에 깔고 글자는 그 위에 둔다. 폭을 인라인으로 주는
                  이유는 비율이 데이터라서다 — CSS 로는 표현할 수 없다. */}
              <span className="poll__bar" style={{ width: `${ratio * 100}%` }} />
              <span className="poll__label">{option.label}</span>
              {poll.resultsVisible && option.voteCount !== null ? (
                <span className="poll__count">{option.voteCount}</span>
              ) : null}
            </li>
          );
        })}
      </ul>

      <p className="poll__footer">{footer(poll)}</p>
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
