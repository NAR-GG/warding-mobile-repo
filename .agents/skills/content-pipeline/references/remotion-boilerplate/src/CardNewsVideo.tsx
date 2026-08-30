import React from "react";
import {
  AbsoluteFill,
  Audio,
  Sequence,
  Series,
  staticFile,
} from "remotion";
import {CARD_COMPONENTS} from "./cards";
import {CARD_DURATIONS} from "./data";
import {SubtitleOverlay} from "./SubtitleOverlay";

// 씬 전환 버퍼: 카드 시작 후 음성이 시작되기까지의 딜레이
const AUDIO_DELAY_FRAMES = 20; // 0.67초 @ 30fps

interface CardNewsVideoProps {
  cardDurations?: number[];
  showSubtitles?: boolean;
}

export const CardNewsVideo: React.FC<CardNewsVideoProps> = ({
  cardDurations = CARD_DURATIONS,
  showSubtitles = true,
}) => {
  // 각 카드에 오디오 딜레이만큼 프레임 추가
  const adjustedDurations = cardDurations.map((dur, i) =>
    i === 0 ? dur : dur + AUDIO_DELAY_FRAMES
  );

  return (
    <AbsoluteFill style={{ backgroundColor: "#000" }}>
      <Series>
        {adjustedDurations.map((durationInFrames, index) => {
          const CardComponent = CARD_COMPONENTS[index];
          const audioNum = String(index + 1).padStart(2, "0");
          const delay = index === 0 ? 0 : AUDIO_DELAY_FRAMES;
          return (
            <Series.Sequence key={index} durationInFrames={durationInFrames}>
              {/* 카드 비주얼은 즉시 시작 */}
              <CardComponent durationInFrames={durationInFrames} />
              {/* 오디오는 딜레이 후 시작 — 씬 전환이 끝난 뒤 나레이션 시작 */}
              <Sequence from={delay}>
                <Audio src={staticFile(`card-${audioNum}.mp3`)} />
              </Sequence>
            </Series.Sequence>
          );
        })}
      </Series>

      {showSubtitles ? <SubtitleOverlay bottom={96} maxWidth={920} /> : null}
    </AbsoluteFill>
  );
};
