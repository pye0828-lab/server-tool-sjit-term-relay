#!/bin/bash
# deploy_rpi.sh
# Raspberry Pi 4 — Docker 빌드 및 배포
#
# 사용법:
#   cd server-tool-sjit-term-relay
#   bash scripts/deploy_rpi.sh

set -e

# ── Settings ──────────────────────────────────────────────────────────────────
CONTAINER_NAME="term-relay"
IMAGE_NAME="rpi-term-relay"
PORT=8766

DATETIME=$(date '+%Y%m%d-%H%M%S')

SCRIPT_DIR="$(dirname "$0")"
HISTORY_FILE="${SCRIPT_DIR}/deploy_rpi-history.txt"

echo "=================================================="
echo " Deploy: ${CONTAINER_NAME} (Raspberry Pi 4)"
echo " Version: ${DATETIME}"
echo "=================================================="

# ── 이전 배포 내역 확인 ────────────────────────────────────────────────────────
if [ -f "${HISTORY_FILE}" ]; then
  echo ""
  echo "[ 이전 배포 내역 ]"
  grep -v "^#" "${HISTORY_FILE}" | grep -v "^$"

  echo ""
  echo "[ 최근 배포 이력 (최대 5건) ]"
  HISTORY=$(grep "^\[" "${HISTORY_FILE}" 2>/dev/null || true)
  if [ -n "${HISTORY}" ]; then
    echo "${HISTORY}" | tail -5
  else
    echo "  (이력 없음)"
  fi
  echo ""
else
  echo ""
  echo "[ 이전 배포 내역 없음 — 최초 배포 ]"
  echo ""
fi

# ── 배포 확인 ─────────────────────────────────────────────────────────────────
read -r -p "정말 배포하겠습니까? [y/N]: " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
  echo "배포를 취소했습니다."
  exit 0
fi

echo ""

# ── Build ─────────────────────────────────────────────────────────────────────
echo "[1/3] Building image..."
docker build -f docker/Dockerfile.rpi4 \
  -t "${IMAGE_NAME}:${DATETIME}" \
  -t "${IMAGE_NAME}:latest" \
  .

# ── Replace container ─────────────────────────────────────────────────────────
echo "[2/3] Replacing container..."
docker stop "${CONTAINER_NAME}" 2>/dev/null || true
docker rm   "${CONTAINER_NAME}" 2>/dev/null || true

docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p ${PORT}:${PORT} \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  "${IMAGE_NAME}:${DATETIME}"

# ── Save History ──────────────────────────────────────────────────────────────
echo "[3/3] Saving deployment info..."
HISTORY=$(grep "^\[" "${HISTORY_FILE}" 2>/dev/null || true)

{
  echo "# Raspberry Pi 4 Docker Deployment History"
  echo "# 마지막 배포: ${DATETIME}"
  echo ""
  echo "IMAGE=${IMAGE_NAME}:${DATETIME}"
  echo "PORT=${PORT}"
  echo ""
  echo "# ── 배포 이력 ────────────────────────────────────────────────────"
  if [ -n "${HISTORY}" ]; then
    echo "${HISTORY}"
  fi
  echo "[${DATETIME}] IMAGE=${IMAGE_NAME}:${DATETIME} PORT=${PORT}"
} > "${HISTORY_FILE}"

echo ""
echo "=================================================="
echo " [Done]"
echo " Container : ${CONTAINER_NAME}"
echo " Image     : ${IMAGE_NAME}:${DATETIME}"
echo " Port      : ${PORT}/TCP"
echo " 재시작    : 부팅 시 자동 실행 (--restart=always)"
echo "=================================================="
echo "[Saved] deploy_rpi-history.txt"
