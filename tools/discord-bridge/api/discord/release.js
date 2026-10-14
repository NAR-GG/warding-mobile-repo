// 배포 전용 Discord 봇 엔드포인트.
//
// `/intent` 를 처리하는 interactions.js 와 **앱이 다르다.** Discord 는 앱마다
// 서명 검증 공개키가 다르므로 엔드포인트를 나눠야 한다 — 한 파일에서 두 앱을
// 검증하면 어느 앱에서 온 요청인지 흐려진다.
//
// 배포 봇은 버튼만 처리한다. 슬래시 명령이 없어 MESSAGE_COMPONENT 와 PING 만
// 받는다.
//
// 설계 배경은 intent/discord-release-approval/spec.md 참고.

import { verifyKey, InteractionType, InteractionResponseType } from 'discord-interactions';
import { readRawBody, sendText, sendStatus, sendJson, dispatch } from '../../lib/http.js';

export const config = { api: { bodyParser: false } };

/** `1.0.33+81` 형식만 통과시킨다. custom_id 는 Discord 를 거쳐 돌아오는 외부 입력이다. */
export function parseVersion(raw) {
  return /^\d+\.\d+\.\d+\+\d+$/.test(raw ?? '') ? raw : null;
}

/**
 * 릴리즈 알림 메시지의 embed 에서 패치노트를 꺼낸다.
 * 워크플로우가 두 번째 embed 에 초안을 싣는다. 없으면 null 이고, 그 경우
 * 받는 쪽이 "distribution/ 에 있는 내용 그대로 제출"로 처리한다.
 */
export function extractReleaseNotes(message) {
  const embed = message?.embeds?.find((e) => (e.title ?? '').includes('패치노트'));
  const body = embed?.description ?? '';
  // user_facing=false 일 때 워크플로우가 넣는 안내 문구는 패치노트가 아니다.
  if (!body || !body.includes('■')) return null;
  return body;
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    sendStatus(res, 405);
    return;
  }

  const rawBody = await readRawBody(req);
  const isValid = await verifyKey(
    rawBody,
    req.headers['x-signature-ed25519'],
    req.headers['x-signature-timestamp'],
    process.env.DISCORD_RELEASE_PUBLIC_KEY
  );
  if (!isValid) {
    sendText(res, 401, 'invalid request signature');
    return;
  }

  const interaction = JSON.parse(rawBody.toString('utf8'));

  if (interaction.type === InteractionType.PING) {
    sendJson(res, 200, { type: InteractionResponseType.PONG });
    return;
  }

  if (interaction.type !== InteractionType.MESSAGE_COMPONENT) {
    sendText(res, 400, 'unhandled interaction type');
    return;
  }

  const customId = interaction.data?.custom_id ?? '';
  const user = interaction.member?.user?.username ?? interaction.user?.username ?? 'unknown';

  const badVersion = () =>
    sendJson(res, 200, {
      type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
      data: { content: '❌ 버전 형식이 올바르지 않아요.', flags: 64 },
    });

  // ── [1단계] 제출 의사 → 확인 버튼을 띄운다 ──────────────────────────────
  // 심사 제출은 되돌릴 수 없고 Discord 버튼은 누르기 쉬워서, 한 번 더 묻는다.
  if (customId.startsWith('rel_submit:')) {
    const version = parseVersion(customId.slice('rel_submit:'.length));
    if (!version) return badVersion();

    sendJson(res, 200, {
      type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
      data: {
        content: `⚠️ **${version}** 을 심사에 제출합니다.\n되돌릴 수 없어요. 정말 진행할까요?`,
        // flags 64 = ephemeral. 누른 사람에게만 보여 채널을 어지럽히지 않는다.
        flags: 64,
        components: [
          {
            type: 1,
            components: [
              {
                type: 2,
                style: 4, // danger
                label: '네, 제출합니다',
                custom_id: `rel_confirm:${version}`,
              },
            ],
          },
        ],
      },
    });
    return;
  }

  // ── [2단계] 확정 → 실제로 dispatch ──────────────────────────────────────
  if (customId.startsWith('rel_confirm:')) {
    const version = parseVersion(customId.slice('rel_confirm:'.length));
    if (!version) return badVersion();

    // 확인 버튼은 ephemeral 메시지에 붙어 있다. Discord 는 그 메시지를
    // interaction.message 로 주는데, 거기엔 패치노트가 없다 — 원본 릴리즈
    // 알림에만 있다. 그래서 패치노트를 못 찾으면 null 로 두고, 받는 쪽이
    // distribution/ 에 이미 있는 내용으로 제출한다.
    const releaseNotes = extractReleaseNotes(interaction.message);

    const err = await dispatch('release-submit', {
      version,
      platform: 'both',
      releaseNotes,
      requestedBy: user,
    }).catch((e) => e);

    if (err) {
      console.error('[release-bot] dispatch failed', err);
      sendJson(res, 200, {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: { content: '❌ 제출 실패 — GitHub 연동 중 오류가 났어요.', flags: 64 },
      });
      return;
    }

    sendJson(res, 200, {
      type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
      data: {
        content:
          `✅ **${version}** 심사 제출을 시작했어요. (요청: ${user})\n` +
          (releaseNotes
            ? '패치노트 초안을 distribution/ 에 반영하고 제출합니다.'
            : 'distribution/ 에 있는 패치노트 그대로 제출합니다.'),
      },
    });
    return;
  }

  if (customId === 'rel_cancel') {
    sendJson(res, 200, {
      type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
      data: { content: '취소했어요. 심사에 올리지 않았습니다.', flags: 64 },
    });
    return;
  }

  sendText(res, 400, 'unhandled component');
}
