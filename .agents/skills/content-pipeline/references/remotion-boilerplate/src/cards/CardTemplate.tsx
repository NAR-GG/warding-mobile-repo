// 카드 컴포넌트 템플릿 — 3가지 레이아웃 패턴
// 새 카드를 만들 때 이 파일을 복사해서 내용을 채운다.
// 패턴: FullBleed(이미지 풀블리드+텍스트 오버레이), Split(좌우 분할), TextOnly(텍스트 중심)
//
// ★ 모바일 가독성 폰트 사이즈 기준 (1080px 캔버스 → 모바일 ~375px, 약 1/2.88 축소)
//   h2 제목: 48px (모바일 ~17px)
//   본문 desc: 36px (모바일 ~12px)
//   날짜/태그: 32px (모바일 ~11px)
//   위치/출처 info: 30px (모바일 ~10px)
//   페이지 번호: 28px (모바일 ~10px)
//   절대 최소: 24px (이 이하 금지)
//
// ★ 좌우분할(Split)의 페이지 번호는 텍스트 영역 하단 중앙에 배치 (이미지 위 금지)

import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame } from "remotion";

const FADE_IN = 9;      // 0.3초 @ 30fps
const TITLE_IN = 15;    // 0.5초
const BODY_IN = 24;     // 0.8초
const FADE_OUT = 15;    // 0.5초

interface CardProps {
  durationInFrames: number;
}

// ─── 패턴 A: 풀블리드 (이미지 배경 + 텍스트 오버레이) ───
export const FullBleedCard: React.FC<CardProps> = ({ durationInFrames }) => {
  const frame = useCurrentFrame();
  const bgOpacity = interpolate(frame, [0, FADE_IN], [0, 1], { extrapolateRight: "clamp" });
  const titleOpacity = interpolate(frame, [TITLE_IN, TITLE_IN + 12], [0, 1], { extrapolateRight: "clamp" });
  const titleY = interpolate(frame, [TITLE_IN, TITLE_IN + 12], [30, 0], { extrapolateRight: "clamp" });
  const bodyOpacity = interpolate(frame, [BODY_IN, BODY_IN + 12], [0, 1], { extrapolateRight: "clamp" });
  const fadeOut = interpolate(frame, [durationInFrames - FADE_OUT, durationInFrames], [1, 0], { extrapolateLeft: "clamp" });

  return (
    <AbsoluteFill style={{ opacity: fadeOut }}>
      <Img src={staticFile("card-XX.png")} style={{ width: "100%", height: "100%", objectFit: "cover", opacity: bgOpacity }} />
      <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to bottom, transparent 40%, rgba(0,0,0,0.8) 100%)" }} />
      <div style={{ position: "absolute", bottom: 100, left: 80, right: 80 }}>
        <div style={{ fontSize: 32, fontWeight: 500, letterSpacing: 3, marginBottom: 20, opacity: bodyOpacity }}>날짜</div>
        <h2 style={{ fontFamily: "'Noto Serif KR', serif", fontSize: 48, fontWeight: 900, lineHeight: 1.25, color: "#FAFAFA", opacity: titleOpacity, transform: `translateY(${titleY}px)`, marginBottom: 16 }}>
          제목
        </h2>
        <p style={{ fontSize: 36, fontWeight: 300, color: "rgba(250,250,250,0.85)", lineHeight: 1.55, opacity: bodyOpacity }}>
          설명 텍스트 (2~3줄 이내)
        </p>
        <p style={{ fontSize: 30, color: "rgba(250,250,250,0.5)", marginTop: 24, lineHeight: 1.6, opacity: bodyOpacity }}>
          위치 정보
        </p>
      </div>
      {/* 페이지 번호: 하단 중앙 */}
      <div style={{ position: "absolute", bottom: 40, left: "50%", transform: "translateX(-50%)", fontSize: 28, fontWeight: 300, letterSpacing: 3, color: "rgba(255,255,255,0.4)" }}>
        N / 13
      </div>
    </AbsoluteFill>
  );
};

