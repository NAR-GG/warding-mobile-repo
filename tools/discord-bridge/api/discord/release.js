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
import {
  readRawBody,
  sendText,
  sendStatus,
  sendJson,
  dispatch,
  respondThenRun,
} from '../../lib/http.js';
import { claimOnce, interactionKey } from '../../lib/once.js';

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

  const isComponent = interaction.type === InteractionType.MESSAGE_COMPONENT;
  const isModal = interaction.type === InteractionType.MODAL_SUBMIT;
  if (!isComponent && !isModal) {
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

    // 응답을 먼저 보낸다. dispatch 를 먼저 await 하다가 3초를 넘기면 Discord 가
    // 재시도하고, 재시도마다 제출이 한 번씩 더 나간다(2026-10-27 중복 제출).
    respondThenRun(res, interaction, { ephemeral: true }, async () => {
      // 재시도가 이미 통과했다면 여기서 멈춘다. 콜드 스타트가 3초를 먹으면
      // 응답을 먼저 보내도 재시도가 올 수 있어, 이 가드가 최종 방어선이다.
      if (!(await claimOnce(interactionKey(interaction, 'rel_confirm')))) {
        return `ℹ️ **${version}** 제출은 이미 접수됐어요. (중복 요청은 무시합니다)`;
      }

      await dispatch('release-submit', {
        version,
        platform: 'both',
        releaseNotes,
        requestedBy: user,
      });

      return (
        `✅ **${version}** 심사 제출을 시작했어요. (요청: ${user})\n` +
        (releaseNotes
          ? '패치노트 초안을 distribution/ 에 반영하고 제출합니다.'
          : 'distribution/ 에 있는 패치노트 그대로 제출합니다.')
      );
    });
    return;
  }

  // ── [수정] 패치노트를 Discord 안에서 고친다 ─────────────────────────────
  // 레포에 PR 을 올렸다 머지하고 돌아올 필요 없이, 초안을 그 자리에서 손본다.
  // 모달 입력창에 현재 초안을 미리 채워 두고(value), 고친 내용을 그대로 쓴다.
  if (customId.startsWith('rel_edit:')) {
    const version = parseVersion(customId.slice('rel_edit:'.length));
    if (!version) return badVersion();

    const current = extractReleaseNotes(interaction.message) ?? '';
    sendJson(res, 200, {
      type: InteractionResponseType.MODAL,
      data: {
        // MODAL_SUBMIT 에는 원본 메시지가 딸려 오지 않을 수 있어서, 버전을
        // custom_id 에 실어 보낸다.
        custom_id: `rel_notes_modal:${version}`,
        title: `${version} 패치노트`,
        components: [
          {
            type: 1,
            components: [
              {
                type: 4,
                custom_id: 'notes',
                label: '스토어에 올릴 패치노트',
                style: 2, // paragraph
                required: true,
                // Play 가 500자 제한이라 여기서 먼저 막는다.
                max_length: 500,
                value: current,
              },
            ],
          },
        ],
      },
    });
    return;
  }

  // 모달에서 고친 패치노트로 제출한다. 모달 자체가 '수정하겠다'는 의사 표시라
  // 여기서 확인을 한 번 더 받는다(버튼 흐름과 같은 2단계).
  if (isModal && customId.startsWith('rel_notes_modal:')) {
    const version = parseVersion(customId.slice('rel_notes_modal:'.length));
    if (!version) return badVersion();

    const notes = interaction.data?.components?.[0]?.components?.[0]?.value ?? '';
    if (!notes.trim()) {
      sendJson(res, 200, {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: { content: '❌ 패치노트가 비어 있어요.', flags: 64 },
      });
      return;
    }

    // 버튼 경로와 같은 이유로 응답을 먼저 보낸다 (lib/once.js 참고).
    // 모달 결과는 채널에 보이는 편이 자연스러워 ephemeral 을 끈다.
    respondThenRun(res, interaction, { ephemeral: false }, async () => {
      if (!(await claimOnce(interactionKey(interaction, 'rel_notes_modal')))) {
        return `ℹ️ **${version}** 제출은 이미 접수됐어요. (중복 요청은 무시합니다)`;
      }

      await dispatch('release-submit', {
        version,
        platform: 'both',
        releaseNotes: notes,
        requestedBy: user,
      });

      return (
        `✅ **${version}** 을 고친 패치노트로 제출했어요. (요청: ${user})\n` +
        '```\n' + notes.slice(0, 1800) + '\n```'
      );
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
