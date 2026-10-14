// Discord 핸들러들이 같이 쓰는 HTTP 헬퍼.
//
// Vercel의 Node.js Function 런타임은 ESM(`"type": "module"`) 핸들러에는
// Express 스타일 `res.status()/.json()` 헬퍼를 붙여주지 않는다(CommonJS
// 핸들러에만 적용됨) — 순수 `http.ServerResponse` API로 대체한다.

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
 * Vercel 서버리스 함수는 res.end() 뒤 실행 컨텍스트를 바로 종료할 수 있어,
 * 응답을 먼저 보내고 뒤이어 await 하는 fire-and-forget 방식은 이 호출이
 * 중간에 끊길 수 있다(실제로 접수 메시지는 뜨는데 dispatch 가 전송 안 되는
 * 형태로 관측됨). 호출하는 쪽에서 **먼저 await 하고 그다음 응답**한다.
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
