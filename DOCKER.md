# Docker 운영 규칙

홈서버에서 Docker 컨테이너를 구성·운영할 때 따르는 규칙. 서비스가 늘어나도(블로그, 게임 서버 등) 동일한 구조를 유지한다.

## 디렉토리 구조

루트 기준 3분류, 각 폴더 아래 컨테이너(서비스)별 서브 폴더를 둔다.

```
/
├── data/       # 컨테이너가 사용하는 영속 데이터 (볼륨 마운트 대상)
│   ├── jenkins/
│   ├── postgres/
│   └── redis/
├── deploy/     # docker-compose.yml 및 관련 설정 파일
│   ├── jenkins/
│   │   └── docker-compose.yml
│   ├── postgres/
│   │   └── docker-compose.yml
│   ├── redis/
│   │   └── docker-compose.yml
│   ├── blog-web/
│   │   └── docker-compose.yml
│   ├── blog-api/
│   │   └── docker-compose.yml
│   └── ...
└── secret/     # .env 파일 (민감 정보)
    ├── jenkins/
    │   └── .env
    ├── blog-api/
    │   └── .env
    └── ...
```

- 서브 폴더 이름은 **컨테이너 단위**로 통일한다 (예: `jenkins`, `postgres`, `redis`, `blog-web`, `blog-api`, `gameserver`).
- 컨테이너는 각각 독립된 `docker-compose.yml`로 하나씩 띄운다. 여러 컨테이너를 한 파일에 몰아넣지 않고, 컨테이너별로 독립적인 생명주기(재시작/업데이트/배포)를 갖는다.
  - 예: `postgres`, `redis`처럼 여러 서비스가 공유하는 인프라 컨테이너도 각자 자기 compose 파일 하나로 뜨고, 필요한 앱 컨테이너가 네트워크로 연결해서 사용한다.

## Compose 프로젝트 규칙

- **컨테이너 단위 분리**: 컨테이너 하나 = compose 프로젝트 하나. 이렇게 하면 컨테이너별로 독립적으로 올리고 내리고 재시작할 수 있고, postgres/redis 같은 인프라 컨테이너를 블로그·게임 서버 등 여러 서비스가 공유하기도 쉽다.
- **프로젝트 이름 고정**: `docker-compose.yml`마다 `name:` 필드를 명시해 프로젝트명을 고정한다 (경로 기준 자동 이름 생성에 의존하지 않음).
- **네트워크는 통신 경계 기준으로 설계**: "프로젝트별 네트워크"가 아니라, 실제로 통신이 필요한 범위 단위로 외부(`external: true`) 네트워크를 만들고 필요한 컨테이너만 연결한다. 자세한 내용은 아래 [네트워크 설계](#네트워크-설계) 참고.
- **볼륨 경로**: 전부 `../../data/<컨테이너명>/...` 형태의 상대 경로 bind mount를 사용한다 (named volume 대신 bind mount로 실제 데이터 위치를 명확히 파악 가능하게 함).
- **환경 변수**: `env_file: ../../secret/<컨테이너명>/.env` 로 참조한다. `docker-compose.yml`에 비밀값을 직접 하드코딩하지 않는다.

## 네트워크 설계

컨테이너가 독립적으로 뜨는 구조라, 네트워크는 "프로젝트별"이 아니라 **통신이 실제로 필요한 경계(trust boundary) 기준**으로 나눈다. 관계없는 컨테이너가 서로의 존재를 모르게 하는 게 목적이다.

- 네트워크는 `docker network create` 등으로 미리 만들어두고, 각 `docker-compose.yml`에서는 `external: true`로 참조만 한다 (compose 파일이 네트워크를 새로 만들지 않게).
- 기본으로 두는 네트워크 예시:
  - `proxy` — 리버스 프록시(Nginx/Traefik) + 외부에 노출될 웹/API 컨테이너만 연결. 인터넷에서 들어오는 요청이 닿는 유일한 통로.
  - `blog-backend` — blog-api, postgres, redis 등 블로그 앱과 그 앱이 쓰는 DB/캐시만 연결. 게임 서버 등 관계없는 컨테이너는 여기 연결하지 않는다.
  - (향후) `gameserver-backend` — 게임 서버 전용. postgres를 블로그와 공유해야 한다면, postgres 컨테이너만 `blog-backend`와 `gameserver-backend` 양쪽에 추가로 연결한다.
- 하나의 컨테이너가 여러 네트워크에 동시에 속하는 것은 정상이다 (예: blog-api는 `proxy`와 `blog-backend` 둘 다에 연결).
- 절대 모든 컨테이너를 하나의 flat 네트워크에 몰아넣지 않는다 — 관계없는 컨테이너가 postgres/redis에 접근 가능해지는 것을 방지하기 위함.

## 시크릿 관리

- `secret/` 폴더 전체를 `.gitignore`에 등록해 절대 커밋되지 않게 한다.
- `secret/<서비스명>/.env.example`을 함께 두어 필요한 키 목록만 공유하고, 실제 값은 `.env`에만 넣는다.
- 이미지 빌드에 시크릿이 필요하면 `ARG`/`ENV`로 이미지에 굽지 않고, 런타임 `.env` 주입으로만 처리한다.

## 리소스 및 안정성

- 모든 서비스 컨테이너에 `deploy.resources.limits` (cpus/memory)를 지정해 한 서비스의 장애·과부하가 다른 서비스에 영향을 주지 않게 한다.
- `restart: unless-stopped`를 기본값으로 사용한다.
- DB/캐시처럼 상태가 있는 컨테이너는 `healthcheck`를 정의해, 의존하는 서비스(`depends_on: condition: service_healthy`)가 준비 전에 뜨지 않게 한다.

## 이미지 및 버전 관리

- 공식 이미지는 `latest` 대신 **명시적 버전 태그**를 고정한다 (예: `postgres:16`, `redis:7`). 예기치 않은 브레이킹 체인지를 방지.
- 자체 빌드 이미지(블로그 프론트/백엔드 등)는 CI(Jenkins)에서 커밋 해시 또는 semver 태그로 빌드해 배포한다.

## 로그 및 백업

- 컨테이너 로깅 드라이버에 `max-size`/`max-file`을 설정해 로그가 디스크를 무한정 채우지 않게 한다.
- DB는 `data/<서비스명>` bind mount와는 별도로, `pg_dump` 등 정기 백업 산출물을 `data/backups/<서비스명>/`처럼 분리된 경로에 저장한다 (원본 데이터 볼륨과 백업을 같은 위치에 섞지 않음).

## 명명 규칙 요약

| 대상 | 규칙 | 예 |
|---|---|---|
| 서브 폴더명 (data/deploy/secret 공통) | 컨테이너 단위, 소문자, 하이픈 구분 | `jenkins`, `postgres`, `blog-web`, `blog-api` |
| Compose 프로젝트명 | 서브 폴더명과 동일하게 고정 | `name: blog-api` |
| 공용 네트워크명 | 통신 경계 기준, `<범위>-<용도>` | `proxy`, `blog-backend`, `gameserver-backend` |
