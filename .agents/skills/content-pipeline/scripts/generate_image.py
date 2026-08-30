#!/usr/bin/env python3
# NanoBanana Image Generator — google-genai SDK 기반
# 3가지 모드 지원: generate(새 생성), edit(이미지 편집), chat(멀티턴 세션)

import sys
import os
import json
import base64
import argparse
import uuid
from datetime import datetime
from pathlib import Path


# ── .env 로드 ──────────────────────────────────

def load_env(env_file):
    env_path = Path(env_file)
    if not env_path.exists():
        _exit_error("ENV_NOT_FOUND",
                    f".env 파일을 찾을 수 없습니다: {env_file}\n"
                    ".env.example을 복사해서 .env를 만들고 API 키를 입력하세요.")
    env = {}
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                key, _, value = line.partition('=')
                env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def preflight_check(env):
    if not env.get('NANOBANANA_API_KEY'):
        _exit_error("MISSING_CONFIG",
                    "NANOBANANA_API_KEY가 .env에 설정되지 않았습니다.")


# ── 공통 유틸 ──────────────────────────────────

def _exit_error(code, message):
    print(json.dumps({"success": False, "error": code, "message": message},
                     ensure_ascii=False))
    sys.exit(1)


def _import_sdk():
    try:
        from google import genai
        from google.genai import types
        return genai, types
    except ImportError:
        _exit_error("MISSING_DEPENDENCY",
                    "google-genai 라이브러리가 필요합니다.\n설치: pip install google-genai")


def _import_pil():
    try:
        from PIL import Image
        return Image
    except ImportError:
        _exit_error("MISSING_DEPENDENCY",
                    "Pillow 라이브러리가 필요합니다.\n설치: pip install Pillow")


def _create_client(env):
    genai, types = _import_sdk()
    client = genai.Client(api_key=env['NANOBANANA_API_KEY'])
    return client, types


def _build_config(types, aspect_ratio=None, image_size=None, thinking_level=None):
    config_dict = {
        "response_modalities": ["IMAGE", "TEXT"],
    }
    if aspect_ratio or image_size:
        img_kwargs = {}
        if aspect_ratio:
            img_kwargs["aspect_ratio"] = aspect_ratio
        if image_size:
            img_kwargs["image_size"] = image_size
        config_dict["image_config"] = types.ImageConfig(**img_kwargs)
    if thinking_level:
        config_dict["thinking_config"] = types.ThinkingConfig(thinking_level=thinking_level)
    return types.GenerateContentConfig(**config_dict)


def _build_config_without_thinking(types, aspect_ratio=None, image_size=None):
    """thinking_config 없이 config 생성 (미지원 모델 폴백용)."""
    return _build_config(types, aspect_ratio, image_size, thinking_level=None)


def _call_with_thinking_fallback(api_func, types, aspect_ratio, image_size, thinking_level, **kwargs):
    """API 호출 시 thinking_level 미지원이면 자동으로 빼고 재시도."""
    config = _build_config(types, aspect_ratio, image_size, thinking_level)
    try:
        return api_func(config=config, **kwargs)
    except Exception as exc:
        if "thinking" in str(exc).lower() or "Thinking level" in str(exc):
            config_no_think = _build_config_without_thinking(types, aspect_ratio, image_size)
            return api_func(config=config_no_think, **kwargs)
        raise


def _save_image(image_bytes, output_path):
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(output, 'wb') as f:
            f.write(image_bytes)
    except Exception as e:
        _exit_error("SAVE_ERROR", f"이미지 저장에 실패했습니다: {e}")
    return str(output.resolve()), round(len(image_bytes) / 1024, 1)


def _extract_response(response):
    image_bytes = None
    text_response = None
    candidates = getattr(response, 'candidates', []) or []
    for candidate in candidates:
        content = getattr(candidate, 'content', None)
        if not content:
            continue
        for part in getattr(content, 'parts', []):
            inline_data = getattr(part, 'inline_data', None)
            if inline_data:
                raw = getattr(inline_data, 'data', None)
                if raw:
                    if isinstance(raw, (bytes, bytearray)):
                        image_bytes = bytes(raw)
                    else:
                        image_bytes = base64.b64decode(raw)
            text = getattr(part, 'text', None)
            if text:
                text_response = text
    return image_bytes, text_response


