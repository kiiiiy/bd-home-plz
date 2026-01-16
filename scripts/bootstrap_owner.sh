#!/usr/bin/env bash
set -euo pipefail

need(){ command -v "$1" >/dev/null 2>&1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> bd-home-template (monorepo) owner bootstrap"
echo "==> Repo root: $ROOT_DIR"
echo

# 0) tools
echo "==> Install base tools"
sudo apt update -y
sudo apt install -y git curl unzip

if ! need gh; then
  sudo apt install -y gh
fi

if ! need fly; then
  curl -L https://fly.io/install.sh | sh
fi
export PATH="$HOME/.fly/bin:$PATH"


# 1) auth
echo "==> Auth check (1-time browser login if needed)"
gh auth status >/dev/null 2>&1 || { echo "!! Run: gh auth login"; exit 1; }
fly auth whoami >/dev/null 2>&1 || { echo "!! Run: fly auth login"; exit 1; }

OWNER="$(gh api user -q .login)"
echo "==> GitHub owner: $OWNER"

OPS_REPO="${OPS_REPO:-bd-home-${OWNER}}"
VISIBILITY="${VISIBILITY:-public}"   # Pages 쓰려면 public 권장

echo "==> Target 운영 repo: ${OWNER}/${OPS_REPO} (${VISIBILITY})"

if ! gh repo view "${OWNER}/${OPS_REPO}" >/dev/null 2>&1; then
  gh repo create "${OPS_REPO}" --"${VISIBILITY}"
fi

git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/${OWNER}/${OPS_REPO}.git"


git add -A || true
git commit -m "chore: init from bd-home-template" || true
git branch -M main
git push -u origin main --force-with-lease


echo
echo "==> Setup backend & frontend inside this repo"
./scripts/bootstrap_backend.sh
./scripts/bootstrap_frontend.sh

echo
echo "==> Fly app bootstrap & GitHub secret setup"

APP_NAME="bd-homepage-${OWNER}"
if [ -d "${ROOT_DIR}/backend" ]; then
  BACKEND_DIR="${ROOT_DIR}/backend"
elif [ -d "${ROOT_DIR}/bd-home-template/backend" ]; then
  BACKEND_DIR="${ROOT_DIR}/bd-home-template/backend"
else
  echo "!! backend directory not found"
  exit 1
fi

cd "$BACKEND_DIR"

fly status -a "$APP_NAME" >/dev/null 2>&1 || fly apps create "$APP_NAME" --org personal >/dev/null

if [ ! -f fly.toml ]; then
  fly launch --name "$APP_NAME" --region nrt --no-deploy --dockerfile Dockerfile
fi

if grep -q '^app = ' fly.toml; then
  sed -i "s/^app = \".*\"/app = \"${APP_NAME}\"/" fly.toml
else
  printf 'app = "%s"\n%s' "$APP_NAME" "$(cat fly.toml)" > fly.toml
fi

# GitHub Actions에서 fly deploy 하도록 토큰을 repo secret으로 주입
FLY_API_TOKEN="$(fly auth token)"
cd "$ROOT_DIR"
echo "==> Fly app: $APP_NAME"


echo
echo "==> Push generated contents"
for i in 1 2 3; do
  gh secret set FLY_API_TOKEN -b"$FLY_API_TOKEN" -R "${OWNER}/${OPS_REPO}" && break
  sleep 2
done

git add -A
git commit -m "chore: generate backend/frontend & workflows" || true
git push

echo
echo "✅ Done."
echo "- Backend deploy: GitHub Actions -> Fly"
echo "- Frontend deploy: GitHub Actions -> GitHub Pages"
echo
echo "Check:"
echo "  GitHub repo: https://github.com/${OWNER}/${OPS_REPO}"
echo "  (After first backend deploy) Fly URL: https://bd-homepage-${OWNER}.fly.dev/api/health"
echo "  Pages URL: https://${OWNER}.github.io/${OPS_REPO}/"
