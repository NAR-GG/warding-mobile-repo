import { verifyKey, InteractionType, InteractionResponseType } from 'discord-interactions';
import { slugify } from '../../lib/slugify.js';

export const config = { api: { bodyParser: false } };

async function readRawBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return Buffer.concat(chunks);
}

async function dispatchIntentRequest({ slug, description, requestedBy }) {
  const res = await fetch(
    `https://api.github.com/repos/${process.env.GITHUB_REPO}/dispatches`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.GITHUB_DISPATCH_TOKEN}`,
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
    res.status(405).end();
    return;
  }

  const rawBody = await readRawBody(req);
  const signature = req.headers['x-signature-ed25519'];
  const timestamp = req.headers['x-signature-timestamp'];

  const isValid = await verifyKey(rawBody, signature, timestamp, process.env.DISCORD_PUBLIC_KEY);
  if (!isValid) {
    res.status(401).end('invalid request signature');
    return;
  }

  const interaction = JSON.parse(rawBody.toString('utf8'));

  if (interaction.type === InteractionType.PING) {
    res.status(200).json({ type: InteractionResponseType.PONG });
    return;
  }

  if (interaction.type === InteractionType.APPLICATION_COMMAND && interaction.data.name === 'intent') {
    res.status(200).json({
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

    res.status(200).json({
      type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
      data: { content: `✅ 접수됨 — \`${slug}\` intent 초안을 생성 중입니다.` },
    });

    await dispatchIntentRequest({ slug, description: fields.description, requestedBy });
    return;
  }

  res.status(400).end('unhandled interaction type');
}
