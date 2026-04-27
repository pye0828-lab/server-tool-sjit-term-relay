#!/usr/bin/env python3
"""
ws_relay_server.py — Term.py 화면 공유 릴레이 서버 (보안 강화판)

사용 포트: 8766/TCP (방화벽에서 TCP 8766 허용 필요)
  - Ubuntu/Debian: sudo ufw allow 8766/tcp
  - CentOS/RHEL:   sudo firewall-cmd --permanent --add-port=8766/tcp && sudo firewall-cmd --reload

설치:
  pip install websockets

실행:
  python ws_relay_server.py
  python ws_relay_server.py --port 8766 --host 0.0.0.0

보안 기능:
  - 6자리 숫자 룸 코드
  - 룸당 최대 클라이언트 수 제한 (MAX_CLIENTS_PER_ROOM)
  - IP당 분당 최대 연결 시도 제한 (RATE_LIMIT_PER_MIN)
  - 메시지 최대 크기 제한 (MAX_MSG_SIZE bytes)
  - 접속 후 첫 메시지 타임아웃 (HANDSHAKE_TIMEOUT 초)
  - 룸 비활성 자동 정리 (ROOM_IDLE_TIMEOUT 초)
"""

import asyncio
import json
import random
import string
import argparse
import logging
import ssl
import time
from collections import defaultdict
from datetime import datetime

try:
    import websockets
except ImportError:
    print("websockets 미설치: pip install websockets")
    raise

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

# ── 서버 설정 ──────────────────────────────────────────────────────────────────
RELAY_HOST          = "0.0.0.0"
RELAY_PORT          = 8766
MAX_CLIENTS_PER_ROOM = 10      # 룸당 최대 클라이언트 수
RATE_LIMIT_PER_MIN  = 20       # IP당 분당 최대 연결 시도 수
MAX_MSG_SIZE        = 512 * 1024  # 메시지 최대 크기: 512 KB
HANDSHAKE_TIMEOUT   = 15       # 첫 메시지 타임아웃 (초)
ROOM_IDLE_TIMEOUT   = 3600     # 룸 최대 유지 시간 (초, 1시간)
ROOM_CODE_LEN       = 6        # 룸 코드 길이 (숫자 6자리)
ROOM_CODE_CHARS     = string.digits  # 0-9

# ── 전역 상태 ──────────────────────────────────────────────────────────────────
# rooms: { room_code: {"host": ws, "clients": set(ws), "created_at": float} }
rooms: dict = {}

# rate limiting: { ip_str: [timestamp, ...] }
_rate_table: dict = defaultdict(list)


# ── 유틸리티 ──────────────────────────────────────────────────────────────────

def _gen_room_code() -> str:
    """6자리 숫자 룸 코드 생성 (충돌 회피)"""
    for _ in range(200):
        code = "".join(random.choices(ROOM_CODE_CHARS, k=ROOM_CODE_LEN))
        if code not in rooms:
            return code
    raise RuntimeError("룸 코드 생성 실패 (룸 포화)")


def _check_rate_limit(ip: str) -> bool:
    """True = 허용, False = 제한 초과"""
    now = time.monotonic()
    window = 60.0
    timestamps = _rate_table[ip]
    # 1분 이전 기록 제거
    _rate_table[ip] = [t for t in timestamps if now - t < window]
    if len(_rate_table[ip]) >= RATE_LIMIT_PER_MIN:
        return False
    _rate_table[ip].append(now)
    return True


async def _send_safe(ws, payload: dict):
    """JSON 직렬화 후 전송, 실패 시 무시"""
    try:
        await ws.send(json.dumps(payload))
    except Exception:
        pass


async def _broadcast_to_clients(room_code: str, raw: str):
    """룸의 모든 클라이언트에 메시지 전송, 끊긴 연결 정리"""
    if room_code not in rooms:
        return
    dead = set()
    for client in list(rooms[room_code]["clients"]):
        try:
            await client.send(raw)
        except Exception:
            dead.add(client)
    rooms[room_code]["clients"] -= dead


def _cleanup_expired_rooms():
    """유효 시간 초과 룸 정리"""
    now = time.monotonic()
    expired = [
        code for code, r in rooms.items()
        if now - r.get("created_at", now) > ROOM_IDLE_TIMEOUT
    ]
    for code in expired:
        logging.info(f"[Room {code}] 유효 시간 초과 → 자동 삭제")
        del rooms[code]


# ── 메인 핸들러 ───────────────────────────────────────────────────────────────

