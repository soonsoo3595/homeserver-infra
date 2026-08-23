#!/bin/bash
set -euo pipefail

# cloudflared 이미지엔 셸/curl조차 없어서 컨테이너 안에서 도는 Docker
# HEALTHCHECK를 만들 수가 없다. 게다가 이 프로세스는 죽지 않고 "떠있는
# 채로 응답만 멈추는" 방식으로 좀비 상태가 되는 걸 실제로 겪었다
# (docker ps엔 Up으로 나오는데 터널은 죽어서 Cloudflare가 1033/530을 냄).
# 그래서 밖에서(host cron) 주기적으로 /ready를 찔러보고 실패하면 재시작.
if ! curl -sf -o /dev/null --max-time 5 http://127.0.0.1:20241/ready; then
  echo "$(date -u +%FT%TZ) cloudflared not ready, restarting"
  docker restart cloudflared
fi
