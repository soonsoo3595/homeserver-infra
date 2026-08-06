# HomeServer

노트북 한 대로 구축·운영하는 홈서버 프로젝트. 1차 서비스는 개인 블로그이며, 이후 같은 서버 위에 게임 서버 기능을 확장한다. 마감 없이 지속 가능성을 우선하는 개인 프로젝트다.

## 서버 환경

- 노트북 WSL2 (CPU i7-1260P / RAM 32GB / SSD 1TB)
- Ubuntu 24.04 LTS 위에서 Docker로 서비스 운영

## 진행 상황

- [x] WSL2 설치
- [x] Ubuntu 24.04 설치
- [x] WSL2 mirrored 네트워킹 모드 설정 (같은 LAN에서 노트북 IP로 직접 접근 가능)
- [x] SSH 서버 설치 및 systemd로 부팅 시 자동 시작 등록
- [x] Docker 설치
- [x] postgres, redis 컨테이너 구성 (SSH 터널 전용 접근)
- [x] 리버스 프록시(Traefik), 모니터링(Uptime Kuma) 컨테이너 구성
- [x] postgres 백업(pg_dumpall + cron, 7일 보관, 로컬 저장) 구성
- [x] UFW/Fail2ban 기초 보안 설정
- [x] Jenkins 컨테이너 구성 및 초기 설정
- [x] Meilisearch 컨테이너 구성 (블로그 검색용)
- [x] 블로그 레포 생성 및 개발 시작 — 진행 상황은 [blog/CLAUDE.md](../blog/CLAUDE.md) 참고
- [ ] Cloudflare Tunnel 외부 노출 설정 — **보류: 도메인 미보유, 구매 후 재개**

## 개발 환경 메모

- 노트북(우분투 서버)과 별개로 데스크탑에서 작업. 같은 LAN(iptime 공유기, 192.168.0.x)에서 SSH로 노트북에 접속 가능.
- 노트북 WSL2는 mirrored 네트워킹 모드라 내부 IP가 고정되지 않고 Windows 호스트의 실제 LAN IP를 그대로 사용 (`192.168.0.10`).
- **(2026-08-06부터) 데스크탑 → 노트북 SSH는 키 인증으로 전환됨.** 데스크탑 `~/.ssh/homeserver`(ed25519, 패스프레이즈 없음)를 노트북 `~/.ssh/authorized_keys`에 등록해뒀고, 데스크탑 `~/.ssh/config`의 `Host homeserver` 항목 덕분에 `ssh homeserver`로 비밀번호 없이 바로 접속된다. Claude Code 세션에서도 TTY 없이 이 키로 직접 SSH 접속이 가능 — 컨테이너 상태 확인, 로그 조회, 1회성 명령 실행 등은 세션에서 직접 처리할 수 있다 (이전엔 비밀번호 인증만 되어 있어 세션에서 SSH 접속이 불가능했고, 사용자가 직접 서버 작업을 했었음 — 개발 속도를 위해 의도적으로 정책을 바꿈). 다만 시크릿 파일 생성·수정처럼 민감한 작업은 여전히 신중하게, 애매하면 먼저 물어볼 것.
- 관리 화면(postgres, redis, Traefik 대시보드, Uptime Kuma, Jenkins 등)은 전부 `127.0.0.1`에만 바인딩하고, 데스크탑에서는 `ssh -L <포트>:localhost:<포트> <사용자명>@192.168.0.10` SSH 터널로만 접근한다. LAN에 직접 노출하지 않는다.
- **WSL2 mirrored 네트워킹 모드 + UFW 주의사항**: mirrored 모드에서는 loopback(`127.0.0.1`) 트래픽이 일반적인 `lo` 인터페이스로 안 잡히는 것으로 보여, UFW의 기본 "loopback 허용"(`allow in on lo`) 규칙이 작동하지 않는 경우가 있었다. 이 경우 `sudo ufw allow <포트>/tcp`처럼 포트 자체를 허용해야 한다 — 어차피 Docker가 해당 포트를 `127.0.0.1`에만 바인딩하고 있어 LAN 노출 위험은 없다.

## 서비스 로드맵

1. **개인 블로그** (1차) — 콘텐츠 작성·수정은 본인만, 방문자는 검색·댓글만 이용
2. **게임 서버 기능** (향후) — 블로그와 별도 Docker Compose 프로젝트·네트워크로 분리해 추가

## 블로그 기술 스택

- **프론트엔드**: Next.js (React, SSG/SSR 유연 선택)
- **백엔드**: .NET (ASP.NET Core Web API)
- **DB**: PostgreSQL — JSONB로 유동적 스키마(태그/메타데이터) 처리, 내장 Full Text Search, permissive 오픈소스 라이선스, Npgsql 드라이버 성숙도가 선택 이유
- **캐시**: Redis
- **콘텐츠 관리**: MDX 또는 마크다운 파일 기반
- **디자인**: 라이트·다크 모드, 노션 스타일 참고 (변경 가능)

### 블로그 부가 기능

| 영역 | 선택 | 이유 |
|---|---|---|
| 댓글 | giscus (GitHub Discussions) | 서버·DB 불필요, XSS·스팸 리스크 최소 |
| 검색 | Meilisearch(self-hosted) 또는 클라이언트 사이드 | 읽기 전용이라 리스크 낮음 |
| 분석 | Umami 또는 Plausible(self-hosted) | 프라이버시 친화적 |
| SEO | sitemap.xml, RSS 자동 생성 | |

## 공통 인프라

- **컨테이너**: Docker, 서비스별 Compose 프로젝트·네트워크 분리
- **CI/CD**: Jenkins — 로컬/VPN 내부에서만 접근, 외부 미노출
- **리버스 프록시**: Traefik (Docker 라벨 기반 자동 라우팅)
- **외부 노출**: Cloudflare Tunnel (포트포워딩·고정 IP 불필요)
- **HTTPS**: Let's Encrypt(Certbot) 또는 Cloudflare 자동 처리
- **모니터링**: Uptime Kuma
- **로그**: Docker 로그 + logrotate, 필요 시 Loki
- **백업**: postgres는 `pg_dumpall` + cron(매일 자정)으로 `data/backups/postgres/`에 로컬 저장, 7일 지난 백업 자동 삭제 (추후 외부 저장소로 전환 예정)
- **보안**: UFW, Fail2ban, 컨테이너 리소스 제한(cpus/mem_limit)으로 서비스 간 격리

## 문서

- Docker 운영 규칙(디렉토리 구조, Compose 컨벤션, 시크릿 관리 등)은 [DOCKER.md](DOCKER.md) 참고.

## 설계 원칙

- 서비스별로 Docker Compose 프로젝트·네트워크를 분리해 블로그/게임 서버가 서로 영향을 주지 않게 한다.
- 리소스 제한(cpus/mem_limit)은 블로그 단계부터 적용해 향후 게임 서버 추가에 대비한다.
- 게임 서버는 TCP/UDP 커스텀 포트가 필요하므로 Cloudflare Tunnel과 별도의 포트 노출 전략(VPN 등)을 검토해야 한다.
- 모니터링은 처음부터 세팅해 서비스 확장 시 장애 지점을 빠르게 파악한다.
