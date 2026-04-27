#!/bin/bash
# deploy_cloudrun.sh
# Build, push, and deploy to GCP Cloud Run
#
# Usage (WSL2 Ubuntu):
#   cd /mnt/d/WorkFolder/Project/MyPrj/server/sjit_term_relay_server/relay_server
#   bash scripts/deploy_cloudrun.sh

set -e  # Exit on error

# ── Settings ──────────────────────────────────────────────────────────────────
PROJECT_ID="sjit-term-relay"
REGION="asia-northeast3"
SERVICE="sjit-term-relay"
REPO="sjit-term-relay"
IMAGE_NAME="ws-relay-server"

# 날짜+시간 태그: 버전 추적 및 롤백 용도
# 예: 20260427-103000
DATETIME=$(date '+%Y%m%d-%H%M%S')
TAG_DATED="${DATETIME}"
TAG_LATEST="latest"

IMAGE_DATED="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/${IMAGE_NAME}:${TAG_DATED}"
IMAGE_LATEST="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/${IMAGE_NAME}:${TAG_LATEST}"

SCRIPT_DIR="$(dirname "$0")"
URL_FILE="${SCRIPT_DIR}/deploy_cloudrun-history.txt"

echo "=================================================="
echo " Deploy: ${SERVICE}"
echo " Version: ${TAG_DATED}"
echo "=================================================="

# ── 이전 배포 내역 확인 ────────────────────────────────────────────────────────
if [ -f "${URL_FILE}" ]; then
  echo ""
  echo "[ 이전 배포 내역 ]"
  # 주석(#) 제외하고 출력
  grep -v "^#" "${URL_FILE}" | grep -v "^$"

  echo ""
  echo "[ 최근 배포 이력 (최대 5건) ]"
  HISTORY=$(grep "^\[" "${URL_FILE}" 2>/dev/null || true)
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
echo "[1/4] Building image..."
docker build -f docker/Dockerfile.cloudrun -t "${IMAGE_DATED}" -t "${IMAGE_LATEST}" .

# ── Push ──────────────────────────────────────────────────────────────────────
echo "[2/4] Pushing image to Artifact Registry..."
docker push "${IMAGE_DATED}"
docker push "${IMAGE_LATEST}"

# ── Deploy ────────────────────────────────────────────────────────────────────
echo "[3/4] Deploying to Cloud Run..."
gcloud run deploy "${SERVICE}" \
  --image "${IMAGE_DATED}" \
  --platform managed \
  --region "${REGION}" \
  --allow-unauthenticated \
  --min-instances 1

# ── Save URL & Log ────────────────────────────────────────────────────────────
echo "[4/4] Saving deployment info..."
SERVICE_URL=$(gcloud run services describe "${SERVICE}" \
  --platform managed \
  --region "${REGION}" \
  --format "value(status.url)")

# 기존 이력 읽기
HISTORY=$(grep "^\[" "${URL_FILE}" 2>/dev/null || true)

# url.txt 에 최신 정보 + 이력 통합 저장
# 주의: deploy_cloudrun.sh 의 SERVICE 변수(서비스 이름)를 변경하면
#       GCP가 새로운 URL을 발급하므로 이 파일의 URL도 변경됩니다.
{
  echo "# GCP Cloud Run Service URL"
  echo "# 마지막 배포: ${DATETIME}"
  echo "# 서비스명: ${SERVICE} (deploy_cloudrun.sh 의 SERVICE 변수)"
  echo "# 주의: SERVICE 변수를 변경하면 URL이 변경됩니다."
  echo ""
  echo "SERVICE_URL=${SERVICE_URL}"
  echo "WSS_URL=${SERVICE_URL/https:/wss:}"
  echo "IMAGE=${IMAGE_DATED}"
  echo ""
  echo "# ── 배포 이력 ────────────────────────────────────────────────────"
  if [ -n "${HISTORY}" ]; then
    echo "${HISTORY}"
  fi
  echo "[${DATETIME}] SERVICE=${SERVICE} IMAGE=${IMAGE_DATED} URL=${SERVICE_URL}"
} > "${URL_FILE}"

echo ""
echo "=================================================="
echo " [Done]"
echo " Service URL : ${SERVICE_URL}"
echo " WSS URL     : ${SERVICE_URL/https:/wss:}"
echo " Version     : ${TAG_DATED}"
echo " Image       : ${IMAGE_DATED}"
echo "=================================================="
echo "[Saved] deploy_cloudrun-history.txt"
