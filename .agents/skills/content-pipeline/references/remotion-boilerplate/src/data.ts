export const FPS = 30;

export const CARD_COUNT = 13;
export const CARD_WIDTH = 1080;
export const CARD_HEIGHT = 1350;
export const VERTICAL_WIDTH = 1080;
export const VERTICAL_HEIGHT = 1920;
// 실제 TTS 음성 길이 기반 프레임 수 (섹션별 MP3에서 측정)
const ACTUAL_CARD_FRAMES = [310, 512, 400, 445, 460, 454, 454, 411, 371, 325, 477, 758, 204];
export const TOTAL_FRAMES = ACTUAL_CARD_FRAMES.reduce((a, b) => a + b, 0); // 5581

const SCRIPT_CARD_SECONDS = [10.32, 17.06, 13.34, 14.83, 15.34, 15.12, 15.14, 13.7, 12.36, 10.85, 15.89, 25.27, 6.79];

const distributeByWeights = (total: number, weights: number[]): number[] => {
  const weightSum = weights.reduce((sum, weight) => sum + weight, 0);
  const raw = weights.map((weight) => (weight / weightSum) * total);
  const base = raw.map((value) => Math.floor(value));
  let remainder = total - base.reduce((sum, value) => sum + value, 0);

  const ranked = raw
    .map((value, index) => ({index, fraction: value - Math.floor(value)}))
    .sort((a, b) => b.fraction - a.fraction);

  for (let i = 0; i < ranked.length && remainder > 0; i++) {
    base[ranked[i].index] += 1;
    remainder -= 1;
  }

  return base;
};

export const SUBTITLE_LINES: string[][] = [
  [
    "올해도 벚꽃 시즌이 돌아왔습니다.",
    "이천이십육년 벚꽃, 어디서 봐야 가장 아름다울까요?",
    "전국 벚꽃 명소 열 곳을 한번에 정리해 드릴게요.",
  ],
  [
    "올해 벚꽃은 평년보다 이틀에서 삼일 정도 빠릅니다.",
    "제주가 삼월 이십일 경 가장 먼저 피기 시작하고, 부산은 삼월 이십오일, 서울은 사월 초에 개화합니다.",
    "꽃이 핀 뒤 약 일주일이면 만개하니까, 타이밍을 잘 잡는 게 중요해요.",
  ],
  [
    "첫 번째, 서울 여의도 윤중로입니다.",
    "천육백 그루의 벚나무가 만드는 장대한 벚꽃 터널.",
    "서울에서 가장 유명한 벚꽃 명소죠.",
    "올해 봄꽃축제는 사월 팔일부터 십이일까지 열립니다.",
  ],
  [
    "두 번째, 석촌호수.",
    "이점오 킬로미터 벚꽃길을 걸으며 롯데월드타워 야경까지 즐길 수 있어요.",
    "낮에는 화사한 벚꽃, 밤에는 조명이 비추는 야간 벚꽃.",
    "축제는 삼월 이십구일부터 사월 육일까지입니다.",
  ],
  [
    "세 번째, 경남 창원의 진해.",
    "무려 삼십육만 그루의 벚나무가 있는 국내 최대 규모 벚꽃 도시입니다.",
    "진해군항제는 삼월 이십칠일부터 사월 오일까지.",
    "벚꽃 축제의 분위기를 제대로 느끼고 싶다면 여기예요.",
  ],
  [
    "네 번째, 하동 십리벚꽃길.",
    "지리산 기슭 화개장터에서 쌍계사까지 약 오 킬로미터 이어지는 벚꽃 로드입니다.",
    "산과 벚꽃이 어우러진 풍경이 정말 감동적이에요.",
    "축제는 삼월 이십칠일부터 이십구일까지.",
  ],
  [
    "다섯 번째, 경주 불국사.",
    "국내 최대 겹벚꽃 군락지로, 기와 지붕 위로 핑크빛 구름처럼 피어나는 겹벚꽃이 장관입니다.",
    "일반 벚꽃보다 약 이 주 늦게 피니까, 벚꽃 시즌을 연장하고 싶은 분께 추천드려요.",
  ],
  [
    "여섯 번째, 대구 이월드.",
    "낮에는 핑크빛 벚꽃, 밤에는 레인보우 블라썸 라이팅 쇼.",
    "놀이공원과 벚꽃의 조합이 독특하죠.",
    "블라썸 피크닉은 삼월 이십일일부터 사월 오일까지 진행됩니다.",
  ],
  [
    "일곱 번째, 제주 전농로.",
    "왕벚꽃의 원산지로, 올해 가장 먼저 벚꽃을 볼 수 있는 곳이에요.",
    "돌담길 위로 풍성하게 드리운 왕벚꽃이 제주만의 특별한 봄을 보여줍니다.",
  ],
  [
    "여덟 번째, 서울 창경궁.",
    "궁궐과 벚꽃의 고즈넉한 조화.",
    "춘당지 연못에 비친 벚꽃이 정말 아름답습니다.",
    "서울 궁궐 중 벚꽃이 가장 많은 곳이에요.",
  ],
  [
    "아홉 번째와 열 번째는 서울 숨은 명소 두 곳.",
    "불광천은 현지인만 아는 이 킬로미터 벚꽃길로, 한적하게 산책하기 좋습니다.",
    "경의선숲길 연남동 구간은 벚꽃 산책과 트렌디한 카페 탐방을 동시에 즐길 수 있어요.",
  ],
  [
    "마지막으로 벚꽃놀이 꿀팁 네 가지.",
    "하나, 유명 명소는 평일 오전에 가세요. 주말은 정말 붐빕니다.",
    "둘, 만개 후 삼일에서 사일이 골든타임. 비나 강풍이 오면 금방 져버려요.",
    "셋, 겹벚꽃은 일반 벚꽃 후 약 이 주 뒤에 핍니다. 경주나 전주에서 시즌을 연장하세요.",
    "넷, 석촌호수와 대구 이월드는 야간 조명이 예쁘니까, 밤 벚꽃도 꼭 즐겨보세요.",
  ],
  [
    "올봄, 벚꽃 보러 갈까요?",
    "지금이 딱 그때입니다.",
    "이 영상 저장해두고, 벚꽃 일정 잡아보세요.",
  ],
];

export type SubtitleSegment = {
  end: number;
  start: number;
  text: string;
};

const getTextWeight = (text: string): number => text.replace(/\s+/g, "").length;

// 실제 음성 길이 기반 정확한 프레임 배분
export const CARD_DURATIONS = ACTUAL_CARD_FRAMES;

export const SUBTITLE_SEGMENTS: SubtitleSegment[] = (() => {
  const segments: SubtitleSegment[] = [];
  let cursor = 0;

  SUBTITLE_LINES.forEach((lines, cardIndex) => {
    const framesPerLine = distributeByWeights(
      CARD_DURATIONS[cardIndex],
      lines.map(getTextWeight),
    );

    let localCursor = cursor;
    lines.forEach((text, lineIndex) => {
      const durationInFrames = framesPerLine[lineIndex];
      segments.push({
        start: localCursor,
        end: localCursor + durationInFrames,
        text,
      });
      localCursor += durationInFrames;
    });

    cursor += CARD_DURATIONS[cardIndex];
  });

  return segments;
})();
