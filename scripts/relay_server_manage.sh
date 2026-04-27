#!/usr/bin/env bash
# =============================================================================
# relay_server_manage.sh
# Term.py 릴레이 서버 관리 스크립트
#
# 사용법:
#   ./relay_server_manage.sh {start|stop|restart|status|log|update|uninstall}
# =============================================================================

SERVICE_NAME="term-relay"
INSTALL_DIR="/opt/term-relay"
RELAY_PORT=8766

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

need_root() {
    [[ $EUID -ne 0 ]] && { error "root 권한 필요: sudo $0 $CMD"; exit 1; }
}

CMD="${1:-status}"

case "$CMD" in
    start)
        need_root
        systemctl start "$SERVICE_NAME"
        sleep 1
        systemctl is-active --quiet "$SERVICE_NAME" && \
            info "[OK] 서비스 시작됨" || error "시작 실패"
        ;;

    stop)
        need_root
        systemctl stop "$SERVICE_NAME"
        info "[STOP] 서비스 중지됨"
        ;;

    restart)
        need_root
        systemctl restart "$SERVICE_NAME"
        sleep 1
        systemctl is-active --quiet "$SERVICE_NAME" && \
            info "[OK] 서비스 재시작됨" || error "재시작 실패"
        ;;

    status)
        echo -e "${CYAN}── 서비스 상태 ─────────────────────────────────────${NC}"
        if systemctl cat "$SERVICE_NAME" &>/dev/null; then
            # 서비스 파일 존재 → 설치됨 (active/inactive 무관)
            systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null || true
        else
            warn "서비스가 설치되어 있지 않습니다 (install_relay_server.sh 실행)"
        fi

        echo ""
        echo -e "${CYAN}── 포트 ${RELAY_PORT} 사용 현황 ──────────────────────────────${NC}"
        ss -tlnp "sport = :${RELAY_PORT}" 2>/dev/null || \
        netstat -tlnp 2>/dev/null | grep ":${RELAY_PORT}" || \
            echo "  (포트 미사용 중)"

        echo ""
        echo -e "${CYAN}── 현재 접속 수 ────────────────────────────────────${NC}"
        CNT=$(ss -tnp 2>/dev/null | grep ":${RELAY_PORT}" | wc -l)
        echo "  WebSocket 연결: ${CNT}개"
        ;;

    log)
        # 실시간 로그 출력 (Ctrl+C 로 종료)
        echo -e "${CYAN}[실시간 로그] Ctrl+C 로 종료${NC}"
        journalctl -u "$SERVICE_NAME" -f --no-pager
        ;;

    log-tail)
        # 최근 50줄만 출력
        journalctl -u "$SERVICE_NAME" -n 50 --no-pager
        ;;

    update)
        need_root
        SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)/ws_relay_server.py"
        [[ -f "$SCRIPT_SRC" ]] || { error "ws_relay_server.py 없음: $SCRIPT_SRC"; exit 1; }
        info "서버 파일 업데이트 중..."
        cp -f "$SCRIPT_SRC" "$INSTALL_DIR/ws_relay_server.py"
        systemctl restart "$SERVICE_NAME"
        sleep 1
        systemctl is-active --quiet "$SERVICE_NAME" && \
            info "[OK] 업데이트 및 재시작 완료" || error "재시작 실패"
        ;;

    uninstall)
        need_root
        warn "릴레이 서버를 완전히 제거합니다."
        read -rp "계속하시겠습니까? [y/N] " ans
        [[ "${ans,,}" != "y" ]] && { info "취소됨"; exit 0; }

        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        systemctl daemon-reload
        rm -rf "$INSTALL_DIR"
        info "[OK] 서비스 제거 완료"
        ;;

    *)
        echo "사용법: $0 {start|stop|restart|status|log|log-tail|update|uninstall}"
        echo ""
        echo "  start      — 서비스 시작"
        echo "  stop       — 서비스 중지"
        echo "  restart    — 서비스 재시작"
        echo "  status     — 상태 및 연결 수 확인"
        echo "  log        — 실시간 로그 (Ctrl+C 종료)"
        echo "  log-tail   — 최근 50줄 로그"
        echo "  update     — ws_relay_server.py 교체 후 재시작"
        echo "  uninstall  — 서비스 완전 제거"
        exit 1
        ;;
esac