// ─── 패턴 B: 스플릿 (좌우 분할) ───
// ★ 페이지 번호는 텍스트 영역 하단 중앙 (이미지 위 금지)
export const SplitCard: React.FC<CardProps> = ({ durationInFrames }) => {
  const frame = useCurrentFrame();
  const titleOpacity = interpolate(frame, [TITLE_IN, TITLE_IN + 12], [0, 1], { extrapolateRight: "clamp" });
  const bodyOpacity = interpolate(frame, [BODY_IN, BODY_IN + 12], [0, 1], { extrapolateRight: "clamp" });
  const fadeOut = interpolate(frame, [durationInFrames - FADE_OUT, durationInFrames], [1, 0], { extrapolateLeft: "clamp" });

  return (
    <AbsoluteFill style={{ display: "flex", opacity: fadeOut }}>
      {/* 텍스트 영역 (48%) */}
      <div style={{ width: "48%", height: "100%", padding: "80px 48px 90px 72px", display: "flex", flexDirection: "column", justifyContent: "center", background: "#FAFAFA", position: "relative" }}>
        <div style={{ fontSize: 32, fontWeight: 500, letterSpacing: 3, marginBottom: 20, opacity: bodyOpacity }}>날짜</div>
        <h2 style={{ fontFamily: "'Noto Serif KR', serif", fontSize: 48, fontWeight: 900, lineHeight: 1.25, color: "#0A0A0A", opacity: titleOpacity }}>
          제목
        </h2>
        <p style={{ fontSize: 36, fontWeight: 300, color: "#555", lineHeight: 1.55, opacity: bodyOpacity, marginTop: 16 }}>
          설명 텍스트 (2~3줄 이내)
        </p>
        <p style={{ fontSize: 30, color: "#999", marginTop: 24, lineHeight: 1.6, opacity: bodyOpacity }}>
          위치 정보
        </p>
        {/* 페이지 번호: 텍스트 영역 하단 중앙 */}
        <div style={{ position: "absolute", bottom: 40, left: "50%", transform: "translateX(-50%)", fontSize: 28, fontWeight: 300, letterSpacing: 3, color: "rgba(0,0,0,0.3)" }}>
          N / 13
        </div>
      </div>
      {/* 이미지 영역 (52%) */}
      <div style={{ width: "52%", height: "100%", overflow: "hidden" }}>
        <Img src={staticFile("card-XX.png")} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      </div>
    </AbsoluteFill>
  );
};

// ─── 패턴 C: 텍스트 온리 (이미지 없을 때) ───
export const TextOnlyCard: React.FC<CardProps> = ({ durationInFrames }) => {
  const frame = useCurrentFrame();
  const titleOpacity = interpolate(frame, [TITLE_IN, TITLE_IN + 12], [0, 1], { extrapolateRight: "clamp" });
  const titleY = interpolate(frame, [TITLE_IN, TITLE_IN + 12], [30, 0], { extrapolateRight: "clamp" });
  const bodyOpacity = interpolate(frame, [BODY_IN, BODY_IN + 12], [0, 1], { extrapolateRight: "clamp" });
  const fadeOut = interpolate(frame, [durationInFrames - FADE_OUT, durationInFrames], [1, 0], { extrapolateLeft: "clamp" });

  return (
    <AbsoluteFill style={{ background: "#0A0A0A", display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", padding: "0 80px", opacity: fadeOut }}>
      <h2 style={{ fontFamily: "'Noto Serif KR', serif", fontSize: 56, color: "#FAFAFA", textAlign: "center", opacity: titleOpacity, transform: `translateY(${titleY}px)` }}>
        제목
      </h2>
      <p style={{ fontSize: 36, color: "rgba(250,250,250,0.7)", lineHeight: 1.6, textAlign: "center", marginTop: 32, opacity: bodyOpacity }}>
        설명 텍스트
      </p>
      {/* 페이지 번호 */}
      <div style={{ position: "absolute", bottom: 40, left: "50%", transform: "translateX(-50%)", fontSize: 28, fontWeight: 300, letterSpacing: 3, color: "rgba(255,255,255,0.4)" }}>
        N / 13
      </div>
    </AbsoluteFill>
  );
};
