import { verifyKey, InteractionType, InteractionResponseType } from 'discord-interactions';
import { slugify } from '../../lib/slugify.js';

// NOTE: this `config` export is a Next.js-only convention and has no effect on
// Vercel's plain Node.js functions. Raw-body parsing (required for Discord
// signature verification) is actually disabled via the NODEJS_HELPERS=0
// environment variable on the Vercel project. Kept here as a harmless no-op /
// documentation marker.
export const config = { api: { bodyParser: false } };

async function readRawBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return Buffer.concat(chunks);
}

// Vercel의 Node.js Function 런타임은 ESM(`"type": "module"`) 핸들러에는
// Express 스타일 `res.status()/.json()` 헬퍼를 붙여주지 않는다(CommonJS
// 핸들러에만 적용됨) — 순수 `http.ServerResponse` API로 대체한다.
function sendStatus(res, status) {
  res.statusCode = status;
  res.end();
}

function sendText(res, status, text) {
  res.statusCode = status;
  res.end(text);
}

function sendJson(res, status, body) {
  res.statusCode = status;
  res.setHeader('content-type', 'application/json');
  res.end(JSON.stringify(body));
}

async function dispatchIntentRequest({ slug, description, requestedBy }) {
  const res = await fetch(
    `https://api.github.com/repos/${process.env.GITHUB_REPO}/dispatches`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.DISPATCH_TOKEN}`,
        Accept: 'application/vnd.github+json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        event_type: 'intent-request',
        client_payload: { slug, description, requestedBy, source: 'discord' },
      }),
    }
  );
  if (!res.ok) {
    throw new Error(`repository_dispatch 실패: ${res.status} ${await res.text()}`);
  }
}

async function dispatchReleaseSubmit({ version, platform, releaseNotes, requestedBy }) {
  const res = await fetch(
    `https://api.github.com/repos/${process.env.GITHUB_REPO}/dispatches`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.DISPATCH_TOKEN}`,
        Accept: 'application/vnd.github+json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        event_type: 'release-submit',
        client_payload: { version, platform, releaseNotes, requestedBy, source: 'discord' },
      }),
    }
  );
  if (!res.ok) {
    throw new Error(`repository_dispatch 실패: ${res.status} ${await res.text()}`);
  }
}

/** `1.0.33+81` 형식만 통과시킨다. custom_id 는 우리가 만든 값이지만 그대로 믿지 않는다. */
export function parseVersion(raw) {
  return /^\d+\.\d+\.\d+\+\d+$/.test(raw ?? '') ? raw : null;
}

/**
 * 릴리즈 알림 메시지의 embed 에서 패치노트를 꺼낸다.
 * 워크플로우가 두 번째 embed 에 초안을 싣는다 — 없으면 null 이고, 그 경우
 * 호출하는 쪽이 "distribution/ 에 있는 내용 그대로 제출"로 처리한다.
 */
