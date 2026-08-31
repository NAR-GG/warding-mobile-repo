import React from "react";
import { Composition } from "remotion";
import { CardNewsVideo } from "./CardNewsVideo";
import { CardNewsVerticalVideo } from "./CardNewsVerticalVideo";
import {
  CARD_DURATIONS,
  CARD_HEIGHT,
  CARD_WIDTH,
  FPS,
  TOTAL_FRAMES,
  VERTICAL_HEIGHT,
  VERTICAL_WIDTH,
} from "./data";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="CardNewsVideo"
        component={CardNewsVideo}
        durationInFrames={TOTAL_FRAMES}
        fps={FPS}
        width={CARD_WIDTH}
        height={CARD_HEIGHT}
        defaultProps={{
          cardDurations: CARD_DURATIONS,
          showSubtitles: true,
        }}
      />
      <Composition
        id="CardNewsVideoClean"
        component={CardNewsVideo}
        durationInFrames={TOTAL_FRAMES}
        fps={FPS}
        width={CARD_WIDTH}
        height={CARD_HEIGHT}
        defaultProps={{
          cardDurations: CARD_DURATIONS,
          showSubtitles: false,
        }}
      />
      <Composition
        id="CardNewsVerticalVideo"
        component={CardNewsVerticalVideo}
        durationInFrames={TOTAL_FRAMES}
        fps={FPS}
        width={VERTICAL_WIDTH}
        height={VERTICAL_HEIGHT}
        defaultProps={{
          cardDurations: CARD_DURATIONS,
          showSubtitles: true,
        }}
      />
      <Composition
        id="CardNewsVerticalVideoClean"
        component={CardNewsVerticalVideo}
        durationInFrames={TOTAL_FRAMES}
        fps={FPS}
        width={VERTICAL_WIDTH}
        height={VERTICAL_HEIGHT}
        defaultProps={{
          cardDurations: CARD_DURATIONS,
          showSubtitles: false,
        }}
      />
    </>
  );
};
