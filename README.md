**BD HomePage**

**전체 구조**
bd-home-template/

├─ backend/              # (자동 생성됨) Spring Boot 백엔드

├─ frontend/             # (자동 생성됨) 정적 HTML/JS 프론트

├─ scripts/              # 운영자용 bootstrap 스크립트

├─ .github/workflows/    # CI/CD (Fly.io, GitHub Pages)

└─ README.md


⚠️ backend/, frontend/는 스크립트 실행 시 자동 생성됩니다.
⚠️ 스크립트 실행 시 GitHub 또는 Fly.io에 로그인되어 있지 않으면 자동으로 로그인 안내가 표시되며, 최초 1회 인증 후 계속 진행됩니다.


**사용 방법**

0️⃣ 사전 준비
GitHub 계정
Fly.io 계정 (무료)
WSL 또는 Linux/macOS 환경

1️⃣ 템플릿 clone
git clone https://github.com/<owner>/bd-home-template.git
cd bd-home-template

2️⃣ 스크립트 실행 권한 부여
chmod +x scripts/*.sh

3️⃣ 운영 레포 / 앱 이름 지정 후 실행
export OPS_REPO="bd-home-<github-id>"
export FLY_APP="bd-homepage-<github-id>"
./scripts/bootstrap_owner.sh

4️⃣ 배포 확인
GitHub Actions 탭에서 모두 초록 표시(✅) 인지 확인



**배포 결과물**

스크립트 실행 후 아래 두 개가 자동으로 생성됩니다.

1️⃣ 프론트엔드 (GitHub Pages)
URL 예시: https://<github-id>.github.io/<repo-name>/

2️⃣ 백엔드 (Fly.io)
Health Check 엔드포인트: https://<fly-app-name>.fly.dev/api/health



**Dev Stack **

Backend: Spring Boot + Fly.io
Frontend: HTML / JS + GitHub Pages
CI/CD: GitHub Actions
