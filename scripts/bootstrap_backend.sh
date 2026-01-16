#!/usr/bin/env bash
set -euo pipefail

need(){ command -v "$1" >/dev/null 2>&1; }
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=============================="
echo " Backend bootstrap (use existing backend/)"
echo "=============================="

sudo apt update -y
sudo apt install -y curl unzip

if ! need gh; then sudo apt install -y gh; fi
if ! need fly; then curl -L https://fly.io/install.sh | sh; fi
export PATH="$HOME/.fly/bin:$PATH"

gh auth status >/dev/null 2>&1 || { echo "!! Run: gh auth login"; exit 1; }
fly auth whoami >/dev/null 2>&1 || { echo "!! Run: fly auth login"; exit 1; }

OWNER="$(gh api user -q .login)"
OPS_REPO="${OPS_REPO:-bd-home-${OWNER}}"
FLY_APP="${FLY_APP:-bd-homepage-${OWNER}}"

echo "==> Owner: $OWNER"
echo "==> Ops repo: ${OWNER}/${OPS_REPO}"
echo "==> Fly app: $FLY_APP"

BACKEND_DIR="$ROOT_DIR/backend"
[ -d "$BACKEND_DIR" ] || { echo "!! backend/ not found at $BACKEND_DIR"; exit 1; }

# fly.toml app 이름 고정
if [ ! -f "$BACKEND_DIR/fly.toml" ]; then
  echo "!! fly.toml not found in backend/. Create it or commit it in template."
  exit 1
fi

if grep -q '^app = ' "$BACKEND_DIR/fly.toml"; then
  sed -i "s/^app = \".*\"/app = \"${FLY_APP}\"/" "$BACKEND_DIR/fly.toml"
else
  printf 'app = "%s"\n%s' "$FLY_APP" "$(cat "$BACKEND_DIR/fly.toml")" > "$BACKEND_DIR/fly.toml"
fi

# fly app 없으면 생성
fly status -a "$FLY_APP" >/dev/null 2>&1 || fly apps create "$FLY_APP" --org personal >/dev/null

# deploy token -> GitHub repo secret 주입 (운영 repo에 넣기)
TOKEN="$(fly tokens create deploy --app "${FLY_APP}" | tail -n 1 | tr -d '\r')"
[ -n "$TOKEN" ] || { echo "!! Failed to create Fly token"; exit 1; }

gh secret set FLY_API_TOKEN -b"$TOKEN" -R "${OWNER}/${OPS_REPO}"

echo "✅ backend ready and Fly secret set."
