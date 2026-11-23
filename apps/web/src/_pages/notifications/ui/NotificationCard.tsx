import type { MemberNotification } from 'warding-api';

import { toView } from '../lib/present';

/**
 * 알림 카드 — Flutter `features/subscription/presentation/widgets/
 * notification_card.dart` 의 웹 구현.
 *
 * **`widgets` 가 아니라 이 화면 안에 있다.** 네이티브는 알림함과 마이구독
 * 피드가 같은 카드를 쓰지만 웹은 아직 알림함뿐이라, 올려 두면 린터가
 * "참조가 하나뿐인 슬라이스" 로 잡는다. 마이구독이 웹으로 오면 그때
 * `widgets/` 로 올린다.
 *
 * 수치는 Dart 와 맞춘다 — 배경 `nar-bg-secondary`, 패딩 20, 아이콘 44,
 * gap 16, 제목 15/w600 **한 줄 말줄임**, 본문 13/1.45, 시각 12.
 *
 * **제목이 한 줄 고정인 이유도 Dart 그대로다.** 긴 닉네임·팀명에서 2줄로
 * 접히면 카드가 무겁고, 잘린 내용은 본문·상세가 보완한다.
 *
 * **안 읽은 알림은 보라 틴트 + 좌측 점으로만 구분한다**(인스타 방식).
 * 카드가 자체 배경을 칠하므로 틴트는 카드 **위**에 얹는다 — 밑에 깔면
 * 완전히 가려진다.
 */
export function NotificationCard({
  notification,
  now,
}: {
  notification: MemberNotification;
  /** 상대 시각 기준. 서버에서 한 번 정해 넘긴다 — 항목마다 `new Date()`
   *  를 부르면 같은 렌더 안에서 기준이 흔들린다. */
  now: Date;
}) {
  const v = toView(notification, now);

  return (
    <article className="noti-card">
      {/* **`<img>` 가 아니라 CSS 마스크다.** 네이티브는 `ColorFilter` 로
          아이콘을 전부 `narText` 한 색으로 칠하는데, svg 원본의 stroke 가
          파일마다 다르다(white·#373A40·#CED4DA). `<img>` 는 그 색을 바꿀
          수 없어 3개가 다른 색으로 나온다 — 마스크로 모양만 쓰고 색은
          배경으로 칠한다. */}
      <span className="noti-card__icon-box">
        <span
          className="noti-card__icon"
          aria-hidden="true"
          style={{
            width: `calc(${v.iconSize} * var(--scale))`,
            height: `calc(${v.iconSize} * var(--scale))`,
            maskImage: `url(${v.icon})`,
            WebkitMaskImage: `url(${v.icon})`,
          }}
        />
      </span>

      <div className="noti-card__text">
        <h3 className="noti-card__title">{v.title}</h3>
        <p className="noti-card__body">{v.body}</p>
        <p className="noti-card__time">
          <time dateTime={notification.createdAt.toISOString()}>{v.absolute}</time>
          <span>{v.relative}</span>
        </p>
      </div>

      {notification.read ? null : (
        <>
          <span className="noti-card__tint" aria-hidden="true" />
          <span className="noti-card__dot" aria-hidden="true" />
        </>
      )}
    </article>
  );
}
