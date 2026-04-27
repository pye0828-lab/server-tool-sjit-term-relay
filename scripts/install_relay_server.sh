#!/usr/bin/env bash
# =============================================================================
# install_relay_server.sh
# Term.py WebSocket 릴레이 서버 설치 스크립트
#
# 사용법:
#   chmod +x install_relay_server.sh
#   sudo ./install_relay_server.sh               # 설치 + 부팅 자동시작
#   sudo ./install_relay_server.sh --no-autostart # 설치만, 자동시작 안 함
#                                                 # (SSH로 수동 start 필요)
#
# 동작:
#   1) Python3 / pip 확인
#   2) websockets 패키지 설치
#   3) /opt/term-relay/ 에 서버 복사
#   4) systemd 서비스 등록
#   5) 방화벽(ufw/firewalld) 포트 8766/TCP 개방
#   6) 자동시작 여부에 따라 enable/disable 결정
# =============================================================================
set -euo pipefail

INSTALL_DIR="/opt/term-relay"
SERVICE_NAME="term-relay"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)/ws_relay_server.py"
RELAY_PORT=8766
RELAY_USER="term-relay"

# ── 옵션 파싱 ─────────────────────────────────────────────────────────────────
AUTOSTART=true
for arg in "$@"; do
    case "$arg" in
        --no-autostart) AUTOSTART=false ;;
        *) warn "알 수 없는 옵션: $arg" ;;
    esac
done

# ── 색상 출력 헬퍼 ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── root 확인 ─────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "root 권한 필요: sudo $0"

# ── 전용 시스템 유저 생성 (없을 때만) ────────────────────────────────────────
if ! id "${RELAY_USER}" &>/dev/null; then
    info "전용 유저 생성: ${RELAY_USER}"
    useradd --system --no-create-home --shell /usr/sbin/nologin "${RELAY_USER}"
    info "  유저 생성 완료"
else
    info "전용 유저 이미 존재: ${RELAY_USER}"
fi

# ── 소스 파일 확인 ───────────────────────────────────────────────────────────
[[ -f "$SCRIPT_SRC" ]] || error "ws_relay_server.py 를 찾을 수 없습니다: $SCRIPT_SRC"

# ── Python3 확인 ─────────────────────────────────────────────────────────────
info "Python3 확인 중..."
PYTHON=$(command -v python3 || true)
[[ -z "$PYTHON" ]] && error "python3 가 설치되어 있지 않습니다 (sudo apt install python3)"
PYVER=$("$PYTHON" --version 2>&1)
info "  $PYVER — $PYTHON"

# ── pip 확인 ─────────────────────────────────────────────────────────────────
info "pip 확인 중..."
PIP=$(command -v pip3 || command -v pip || true)
if [[ -z "$PIP" ]]; then
    warn "pip 미설치 — 설치 시도 중..."
    "$PYTHON" -m ensurepip --upgrade 2>/dev/null || \
        apt-get install -y python3-pip 2>/dev/null || \
        error "pip 설치 실패. 수동으로 설치하세요: sudo apt install python3-pip"
    PIP="$PYTHON -m pip"
fi
info "  pip: $PIP"

# ── websockets 설치 ───────────────────────────────────────────────────────────
info "websockets 패키지 설치 중..."
$PIP install --upgrade websockets || error "websockets 설치 실패"
info "  websockets 설치 완료"

# ── 설치 디렉터리 생성 ────────────────────────────────────────────────────────
info "설치 디렉터리 생성: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -f "$SCRIPT_SRC" "$INSTALL_DIR/ws_relay_server.py"
chmod 755 "$INSTALL_DIR/ws_relay_server.py"
info "  파일 복사 완료"

# ── systemd 서비스 파일 생성 ──────────────────────────────────────────────────
info "systemd 서비스 파일 생성: $SERVICE_FILE"
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Term.py WebSocket Relay Server
Documentation=https://github.com/your-org/Term
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RELAY_USER}
ExecStart=${PYTHON} ${INSTALL_DIR}/ws_relay_server.py --host 0.0.0.0 --port ${RELAY_PORT}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# 보안 강화 옵션
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=${INSTALL_DIR}

[Install]
WantedBy=multi-user.target
EOF
info "  서비스 파일 생성 완료"

# ── 방화벽 포트 개방 ──────────────────────────────────────────────────────────
info "방화벽 포트 ${RELAY_PORT}/tcp 개방 중..."
if command -v ufw &>/dev/null; then
    ufw allow ${RELAY_PORT}/tcp && info "  ufw: ${RELAY_PORT}/tcp 개방 완료"
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port=${RELAY_PORT}/tcp && \
    firewall-cmd --reload && info "  firewalld: ${RELAY_PORT}/tcp 개방 완료"
elif command -v iptables &>/dev/null; then
    iptables -C INPUT -p tcp --dport ${RELAY_PORT} -j ACCEPT 2>/dev/null || \
    iptables -A INPUT -p tcp --dport ${RELAY_PORT} -j ACCEPT && \
    info "  iptables: ${RELAY_PORT}/tcp 개방 완료"
else
    warn "방화벽 도구를 찾을 수 없습니다. 수동으로 ${RELAY_PORT}/tcp 를 개방하세요."
fi

# ── systemd 등록 ──────────────────────────────────────────────────────────────
info "systemd 서비스 등록 중..."
systemctl daemon-reload

if $AUTOSTART; then
    info "  자동시작 활성화 (재부팅 시 자동 실행)"
    systemctl enable "${SERVICE_NAME}"
    systemctl restart "${SERVICE_NAME}"

    sleep 1
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        info "  [OK] ${SERVICE_NAME} 서비스 실행 중"
    else
        warn "서비스 시작 실패. 로그 확인:"
        journalctl -u "${SERVICE_NAME}" -n 20 --no-pager
        exit 1
    fi
else
    info "  자동시작 비활성화 (수동 start 필요)"
    systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
    # 혹시 이미 실행 중이면 중지
    systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
    info "  [OK] ${SERVICE_NAME} 서비스 등록 완료 (현재 중지 상태)"
fi

# ── 완료 메시지 ───────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Term.py 릴레이 서버 설치 완료!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "  포트     : ${RELAY_PORT}/TCP"
echo -e "  설치위치 : ${INSTALL_DIR}/"
echo -e "  서비스   : systemctl {start|stop|restart|status} ${SERVICE_NAME}"
echo -e "  로그보기 : journalctl -u ${SERVICE_NAME} -f"
echo ""

if $AUTOSTART; then
    echo -e "  [자동시작 서버] 재부팅 후에도 자동으로 실행됩니다."
else
    echo -e "  [수동시작 서버] 재부팅 시 자동 실행 안 됨."
    echo -e "  SSH 접속 후 아래 명령으로 시작하세요:"
    echo -e "    sudo systemctl start ${SERVICE_NAME}"
    echo -e "  또는 관리 스크립트 사용:"
    echo -e "    sudo ./relay_server_manage.sh start"
fi
echo ""
echo -e "  server.json 설정:"
echo -e "    \"relay_servers\": [\"ws://$(hostname -I | awk '{print $1}'):${RELAY_PORT}\"]"
echo ""
