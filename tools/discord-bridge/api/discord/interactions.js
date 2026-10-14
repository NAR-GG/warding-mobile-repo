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

  sendText(res, 400, 'unhandled interaction type');
}
