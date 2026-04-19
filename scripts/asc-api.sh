#!/usr/bin/env bash
# Thin helper around the App Store Connect API.
#
# Generates a short-lived ES256 JWT from the same .p8 key that deploy.sh
# uses, then calls api.appstoreconnect.apple.com paths passed as the first
# argument. Any extra curl args (e.g. -X PATCH --data @…) pass through.
#
# Usage:
#   ./scripts/asc-api.sh /v1/apps
#   ./scripts/asc-api.sh /v1/apps/<id>/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION
#   ./scripts/asc-api.sh -X PATCH /v1/appStoreVersions/<versionId> --data-binary @/tmp/body.json

set -euo pipefail

cd "$(dirname "$0")/.."

[ -f .env ] && { set -a; . ./.env; set +a; }

: "${ASC_API_KEY_ID:?}"
: "${ASC_API_ISSUER_ID:?}"
: "${ASC_API_KEY_PATH:?}"
ASC_API_KEY_PATH=$(eval echo "$ASC_API_KEY_PATH")

# ES256 JWT signed with the private key. iat/exp are UNIX seconds; ASC
# caps exp at 20 min from now.
python3 - <<PY > /tmp/asc-token
import base64, json, time, subprocess, os
header = {"alg":"ES256","kid":os.environ["ASC_API_KEY_ID"],"typ":"JWT"}
now = int(time.time())
payload = {"iss":os.environ["ASC_API_ISSUER_ID"],"iat":now,"exp":now+19*60,"aud":"appstoreconnect-v1"}
def b64(d): return base64.urlsafe_b64encode(json.dumps(d,separators=(",",":")).encode()).rstrip(b"=").decode()
signing_input = f"{b64(header)}.{b64(payload)}"

# openssl can't output raw ES256 R||S directly; use cryptography if
# available, otherwise fall back to a two-step openssl + asn1parse.
try:
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec, utils as ecu
    with open(os.environ["ASC_API_KEY_PATH"], "rb") as f:
        key = serialization.load_pem_private_key(f.read(), password=None)
    der_sig = key.sign(signing_input.encode(), ec.ECDSA(hashes.SHA256()))
    r, s = ecu.decode_dss_signature(der_sig)
    raw = r.to_bytes(32, "big") + s.to_bytes(32, "big")
except ImportError:
    # Fallback: openssl dgst produces DER, reparse to raw R||S.
    der = subprocess.check_output(
        ["openssl","dgst","-sha256","-sign", os.environ["ASC_API_KEY_PATH"]],
        input=signing_input.encode())
    # minimal DER ECDSA decode
    assert der[0] == 0x30
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7f)
    assert der[i] == 0x02
    r_len = der[i+1]; r = der[i+2:i+2+r_len]
    j = i+2+r_len
    assert der[j] == 0x02
    s_len = der[j+1]; s = der[j+2:j+2+s_len]
    r = r.lstrip(b"\x00").rjust(32, b"\x00")
    s = s.lstrip(b"\x00").rjust(32, b"\x00")
    raw = r + s
sig = base64.urlsafe_b64encode(raw).rstrip(b"=").decode()
print(f"{signing_input}.{sig}", end="")
PY

TOKEN=$(cat /tmp/asc-token)
BASE="https://api.appstoreconnect.apple.com"

# Allow passing extra curl flags before the path; detect the path as the
# first argument that starts with '/'.
ARGS=()
PATH_ARG=""
for a in "$@"; do
    if [ -z "$PATH_ARG" ] && [[ "$a" == /* ]]; then
        PATH_ARG="$a"
    else
        ARGS+=("$a")
    fi
done

[ -n "$PATH_ARG" ] || { echo "usage: $0 [curl-args...] /v1/path" >&2; exit 2; }

curl -sS -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    ${ARGS[@]+"${ARGS[@]}"} "$BASE$PATH_ARG"