def _handle_error(exc):
    try:
        from google.api_core import exceptions as gexc
        error_map = {
            gexc.Unauthenticated: ("AUTH_ERROR", "API 인증에 실패했습니다. .env의 NANOBANANA_API_KEY를 확인하세요."),
            gexc.PermissionDenied: ("AUTH_ERROR", "API 접근 권한이 없습니다. API 키 권한을 확인하세요."),
            gexc.ResourceExhausted: ("RATE_LIMIT", "API 요청 한도에 도달했습니다. 잠시 후 다시 시도하세요."),
            gexc.DeadlineExceeded: ("TIMEOUT", "API 요청 시간이 초과되었습니다. 다시 시도하세요."),
            gexc.InternalServerError: ("SERVER_ERROR", "API 서버 내부 오류입니다. 잠시 후 다시 시도하세요."),
            gexc.ServiceUnavailable: ("SERVER_ERROR", "API 서비스를 일시적으로 사용할 수 없습니다."),
            gexc.InvalidArgument: ("INVALID_REQUEST", f"잘못된 요청입니다: {exc}"),
            gexc.NotFound: ("MODEL_NOT_FOUND", f"모델을 찾을 수 없습니다. .env의 NANOBANANA_MODEL을 확인하세요."),
        }
        for exc_type, (code, msg) in error_map.items():
            if isinstance(exc, exc_type):
                _exit_error(code, msg)
    except ImportError:
        pass
    _exit_error("UNKNOWN_ERROR", f"예상치 못한 오류: {type(exc).__name__}: {exc}")


# ── generate 모드 ──────────────────────────────

def generate_image(client, types, prompt, output, env,
                   aspect_ratio=None, image_size=None, thinking_level=None):
    model = env.get('NANOBANANA_MODEL', 'gemini-3-pro-image-preview')

    try:
        def _gen_call(config, **kw):
            return client.models.generate_content(model=model, contents=prompt, config=config)
        response = _call_with_thinking_fallback(
            _gen_call, types, aspect_ratio, image_size, thinking_level)
    except Exception as exc:
        _handle_error(exc)

    image_bytes, text_response = _extract_response(response)
    if not image_bytes:
        _exit_error("NO_IMAGE",
                    "API가 이미지를 생성하지 못했습니다."
                    + (f" 응답: {text_response}" if text_response else ""))

    saved_path, size_kb = _save_image(image_bytes, output)
    return {
        "success": True,
        "output_path": saved_path,
        "file_size_kb": size_kb,
        "model": model,
        "mode": "generate",
        "aspect_ratio": aspect_ratio,
        "image_size": image_size,
        "text_response": text_response,
    }


# ── edit 모드 ──────────────────────────────────

def edit_image(client, types, prompt, image_path, output, env,
               aspect_ratio=None, image_size=None, thinking_level=None):
    Image = _import_pil()
    model = env.get('NANOBANANA_MODEL', 'gemini-3-pro-image-preview')

    input_path = Path(image_path)
    if not input_path.exists():
        _exit_error("IMAGE_NOT_FOUND", f"입력 이미지를 찾을 수 없습니다: {image_path}")

    supported = {'.png', '.jpg', '.jpeg', '.webp'}
    if input_path.suffix.lower() not in supported:
        _exit_error("UNSUPPORTED_FORMAT",
                    f"지원하지 않는 포맷입니다. PNG, JPEG, WEBP만 가능합니다. (현재: {input_path.suffix})")

    file_size_mb = input_path.stat().st_size / (1024 * 1024)
    if file_size_mb > 20:
        _exit_error("IMAGE_TOO_LARGE",
                    f"이미지가 너무 큽니다 ({file_size_mb:.1f}MB). 최대 20MB.")

    try:
        pil_image = Image.open(input_path)
        pil_image.verify()
        pil_image = Image.open(input_path)  # verify 후 재오픈
    except Exception:
        _exit_error("IMAGE_CORRUPT", "이미지 파일이 손상되었습니다.")

    w, h = pil_image.size
    if w < 64 or h < 64:
        _exit_error("IMAGE_TOO_SMALL",
                    f"해상도가 너무 낮습니다 ({w}x{h}). 최소 64x64px.")

    try:
        def _edit_call(config, **kw):
            return client.models.generate_content(
                model=model, contents=[prompt, pil_image], config=config)
        response = _call_with_thinking_fallback(
            _edit_call, types, aspect_ratio, image_size, thinking_level)
    except Exception as exc:
        _handle_error(exc)

    image_bytes, text_response = _extract_response(response)
    if not image_bytes:
        _exit_error("NO_IMAGE",
                    "API가 이미지를 편집하지 못했습니다."
                    + (f" 응답: {text_response}" if text_response else ""))

    saved_path, size_kb = _save_image(image_bytes, output)
    return {
        "success": True,
        "output_path": saved_path,
        "file_size_kb": size_kb,
        "model": model,
        "mode": "edit",
        "source_image": str(input_path.resolve()),
        "text_response": text_response,
    }


# ── chat 모드 (멀티턴) ────────────────────────

