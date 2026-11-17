#!/usr/bin/env python3
"""App Store Connect 에서 "지금 심사/출시 줄에 선 버전"의 상태를 조회한다.

심사 제출 워크플로우(submit-for-review.yml)가 제출 전후로 두 번 부른다.

왜 필요한가 — 1.0.41 사고
--------------------------
deliver 는 ASC 의 버전 문자열·패치노트를 먼저 바꾸고, 그다음에 빌드를 붙인다.
그런데 그 버전이 이미 `Waiting For Review` 면 ASC 가 빌드 교체를 거부한다.
결과로 **버전 문자열과 패치노트만 새 버전으로 갈아입고 바이너리는 옛 빌드로
남은** 상태가 만들어지고, 그대로 승인·출시됐다.

사용자 쪽에서는 이렇게 보였다.
  - 스토어 표시 1.0.41 / 실제 코드 1.0.39(빌드 89)
  - 설치본과 스토어본의 빌드 번호가 똑같이 89 → 업데이트 버튼이 아무 일도 안 함
  - 앱 버전(1.0.39) ≠ 스토어 메타데이터(1.0.41) → upgrader 팝업이 매번 뜸

워크플로우는 초록불이었다. deliver 가 실패하며 남긴
`The app store version is in Waiting For Review.` 를 "같은 버전을 두 번 제출한
것" 으로 오인하는 가드가 `exit 0` 했기 때문이다. 두 경우가 **같은 문자열**을
내보내서 로그만으로는 구분할 수 없다. 그래서 ASC 에 사실을 직접 물어본다.

출력
----
`KEY=VALUE` 줄들을 stdout 에 쓴다 (워크플로우가 그대로 읽는다).
조회가 성공하면 `ok=true` 가 반드시 들어간다.

    ok=true
    version=1.0.42          편집 가능한 버전의 버전 문자열 (없으면 빈 값)
    state=WAITING_FOR_REVIEW
    build=92                그 버전에 붙은 빌드 번호 (안 붙어 있으면 빈 값)
    editable=false          지금 빌드를 바꿔 끼울 수 있는 상태인가

실패하면 `ok=false` 와 `error=...` 만 쓰고 종료 코드 0 으로 끝낸다. 조회 실패가
곧 "제출하면 안 된다" 는 뜻은 아니므로, 판단은 부르는 쪽에 맡긴다.

필요한 환경 변수: ASC_KEY_P8(base64 로 감싼 .p8 내용), ASC_KEY_ID, ASC_ISSUER_ID
"""

import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

APP_ID = "com.nar.wardingapp"

# 이 상태의 버전에는 빌드를 바꿔 끼울 수 있다. ASC 가 쓰는 이름 그대로다.
# 그 밖(WAITING_FOR_REVIEW·IN_REVIEW·PENDING_DEVELOPER_RELEASE 등)이면
# 빌드 교체가 거부되고, 1.0.41 사고의 조건이 된다.
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}


def emit(**kv):
    """KEY=VALUE 줄로 결과를 쓴다. 값의 줄바꿈은 지운다 — 한 줄 = 한 항목."""
    for k, v in kv.items():
        print(f"{k}={str(v).replace(chr(10), ' ').strip()}")


def token():
    """ASC API 용 ES256 JWT 를 만든다.

    openssl 로 서명한다. PyJWT 를 쓰면 러너에 pip 설치가 필요한데, 여기서
    필요한 건 서명 한 번뿐이라 의존성을 늘릴 이유가 없다 (release-deploy.yml
    의 Play 토큰 발급도 같은 방식이다).

    openssl 의 ECDSA 서명은 DER 인데 JWT 는 raw r||s 를 요구해서, DER 을
    직접 풀어 32 바이트씩 이어 붙인다.
    """
    key_id = os.environ["ASC_KEY_ID"]
    issuer = os.environ["ASC_ISSUER_ID"]
    p8 = base64.b64decode(os.environ["ASC_KEY_P8"])

    def b64(raw):
        return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

    now = int(time.time())
    header = b64(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    # aud 는 고정값이고, exp 는 20 분 안쪽이어야 Apple 이 받는다.
    claims = b64(
        json.dumps(
            {"iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
        ).encode()
    )
    signing_input = f"{header}.{claims}".encode()

    with tempfile.NamedTemporaryFile(suffix=".p8", delete=False) as f:
        f.write(p8)
        key_path = f.name
    try:
        der = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_path],
            input=signing_input,
            capture_output=True,
            check=True,
        ).stdout
    finally:
        os.unlink(key_path)

    # DER: 30 <len> 02 <rlen> <r> 02 <slen> <s>
    i = 4 if der[1] & 0x80 == 0 else 5  # 전체 길이가 long-form 이면 한 바이트 더
    r_len = der[i - 1]
    r = der[i : i + r_len]
    s_len = der[i + r_len + 1]
    s = der[i + r_len + 2 : i + r_len + 2 + s_len]
    # 앞의 0x00 패딩은 떼고, 32 바이트로 왼쪽을 0 으로 채운다.
    r = r.lstrip(b"\x00").rjust(32, b"\x00")
    s = s.lstrip(b"\x00").rjust(32, b"\x00")

    return f"{header}.{claims}.{b64(r + s)}"


def get(url, tok):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {tok}"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def main():
    try:
        tok = token()
    except Exception as e:  # 키가 잘못됐거나 openssl 이 없는 경우
        emit(ok="false", error=f"토큰 발급 실패: {e}")
        return 0

    base = "https://api.appstoreconnect.apple.com/v1"
    try:
        apps = get(f"{base}/apps?filter[bundleId]={APP_ID}", tok)
        if not apps.get("data"):
            emit(ok="false", error=f"앱을 못 찾았다: {APP_ID}")
            return 0
        app_id = apps["data"][0]["id"]

        # appStoreVersions 는 최신순이다. 맨 앞 하나가 "지금 줄에 선 버전" 이다
        # (이미 출시 완료된 과거 버전들도 같은 목록에 들어 있다).
        versions = get(
            f"{base}/apps/{app_id}/appStoreVersions"
            "?limit=1&fields[appStoreVersions]=versionString,appStoreState",
            tok,
        )
        if not versions.get("data"):
            emit(ok="true", version="", state="", build="", editable="true")
            return 0

        v = versions["data"][0]
        state = v["attributes"].get("appStoreState") or ""
        version_string = v["attributes"].get("versionString") or ""

        # 그 버전에 실제로 붙어 있는 빌드. 이것이 이번 사고의 핵심 값이다 —
        # 버전 문자열이 바뀌어도 이 값은 따라오지 않는다.
        build = ""
        try:
            b = get(
                f"{base}/appStoreVersions/{v['id']}/build?fields[builds]=version", tok
            )
            if b.get("data"):
                build = b["data"]["attributes"].get("version") or ""
        except urllib.error.HTTPError as e:
            # 빌드가 아직 안 붙은 버전은 404 를 준다 — 오류가 아니라 "없음" 이다.
            if e.code != 404:
                raise

        emit(
            ok="true",
            version=version_string,
            state=state,
            build=build,
            editable=str(state in EDITABLE_STATES).lower(),
        )
    except Exception as e:
        emit(ok="false", error=f"ASC 조회 실패: {e}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
