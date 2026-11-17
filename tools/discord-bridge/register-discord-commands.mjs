// scripts/register-discord-commands.mjs
// 1회 실행: /intent 슬래시 커맨드를 Discord Application에 등록한다.
// 실행: DISCORD_APPLICATION_ID=... DISCORD_BOT_TOKEN=... node scripts/register-discord-commands.mjs

const APPLICATION_ID = process.env.DISCORD_APPLICATION_ID;
const BOT_TOKEN = process.env.DISCORD_BOT_TOKEN;

if (!APPLICATION_ID || !BOT_TOKEN) {
  console.error('DISCORD_APPLICATION_ID, DISCORD_BOT_TOKEN 환경변수가 필요합니다.');
  process.exit(1);
}

const commands = [
  {
    name: 'intent',
    description: '기획안으로 intent.md 초안 + PR을 자동 생성한다',
    type: 1,
  },
];

const res = await fetch(`https://discord.com/api/v10/applications/${APPLICATION_ID}/commands`, {
  method: 'PUT',
  headers: {
    Authorization: `Bot ${BOT_TOKEN}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(commands),
});

if (!res.ok) {
  console.error(`커맨드 등록 실패: ${res.status} ${await res.text()}`);
  process.exit(1);
}

console.log('✅ /intent 커맨드 등록 완료');