def chat_session(client, types, prompt, output, env,
                 session_id=None, aspect_ratio=None, image_size=None,
                 thinking_level=None):
    model = env.get('NANOBANANA_MODEL', 'gemini-3-pro-image-preview')
    config = _build_config(types, aspect_ratio, image_size, thinking_level)

    sid = session_id or f"nb_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    session_dir = Path(output).parent / ".sessions"
    session_dir.mkdir(parents=True, exist_ok=True)
    session_file = session_dir / f"{sid}.json"

    # 히스토리 복원
    history = []
    if session_file.exists():
        try:
            with open(session_file) as f:
                history = json.load(f)
        except Exception:
            history = []

    # SDK Content 객체로 변환
    sdk_history = []
    for turn in history:
        parts = []
        for p in turn.get("parts", []):
            if "text" in p:
                parts.append(types.Part.from_text(text=p["text"]))
        if parts:
            sdk_history.append(types.Content(role=turn["role"], parts=parts))

    # 히스토리 윈도우 (첫 턴 + 최근 5턴 = 최대 6턴)
    MAX_TURNS = 6
    if len(sdk_history) > MAX_TURNS * 2:
        sdk_history = sdk_history[:2] + sdk_history[-(MAX_TURNS - 1) * 2:]

    # 이미지 프리뷰 모델은 thinking을 지원하지 않으므로 chat 모드에서는 무시
    config = _build_config(types, aspect_ratio, image_size, thinking_level=None)
    try:
        chat = client.chats.create(
            model=model, history=sdk_history, config=config
        )
        response = chat.send_message(prompt)
    except Exception as exc:
        # 세션 만료 시 새 세션으로 자동 전환
        err_str = str(exc).lower()
        if "session" in err_str or "history" in err_str or "context" in err_str:
            try:
                chat = client.chats.create(model=model, config=config)
                response = chat.send_message(prompt)
                sid = f"nb_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                session_file = session_dir / f"{sid}.json"
                history = []
            except Exception as exc2:
                _handle_error(exc2)
        else:
            _handle_error(exc)

    image_bytes, text_response = _extract_response(response)

    # 히스토리 저장 (텍스트만)
    new_history = history + [
        {"role": "user", "parts": [{"text": prompt}]},
        {"role": "model", "parts": [{"text": text_response or ""}]},
    ]
    try:
        with open(session_file, 'w') as f:
            json.dump(new_history, f, ensure_ascii=False, indent=2)
    except Exception:
        pass  # 세션 저장 실패는 치명적이지 않음

    if not image_bytes:
        return {
            "success": True,
            "output_path": None,
            "session_id": sid,
            "model": model,
            "mode": "chat",
            "text_response": text_response,
        }

    saved_path, size_kb = _save_image(image_bytes, output)
    return {
        "success": True,
        "output_path": saved_path,
        "file_size_kb": size_kb,
        "session_id": sid,
        "model": model,
        "mode": "chat",
        "text_response": text_response,
    }


# ── CLI 진입점 ─────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description='NanoBanana Image Generator (google-genai SDK)')
    parser.add_argument('--mode', choices=['generate', 'edit', 'chat'],
                        default='generate')
    parser.add_argument('--prompt', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--env-file', required=True)
    parser.add_argument('--image', default=None,
                        help='편집할 원본 이미지 (edit 모드)')
    parser.add_argument('--session-id', default=None,
                        help='세션 ID (chat 모드)')
    parser.add_argument('--aspect-ratio', default=None,
                        choices=['1:1', '16:9', '9:16', '4:3', '3:4', '4:1', '1:4'])
    parser.add_argument('--image-size', default=None,
                        choices=['512', '1K', '2K', '4K'])
    parser.add_argument('--thinking-level', default=None,
                        choices=['minimal', 'high'])
    args = parser.parse_args()

    if not args.prompt.strip():
        _exit_error("EMPTY_PROMPT", "프롬프트가 비어 있습니다.")

    # 모드 자동 감지
    mode = args.mode
    if mode == 'generate' and args.image:
        mode = 'edit'
    elif mode == 'generate' and args.session_id:
        mode = 'chat'

    if mode == 'edit' and not args.image:
        _exit_error("MISSING_IMAGE", "edit 모드에서는 --image가 필요합니다.")

    env = load_env(args.env_file)
    preflight_check(env)

    # .env 기본값 적용 (CLI 인수가 우선)
    ar = args.aspect_ratio or env.get('NANOBANANA_ASPECT_RATIO') or None
    isz = args.image_size or env.get('NANOBANANA_IMAGE_SIZE') or None
    tl = args.thinking_level or env.get('NANOBANANA_THINKING_LEVEL') or None

    client, types = _create_client(env)

    if mode == 'generate':
        result = generate_image(client, types, args.prompt, args.output, env,
                                aspect_ratio=ar, image_size=isz, thinking_level=tl)
    elif mode == 'edit':
        result = edit_image(client, types, args.prompt, args.image, args.output, env,
                            aspect_ratio=ar, image_size=isz, thinking_level=tl)
    elif mode == 'chat':
        result = chat_session(client, types, args.prompt, args.output, env,
                              session_id=args.session_id,
                              aspect_ratio=ar, image_size=isz, thinking_level=tl)

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