async def handler(ws, path=""):
    peer_addr = ws.remote_address
    ip = peer_addr[0] if peer_addr else "unknown"
    role = None
    room_code = None

    # ── 연결 속도 제한 ─────────────────────────────────────────────────────────
    if not _check_rate_limit(ip):
        logging.warning(f"[RateLimit] {ip} — 연결 거부 (분당 {RATE_LIMIT_PER_MIN}회 초과)")
        await _send_safe(ws, {"type": "error", "msg": "rate_limit"})
        return

    # ── 만료 룸 주기적 정리 ────────────────────────────────────────────────────
    _cleanup_expired_rooms()

    try:
        # ── 첫 메시지로 역할 결정 ─────────────────────────────────────────────
        raw = await asyncio.wait_for(ws.recv(), timeout=HANDSHAKE_TIMEOUT)
        msg = json.loads(raw)

        # ── Host 등록 ─────────────────────────────────────────────────────────
        if msg.get("type") == "host":
            room_code = _gen_room_code()
            rooms[room_code] = {
                "host": ws,
                "clients": set(),
                "created_at": time.monotonic()
            }
            role = "host"
            await _send_safe(ws, {"type": "room_created", "room": room_code})
            logging.info(f"[Room {room_code}] Host 등록 — {ip}")

            # 호스트 → 클라이언트 포워딩
            async for raw in ws:
                # 메시지 크기 제한
                if len(raw) > MAX_MSG_SIZE:
                    logging.warning(f"[Room {room_code}] Host 메시지 초과 크기 ({len(raw)} bytes) 무시")
                    continue
                try:
                    inner = json.loads(raw)
                    msg_type = inner.get("type")
                    if msg_type in ("display", "hello", "ping"):
                        if msg_type == "ping":
                            await _send_safe(ws, {"type": "pong"})
                        await _broadcast_to_clients(room_code, raw)
                except Exception:
                    pass

        # ── Client 참가 ───────────────────────────────────────────────────────
        elif msg.get("type") == "join":
            room_code = str(msg.get("room", "")).strip().upper()

            # 룸 존재 확인
            if room_code not in rooms:
                await _send_safe(ws, {"type": "error", "msg": "room_not_found"})
                logging.info(f"[Join] {ip} — 룸 없음: {room_code!r}")
                return

            # 최대 클라이언트 수 확인
            if len(rooms[room_code]["clients"]) >= MAX_CLIENTS_PER_ROOM:
                await _send_safe(ws, {"type": "error", "msg": "room_full"})
                logging.info(f"[Room {room_code}] {ip} — 접속 거부 (최대 {MAX_CLIENTS_PER_ROOM}명)")
                return

            rooms[room_code]["clients"].add(ws)
            role = "client"
            count = len(rooms[room_code]["clients"])

            await _send_safe(ws, {"type": "joined", "room": room_code})
            # 호스트에게 클라이언트 수 알림
            try:
                await rooms[room_code]["host"].send(
                    json.dumps({"type": "client_count", "count": count})
                )
            except Exception:
                pass
            logging.info(f"[Room {room_code}] Client 참가 — {ip} ({count}명)")

            # 클라이언트 → 호스트 포워딩 (TX 명령 등)
            async for raw in ws:
                if len(raw) > MAX_MSG_SIZE:
                    logging.warning(f"[Room {room_code}] Client 메시지 초과 크기 무시")
                    continue
                if room_code in rooms:
                    try:
                        await rooms[room_code]["host"].send(raw)
                    except Exception:
                        pass

        else:
            logging.warning(f"[Unknown] {ip} — 알 수 없는 메시지: {msg.get('type')!r}")

    except asyncio.TimeoutError:
        logging.info(f"[Timeout] {ip} — 핸드셰이크 타임아웃 ({HANDSHAKE_TIMEOUT}s)")
    except json.JSONDecodeError:
        logging.warning(f"[ParseError] {ip} — JSON 파싱 실패")
    except Exception as ex:
        logging.error(f"[Error] {ip} — handler 예외: {ex}")
    finally:
        # ── 연결 해제 정리 ────────────────────────────────────────────────────
        if room_code and room_code in rooms:
            if role == "host":
                for client in list(rooms[room_code]["clients"]):
                    await _send_safe(client, {"type": "host_disconnected"})
                del rooms[room_code]
                logging.info(f"[Room {room_code}] Host 해제 → 룸 삭제")
            elif role == "client":
                rooms[room_code]["clients"].discard(ws)
                count = len(rooms[room_code]["clients"])
                logging.info(f"[Room {room_code}] Client 해제 ({count}명 남음)")
                try:
                    await rooms[room_code]["host"].send(
                        json.dumps({"type": "client_count", "count": count})
                    )
                except Exception:
                    pass


# ── 서버 진입점 ───────────────────────────────────────────────────────────────

async def main(host: str, port: int, ssl_ctx=None):
    proto = "WSS" if ssl_ctx else "WS"
    logging.info("Term.py Relay Server v2.1 (WS+WSS 지원)")
    logging.info(f"Listen         : {host}:{port} ({proto})")
    logging.info(f"룸 코드        : {ROOM_CODE_LEN}자리 숫자 (000000~999999)")
    logging.info(f"룸당 최대 인원 : {MAX_CLIENTS_PER_ROOM}명")
    logging.info(f"메시지 최대    : {MAX_MSG_SIZE // 1024} KB")
    logging.info(f"IP 속도 제한   : {RATE_LIMIT_PER_MIN}회/분")
    logging.info(f"룸 유효 시간   : {ROOM_IDLE_TIMEOUT // 60}분")
    logging.info(f"방화벽         : sudo ufw allow {port}/tcp")

    async with websockets.serve(
        handler, host, port,
        max_size=MAX_MSG_SIZE,      # 서버 측 메시지 크기 강제 제한
        reuse_address=True,
        ssl=ssl_ctx,                # None이면 WS, SSLContext이면 WSS
    ):
        logging.info("릴레이 서버 준비 완료 — Ctrl+C 로 종료")
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Term.py WebSocket Relay Server")
    parser.add_argument("--host", default=RELAY_HOST, help="바인드 주소 (기본: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=RELAY_PORT, help="포트 번호 (기본: 8766)")
    parser.add_argument("--certfile", default=None, help="SSL 인증서 파일 경로 (WSS 활성화, PEM 형식)")
    parser.add_argument("--keyfile",  default=None, help="SSL 개인키 파일 경로 (WSS 활성화, PEM 형식)")
    args = parser.parse_args()

    ssl_ctx = None
    if args.certfile:
        ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ssl_ctx.load_cert_chain(args.certfile, args.keyfile)
        logging.info(f"SSL 인증서 로드: {args.certfile}")

    try:
        asyncio.run(main(args.host, args.port, ssl_ctx))
    except KeyboardInterrupt:
        logging.info("서버 종료")
