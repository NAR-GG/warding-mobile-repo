// HTTP 클라이언트 회귀 테스트.
//
// **`--conditions=react-server` 로 돌려야 한다.** `client.ts` 가
// `import 'server-only'` 를 쓰는데, 그 모듈은 번들러 밖에서도 던지기 때문이다
// (실행 조건이 없으면 "클라이언트에서 import 됐다" 로 본다).
// `package.json` 의 test 스크립트에 그 플래그가 들어 있다.

import { createServer, type IncomingMessage, type ServerResponse, type Server } from 'node:http';
import test from 'node:test';
import assert from 'node:assert/strict';

import { getJson, postJson } from './client';

type Captured = { auth: string | undefined; path: string };

type Handler = (req: IncomingMessage, res: ServerResponse) => void;

async function withServer(
  handler: Handler,
  run: (base: string, seen: Captured[]) => Promise<void>,
): Promise<void> {
  const seen: Captured[] = [];
  const srv: Server = createServer((req, res) => {
    seen.push({ auth: req.headers.authorization, path: req.url ?? '' });
    handler(req, res);
  });
  await new Promise<void>((r) => srv.listen(0, () => r()));
  const { port } = srv.address() as { port: number };
  try {
    await run(`http://127.0.0.1:${port}`, seen);
  } finally {
    srv.close();
  }
}

const okJson: Handler = (_req, res) => {
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ id: 7 }));
};

test('토큰을 주면 Bearer 헤더가 붙는다', async () => {
  await withServer(okJson, async (base, seen) => {
    const r = await getJson(`${base}/x`, (j) => j, { token: 'TEST-TOKEN' });
    assert.equal(r.ok, true);
    assert.equal(seen[0]?.auth, 'Bearer TEST-TOKEN');
  });
});

test('토큰이 없으면 헤더를 붙이지 않는다 (비회원 조회)', async () => {
  await withServer(okJson, async (base, seen) => {
    await getJson(`${base}/x`, (j) => j, {});
    assert.equal(seen[0]?.auth, undefined);
  });
});

test('빈 문자열 토큰도 헤더를 붙이지 않는다', async () => {
  await withServer(okJson, async (base, seen) => {
    await getJson(`${base}/x`, (j) => j, { token: '' });
    assert.equal(seen[0]?.auth, undefined);
  });
});

test('404 는 server 실패 + 상태코드를 담는다', async () => {
  await withServer(
    (_req, res) => {
      res.writeHead(404);
      res.end('not found');
    },
    async (base) => {
      const r = await getJson(`${base}/x`, (j) => j, {});
      assert.equal(r.ok, false);
      if (!r.ok) {
        assert.equal(r.failure.kind, 'server');
        assert.equal(r.failure.statusCode, 404);
      }
    },
  );
});

test('401 은 unauthorized 로 가른다', async () => {
  await withServer(
    (_req, res) => {
      res.writeHead(401);
      res.end();
    },
    async (base) => {
      const r = await getJson(`${base}/x`, (j) => j, {});
      assert.equal(r.ok, false);
      if (!r.ok) assert.equal(r.failure.kind, 'unauthorized');
    },
  );
});

test('204 는 noData (본문이 없어 파싱하면 터진다)', async () => {
  await withServer(
    (_req, res) => {
      res.writeHead(204);
      res.end();
    },
    async (base) => {
      const r = await getJson(`${base}/x`, (j) => j, {});
      assert.equal(r.ok, false);
      if (!r.ok) assert.equal(r.failure.kind, 'noData');
    },
  );
});

test('JSON 이 깨지면 parse 실패', async () => {
  await withServer(
    (_req, res) => {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end('{ not json');
    },
    async (base) => {
      const r = await getJson(`${base}/x`, (j) => j, {});
      assert.equal(r.ok, false);
      if (!r.ok) assert.equal(r.failure.kind, 'parse');
    },
  );
});

test('parse 함수가 던져도 Result 로 돌아온다', async () => {
  await withServer(okJson, async (base) => {
    const r = await getJson(`${base}/x`, () => {
      throw new TypeError('형식이 다르다');
    }, {});
    assert.equal(r.ok, false);
    if (!r.ok) assert.equal(r.failure.kind, 'parse');
  });
});

// ── POST ─────────────────────────────────────────────────

test('postJson 은 POST 로 보낸다', async () => {
  await withPostServer(okJson, async (base, seen) => {
    const r = await postJson(`${base}/like`, (j) => j);
    assert.equal(r.ok, true);
    assert.equal(seen[0]?.method, 'POST');
  });
});

test('body 를 주면 JSON 으로 싣고 Content-Type 을 붙인다', async () => {
  await withPostServer(okJson, async (base, seen) => {
    await postJson(`${base}/comments`, (j) => j, {
      body: { body: '안녕', replyToCommentId: 5 },
    });
    assert.equal(seen[0]?.contentType, 'application/json');
    assert.deepEqual(JSON.parse(seen[0]?.body ?? '{}'), {
      body: '안녕',
      replyToCommentId: 5,
    });
  });
});

test('body 가 없으면 Content-Type 을 붙이지 않는다 (토글)', async () => {
  // Dart 토글들은 본문 없이 POST 만 보낸다. 빈 본문에 헤더만 붙이면
  // 서버가 JSON 파싱을 시도할 수 있다.
  await withPostServer(okJson, async (base, seen) => {
    await postJson(`${base}/like`, (j) => j);
    assert.equal(seen[0]?.contentType, undefined);
    assert.equal(seen[0]?.body, '');
  });
});

test('POST 도 토큰을 Bearer 로 붙인다', async () => {
  await withPostServer(okJson, async (base, seen) => {
    await postJson(`${base}/scrap`, (j) => j, { token: 'T' });
    assert.equal(seen[0]?.auth, 'Bearer T');
  });
});

test('POST 401 은 unauthorized 로 가른다', async () => {
  const unauthorized: Handler = (_req, res) => {
    res.writeHead(401, { 'content-type': 'application/json' });
    res.end('{"message":"no"}');
  };
  await withPostServer(unauthorized, async (base) => {
    const r = await postJson(`${base}/like`, (j) => j);
    assert.equal(r.ok, false);
    if (!r.ok) assert.equal(r.failure.kind, 'unauthorized');
  });
});

/** POST 검증용 해네스 — 메서드·본문·Content-Type 까지 담는다. */
type PostCaptured = {
  auth: string | undefined;
  method: string | undefined;
  contentType: string | undefined;
  body: string;
};

async function withPostServer(
  handler: Handler,
  run: (base: string, seen: PostCaptured[]) => Promise<void>,
): Promise<void> {
  const seen: PostCaptured[] = [];
  const srv: Server = createServer((req, res) => {
    let body = '';
    req.on('data', (c) => {
      body += c;
    });
    req.on('end', () => {
      seen.push({
        auth: req.headers.authorization,
        method: req.method,
        contentType: req.headers['content-type'],
        body,
      });
      handler(req, res);
    });
  });
  await new Promise<void>((r) => srv.listen(0, () => r()));
  const { port } = srv.address() as { port: number };
  try {
    await run(`http://127.0.0.1:${port}`, seen);
  } finally {
    srv.close();
  }
}
