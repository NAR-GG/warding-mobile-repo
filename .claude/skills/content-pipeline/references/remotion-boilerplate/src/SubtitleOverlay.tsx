import React from "react";
import {AbsoluteFill, interpolate, useCurrentFrame} from "remotion";
import {SUBTITLE_SEGMENTS} from "./data";

type SubtitleOverlayProps = {
  bottom: number;
  maxWidth: number;
};

export const SubtitleOverlay: React.FC<SubtitleOverlayProps> = ({bottom, maxWidth}) => {
  const frame = useCurrentFrame();
  const currentSegment = SUBTITLE_SEGMENTS.find(
    (segment) => frame >= segment.start && frame < segment.end,
  );

  if (!currentSegment) {
    return null;
  }

  const localFrame = frame - currentSegment.start;
  const durationInFrames = currentSegment.end - currentSegment.start;
  const opacity = interpolate(
    localFrame,
    [0, 8, durationInFrames - 8, durationInFrames],
    [0, 1, 1, 0],
    {extrapolateLeft: "clamp", extrapolateRight: "clamp"},
  );
  const translateY = interpolate(
    localFrame,
    [0, 8, durationInFrames - 8, durationInFrames],
    [18, 0, 0, 12],
    {extrapolateLeft: "clamp", extrapolateRight: "clamp"},
  );

  return (
    <AbsoluteFill
      style={{
        justifyContent: "flex-end",
        alignItems: "center",
        pointerEvents: "none",
      }}
    >
      <div
        style={{
          marginBottom: bottom,
          maxWidth,
          padding: "18px 26px",
          borderRadius: 28,
          backgroundColor: "rgba(12, 12, 12, 0.72)",
          border: "1px solid rgba(255, 255, 255, 0.12)",
          boxShadow: "0 20px 60px rgba(0, 0, 0, 0.32)",
          opacity,
          transform: `translateY(${translateY}px)`,
          backdropFilter: "blur(18px)",
          textAlign: "center",
        }}
      >
        <div
          style={{
            fontFamily: "'Noto Sans KR', sans-serif",
            fontSize: 34,
            fontWeight: 700,
            lineHeight: 1.45,
            letterSpacing: -0.6,
            color: "#FFFFFF",
            textShadow: "0 2px 10px rgba(0, 0, 0, 0.35)",
            whiteSpace: "pre-wrap",
          }}
        >
          {currentSegment.text}
        </div>
      </div>
    </AbsoluteFill>
  );
};
