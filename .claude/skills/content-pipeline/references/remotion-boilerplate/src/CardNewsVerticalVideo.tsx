import React from "react";
import {AbsoluteFill, Audio, Img, Series, staticFile} from "remotion";
import {CARD_ASSETS, CARD_COMPONENTS} from "./cards";
import {CARD_DURATIONS, CARD_HEIGHT, CARD_WIDTH} from "./data";
import {SubtitleOverlay} from "./SubtitleOverlay";

interface CardNewsVerticalVideoProps {
  cardDurations?: number[];
  showSubtitles?: boolean;
}

const cardScale = 0.9;

export const CardNewsVerticalVideo: React.FC<CardNewsVerticalVideoProps> = ({
  cardDurations = CARD_DURATIONS,
  showSubtitles = true,
}) => {
  return (
    <AbsoluteFill style={{backgroundColor: "#050505"}}>
      <Audio src={staticFile("narration.mp3")} />

      <Series>
        {cardDurations.map((durationInFrames, index) => {
          const CardComponent = CARD_COMPONENTS[index];
          const assetName = CARD_ASSETS[index];

          return (
            <Series.Sequence key={assetName} durationInFrames={durationInFrames}>
              <AbsoluteFill style={{backgroundColor: "#050505"}}>
                <Img
                  src={staticFile(assetName)}
                  style={{
                    width: "100%",
                    height: "100%",
                    objectFit: "cover",
                    filter: "blur(36px) saturate(0.95) brightness(0.45)",
                    transform: "scale(1.14)",
                  }}
                />
                <AbsoluteFill
                  style={{
                    background:
                      "linear-gradient(180deg, rgba(5,5,5,0.18) 0%, rgba(5,5,5,0.5) 100%)",
                  }}
                />

                <div
                  style={{
                    position: "absolute",
                    top: 120,
                    left: "50%",
                    width: CARD_WIDTH,
                    height: CARD_HEIGHT,
                    transform: `translateX(-50%) scale(${cardScale})`,
                    transformOrigin: "top center",
                  }}
                >
                  <div
                    style={{
                      position: "relative",
                      width: "100%",
                      height: "100%",
                      overflow: "hidden",
                      borderRadius: 40,
                      boxShadow: "0 34px 100px rgba(0, 0, 0, 0.38)",
                    }}
                  >
                    <CardComponent durationInFrames={durationInFrames} />
                  </div>
                </div>

                {showSubtitles ? <SubtitleOverlay bottom={170} maxWidth={900} /> : null}
              </AbsoluteFill>
            </Series.Sequence>
          );
        })}
      </Series>
    </AbsoluteFill>
  );
};
