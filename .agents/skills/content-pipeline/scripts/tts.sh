#!/usr/bin/env bash
set -euo pipefail
# edge-tts 래퍼 스크립트 — 텍스트 파일을 MP3 음성으로 변환

INPUT_FILE="${1:-}"
OUTPUT_FILE="${2:-}"
VOICE="${3:-ko-KR-SunHiNeural}"

# 의존성 확인
if ! command -v edge-tts &> /dev/null; then
    echo "❌ edge-tts가 설치되어 있지 않아요." >&2
    echo "   설치: pip install edge-tts" >&2
    exit 1
fi

# 입력 확인
if [[ -z "$INPUT_FILE" || -z "$OUTPUT_FILE" ]]; then
    echo "사용법: $0 <입력텍스트파일> <출력mp3파일> [음성이름]" >&2
    echo "  기본 음성: ko-KR-SunHiNeural" >&2
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "❌ 입력 파일을 찾을 수 없어요: $INPUT_FILE" >&2
    exit 1
fi

# 출력 디렉토리 생성
mkdir -p "$(dirname "$OUTPUT_FILE")"

# TTS 실행
TEXT=$(cat "$INPUT_FILE")
echo "🎙️ 음성 생성 중... (음성: $VOICE)"
edge-tts --voice "$VOICE" --text "$TEXT" --write-media "$OUTPUT_FILE"

if [[ -f "$OUTPUT_FILE" ]]; then
    echo "✅ 음성 파일 생성 완료: $OUTPUT_FILE"
else
    echo "❌ 음성 파일 생성에 실패했어요." >&2
    exit 1
fi