export function extractReleaseNotes(message) {
  const embed = message?.embeds?.find((e) => (e.title ?? '').includes('패치노트'));
  const body = embed?.description ?? '';
  // 초안이 없을 때 워크플로우가 넣는 안내 문구는 패치노트가 아니다.
  if (!body || !body.includes('■')) return null;
  return body;
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    sendStatus(res, 405);
    return;
  }

  const rawBody = await readRawBody(req);
  const signature = req.headers['x-signature-ed25519'];
  const timestamp = req.headers['x-signature-timestamp'];

  const isValid = await verifyKey(rawBody, signature, timestamp, process.env.DISCORD_PUBLIC_KEY);
  if (!isValid) {
    sendText(res, 401, 'invalid request signature');
    return;
  }

  const interaction = JSON.parse(rawBody.toString('utf8'));

  if (interaction.type === InteractionType.PING) {
    sendJson(res, 200, { type: InteractionResponseType.PONG });
    return;
  }

  if (interaction.type === InteractionType.APPLICATION_COMMAND && interaction.data.name === 'intent') {
    sendJson(res, 200, {
      type: InteractionResponseType.MODAL,
      data: {
        custom_id: 'intent_modal',
        title: 'Intent 초안 요청',
        components: [
          {
            type: 1,
            components: [
              {
                type: 4,
                custom_id: 'slug',
                label: 'slug (예: match-detail-toc-drag)',
                style: 1,
                required: true,
                max_length: 60,
              },
            ],
          },
          {
            type: 1,
            components: [
              {
                type: 4,
                custom_id: 'description',
                label: '기획안 설명',
                style: 2,
                required: true,
                max_length: 3000,
              },
            ],
          },
        ],
      },
    });
    return;
  }

  if (interaction.type === InteractionType.MODAL_SUBMIT && interaction.data.custom_id === 'intent_modal') {
    const fields = Object.fromEntries(
      interaction.data.components.map((row) => {
        const c = row.components[0];
        return [c.custom_id, c.value];
      })
    );
    const slug = slugify(fields.slug);
    const requestedBy = interaction.member?.user?.username ?? interaction.user?.username ?? 'unknown';

    if (!slug) {
      sendJson(res, 200, {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: { content: '❌ slug는 영문/숫자만 사용할 수 있어요 — 예: match-detail-toc-drag' },
      });
      return;
    }

    // dispatch를 먼저 완료(또는 실패)시킨 뒤 응답한다 — Vercel의 서버리스 함수는
    // res.end() 이후 실행 컨텍스트를 바로 종료할 수 있어, 응답을 먼저 보내고
    // 뒤이어 await하는 fire-and-forget 방식은 GitHub API 호출이 중간에 끊길 수
    // 있다(실제로 접수 메시지는 뜨는데 repository_dispatch가 전송 안 되는 형태로
    // 관측됨).
    const dispatchError = await dispatchIntentRequest({
      slug,
      description: fields.description,
      requestedBy,
    }).catch((err) => err);

    if (dispatchError) {
      console.error('[discord-bridge] dispatch failed', dispatchError);
      sendJson(res, 200, {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: { content: `❌ 접수 실패 — GitHub 연동 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.` },
      });
      return;
    }

    sendJson(res, 200, {
      type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
      data: { content: `✅ 접수됨 — \`${slug}\` intent 초안을 생성 중입니다.` },
    });
    return;
  }

  // ── 릴리즈 심사 제출 버튼 ────────────────────────────────────────────────
  // 2단계다. rel_submit 은 확인을 한 번 더 띄우기만 하고, 실제 제출은
  // rel_confirm 에서 일어난다. 심사 제출은 되돌릴 수 없어 실수 클릭을 막는다.
  if (interaction.type === InteractionType.MESSAGE_COMPONENT) {
    const customId = interaction.data?.custom_id ?? '';
    const user =
      interaction.member?.user?.username ?? interaction.user?.username ?? 'unknown';

    // [1단계] 제출 의사 → 확인 버튼을 띄운다
    if (customId.startsWith('rel_submit:')) {
      const version = parseVersion(customId.slice('rel_submit:'.length));
      if (!version) {
        sendJson(res, 200, {
          type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
          data: { content: '❌ 버전 형식이 올바르지 않아요.', flags: 64 },
        });
        return;
      }
      sendJson(res, 200, {
        type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
        data: {
          content:
            `⚠️ **${version}** 을 심사에 제출합니다.\n` +
            '되돌릴 수 없어요. 정말 진행할까요?',
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

    // [2단계] 확정 → 실제로 dispatch
    if (customId.startsWith('rel_confirm:')) {
      const version = parseVersion(customId.slice('rel_confirm:'.length));
      if (!version) {
        sendJson(res, 200, {
          type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
          data: { content: '❌ 버전 형식이 올바르지 않아요.', flags: 64 },
        });
        return;
      }

      // 확인 메시지는 원본 릴리즈 알림에 딸린 ephemeral 이라, 패치노트는
      // 그 ephemeral 이 아니라 사람이 처음 누른 메시지에서 와야 한다.
      // Discord 는 버튼을 누른 메시지를 interaction.message 로 준다.
      const releaseNotes = extractReleaseNotes(interaction.message);

      // intent 쪽과 같은 이유로 dispatch 를 먼저 끝내고 응답한다 — Vercel 함수는
      // res.end() 뒤 실행 컨텍스트를 바로 종료할 수 있다.
      const err = await dispatchReleaseSubmit({
        version,
        platform: 'both',
        releaseNotes,
        requestedBy: user,
      }).catch((e) => e);

      if (err) {
        console.error('[discord-bridge] release dispatch failed', err);
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
  }

  sendText(res, 400, 'unhandled interaction type');
}
