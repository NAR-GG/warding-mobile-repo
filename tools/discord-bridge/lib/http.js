// Discord 핸들러들이 같이 쓰는 HTTP 헬퍼.
//
// Vercel의 Node.js Function 런타임은 ESM(`"type": "module"`) 핸들러에는
// Express 스타일 `res.status()/.json()` 헬퍼를 붙여주지 않는다(CommonJS
// 핸들러에만 적용됨) — 순수 `http.ServerResponse` API로 대체한다.

import { waitUntil } from '@vercel/functions';

export async function readRawBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return Buffer.concat(chunks);
}

export function sendStatus(res, status) {
  res.statusCode = status;
  res.end();
}

export function sendText(res, status, text) {
  res.statusCode = status;
  res.end(text);
}

export function sendJson(res, status, body) {
  res.statusCode = status;
  res.setHeader('content-type', 'application/json');
  res.end(JSON.stringify(body));
}

/**
 * GitHub repository_dispatch 를 쏜다.
 *
 * 한때 "먼저 await 하고 그다음 응답" 했다. 응답을 먼저 보내고 뒤이어 await 하면
 * Vercel 이 res.end() 뒤 실행 컨텍스트를 종료해 이 호출이 끊겼기 때문이다
 * (접수 메시지는 뜨는데 dispatch 가 안 나가는 형태로 관측됐다).
 *
 * 그런데 그 순서가 **Discord 재시도로 중복 제출**을 만들었다(2026-10-27).
 * 지금은 respondThenRun 으로 응답을 먼저 보내고, 이 호출은 waitUntil 에 실어
 * 끝까지 돌게 한다 — 끊김 문제의 정식 해법이다. 자세한 경위는 lib/once.js 참고.
 */
export async function dispatch(eventType, clientPayload) {
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
        event_type: eventType,
        client_payload: { ...clientPayload, source: 'discord' },
      }),
    }
  );
  if (!res.ok) {
    throw new Error(`repository_dispatch 실패: ${res.status} ${await res.text()}`);
  }
}

/**
 * Discord 에 **먼저 응답하고** 느린 작업은 그 뒤에 돌린다.
 *
 * Discord 의 인터랙션 응답 제한은 3초다. 이걸 넘기면 같은 요청을 재시도하는데,
 * 재시도마다 dispatch 가 한 번씩 더 나가 중복 제출이 됐다(2026-10-27).
 *
 * `type 5`(DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE)로 "생각 중" 을 즉시 돌려주고,
 * 실제 작업은 `waitUntil` 에 실어 응답 뒤에도 끝까지 돌게 한다. 작업이 끝나면
 * 그 메시지를 결과로 바꿔 쓴다.
 *
 * @param res            Node ServerResponse
 * @param interaction    Discord 인터랙션(토큰·application_id 를 쓴다)
 * @param ephemeral      결과 메시지를 누른 사람에게만 보일지
 * @param work           () => Promise<string> — 끝나고 보여줄 본문을 돌려준다
 */
export function respondThenRun(res, interaction, { ephemeral = true } = {}, work) {
  // "..." 이 떴다가 아래 followUp 이 내용을 채워 넣는다. ephemeral 여부는
  // 여기서 정해야 한다 — 나중에 바꿀 수 없다.
  sendJson(res, 200, {
    type: 5,
    data: ephemeral ? { flags: 64 } : {},
  });

  const task = (async () => {
    let content;
    try {
      content = await work();
    } catch (err) {
      console.error('[discord-bridge] 후속 작업 실패', err);
      content = '❌ 처리 중 오류가 났어요. GitHub Actions 를 확인해주세요.';
    }
    await followUp(interaction, content, ephemeral).catch((err) =>
      console.error('[discord-bridge] follow-up 실패', err)
    );
  })();

  // Vercel 이 응답 뒤에도 이 작업을 끝까지 돌려준다. 로컬·다른 런타임에서는
  // waitUntil 이 없을 수 있어 그때는 그냥 떠 있는 promise 로 둔다.
  try {
    waitUntil(task);
  } catch {
    /* no-op */
  }
  return task;
}

/** 지연 응답(type 5)으로 띄운 "..." 를 실제 내용으로 바꾼다. */
export async function followUp(interaction, content, ephemeral = true) {
  const appId = interaction?.application_id;
  const token = interaction?.token;
  if (!appId || !token) throw new Error('follow-up 에 필요한 application_id/token 이 없다');

  const res = await fetch(
    `https://discord.com/api/v10/webhooks/${appId}/${token}/messages/@original`,
    {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content, flags: ephemeral ? 64 : 0 }),
    }
  );
  if (!res.ok) {
    throw new Error(`follow-up 실패: ${res.status} ${await res.text()}`);
  }
}
