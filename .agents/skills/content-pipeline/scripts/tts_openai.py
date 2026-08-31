#!/usr/bin/env python3
# OpenAI TTS 음성 생성 스크립트
# 2가지 모드: 전체 파일 → 단일 MP3 / 섹션별 분리 → 카드별 MP3 + timings JSON
import sys
import json
import argparse
import subprocess
from pathlib import Path


def load_env(env_file):
    env = {}
    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                key, _, value = line.partition('=')
                env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def strip_markdown(text):
    """마크다운 문법 제거 → 순수 나레이션 텍스트"""
    lines = []
    for line in text.split('\n'):
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or stripped.startswith('---') or stripped.startswith('>'):
            continue
        lines.append(stripped)
    return '\n'.join(lines).strip()


def parse_sections(md_text):
    """## 헤더 기준으로 섹션 분리 → [{title, text}]"""
    sections = []
    current_title = None
    current_lines = []

    for line in md_text.split('\n'):
        stripped = line.strip()
        if stripped.startswith('## '):
            if current_title is not None:
                text = strip_markdown('\n'.join(current_lines))
                if text:
                    sections.append({"title": current_title, "text": text})
            current_title = stripped[3:].strip()
            current_lines = []
        else:
            current_lines.append(line)

    if current_title is not None:
        text = strip_markdown('\n'.join(current_lines))
        if text:
            sections.append({"title": current_title, "text": text})

    return sections


def get_duration(filepath):
    """ffprobe로 MP3 재생 시간 측정"""
    try:
        result = subprocess.run(
            ['ffprobe', '-v', 'quiet', '-show_entries', 'format=duration',
             '-of', 'csv=p=0', str(filepath)],
            capture_output=True, text=True
        )
        return float(result.stdout.strip()) if result.stdout.strip() else 0
    except Exception:
        return 0


def generate_single(client, model, voice, text, output_path):
    """단일 MP3 생성"""
    response = client.audio.speech.create(model=model, voice=voice, input=text)
    response.stream_to_file(str(output_path))


def main():
    parser = argparse.ArgumentParser(description='OpenAI TTS 음성 생성')
    parser.add_argument('--input', required=True, help='입력 마크다운/텍스트 파일')
    parser.add_argument('--output', required=True, help='출력 경로 (파일 또는 디렉토리)')
    parser.add_argument('--voice', default='shimmer',
                        choices=['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'])
    parser.add_argument('--model', default='tts-1-hd')
    parser.add_argument('--env-file', required=True)
    parser.add_argument('--section-mode', action='store_true',
                        help='섹션별 분리 모드: ## 헤더 기준으로 카드별 MP3 생성 + card-timings.json')
    args = parser.parse_args()

    # .env 로드
    env_path = Path(args.env_file)
    if not env_path.exists():
        print(json.dumps({"success": False, "error": "ENV_NOT_FOUND",
                          "message": f".env 파일을 찾을 수 없습니다: {args.env_file}"}))
        sys.exit(1)

    env = load_env(args.env_file)
    api_key = env.get('OPENAI_API_KEY')
    if not api_key:
        print(json.dumps({"success": False, "error": "MISSING_KEY",
                          "message": "OPENAI_API_KEY가 .env에 설정되지 않았습니다."}))
        sys.exit(1)

    input_path = Path(args.input)
    if not input_path.exists():
        print(json.dumps({"success": False, "error": "INPUT_NOT_FOUND",
                          "message": f"입력 파일을 찾을 수 없습니다: {args.input}"}))
        sys.exit(1)

    try:
        from openai import OpenAI
    except ImportError:
        print(json.dumps({"success": False, "error": "MISSING_DEPENDENCY",
                          "message": "openai 라이브러리가 필요합니다.\n설치: pip install openai"}))
        sys.exit(1)

    client = OpenAI(api_key=api_key)
    raw_text = input_path.read_text(encoding='utf-8').strip()

    # ── 섹션 모드 ──
    if args.section_mode:
        sections = parse_sections(raw_text)
        if not sections:
            print(json.dumps({"success": False, "error": "NO_SECTIONS",
                              "message": "## 헤더로 구분된 섹션을 찾을 수 없습니다."}))
            sys.exit(1)

        output_dir = Path(args.output)
        output_dir.mkdir(parents=True, exist_ok=True)

        results = []
        for i, section in enumerate(sections):
            num = str(i + 1).zfill(2)
            mp3_path = output_dir / f"card-{num}.mp3"
            print(f"[{num}/{len(sections)}] {section['title'][:40]}...", file=sys.stderr)

            try:
                generate_single(client, args.model, args.voice, section['text'], mp3_path)
            except Exception as e:
                print(json.dumps({"success": False, "error": "TTS_ERROR",
                                  "message": f"카드 {num} TTS 실패: {e}"}))
                sys.exit(1)

            duration = get_duration(mp3_path)
            frames = round(duration * 30)
            results.append({
                "card": i + 1,
                "title": section['title'],
                "duration_sec": round(duration, 2),
                "frames": frames,
                "file": f"card-{num}.mp3"
            })

        # card-timings.json 저장
        timings_path = output_dir / "card-timings.json"
        with open(timings_path, 'w') as f:
            json.dump(results, f, ensure_ascii=False, indent=2)

        total_sec = sum(r['duration_sec'] for r in results)
        total_frames = sum(r['frames'] for r in results)
        print(json.dumps({
            "success": True,
            "mode": "section",
            "sections": len(results),
            "total_duration_sec": round(total_sec, 2),
            "total_frames": total_frames,
            "timings_path": str(timings_path.resolve()),
            "output_dir": str(output_dir.resolve()),
            "voice": args.voice,
            "model": args.model
        }, ensure_ascii=False))
        return

    # ── 단일 모드 (기본) ──
    text = strip_markdown(raw_text)
    if not text:
        print(json.dumps({"success": False, "error": "EMPTY_INPUT",
                          "message": "입력 파일이 비어 있습니다."}))
        sys.exit(1)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        generate_single(client, args.model, args.voice, text, output_path)
    except Exception as e:
        print(json.dumps({"success": False, "error": "TTS_ERROR",
                          "message": f"TTS 생성 실패: {e}"}))
        sys.exit(1)

    size_kb = round(output_path.stat().st_size / 1024, 1)
    print(json.dumps({
        "success": True,
        "mode": "single",
        "output_path": str(output_path.resolve()),
        "file_size_kb": size_kb,
        "voice": args.voice,
        "model": args.model
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
