#!/usr/bin/env bash
set -euo pipefail

need(){ command -v "$1" >/dev/null 2>&1; }
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "=============================="
echo " Backend bootstrap (sync from template)"
echo "=============================="

# tools
sudo apt update -y
sudo apt install -y curl unzip rsync git

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

# ---- 핵심: 템플릿 backend 위치 ----
TEMPLATE_BACKEND_DIR="$ROOT_DIR/bd-home-template/backend"
TARGET_BACKEND_DIR="$ROOT_DIR/backend"

if [ ! -d "$TEMPLATE_BACKEND_DIR" ]; then
  echo "!! template backend not found: $TEMPLATE_BACKEND_DIR"
  echo "   (Hint) run this in repo that contains bd-home-template/backend"
  exit 1
fi

echo "==> Sync template backend -> backend/"
rm -rf "$TARGET_BACKEND_DIR"
mkdir -p "$TARGET_BACKEND_DIR"
rsync -a --delete "$TEMPLATE_BACKEND_DIR"/ "$TARGET_BACKEND_DIR"/

# ---- Fly 설정: fly.toml app명만 소유자별로 교체 ----
if [ -f "$TARGET_BACKEND_DIR/fly.toml" ]; then
  if grep -q '^app = ' "$TARGET_BACKEND_DIR/fly.toml"; then
    sed -i "s/^app = \".*\"/app = \"${FLY_APP}\"/" "$TARGET_BACKEND_DIR/fly.toml"
  else
    printf 'app = "%s"\n%s' "$FLY_APP" "$(cat "$TARGET_BACKEND_DIR/fly.toml")" > "$TARGET_BACKEND_DIR/fly.toml"
  fi
fi

# ---- Fly 앱 생성 ----
fly status -a "$FLY_APP" >/dev/null 2>&1 || fly apps create "$FLY_APP" --org personal >/dev/null

# ---- GitHub Secret 주입 (repo 지정해서 넣는 게 제일 안전) ----
TOKEN="$(fly tokens create deploy --app "${FLY_APP}" | tail -n 1 | tr -d '\r')"
[ -n "$TOKEN" ] || { echo "!! Failed to create Fly token"; exit 1; }

gh secret set FLY_API_TOKEN -b"$TOKEN" -R "${OWNER}/${OPS_REPO}"

echo "✅ backend synced and Fly secret set."
