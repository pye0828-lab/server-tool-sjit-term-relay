# server-tool-sjit-term-relay

**SJIT Terminal** 화면 공유를 위한 WebSocket 릴레이 서버입니다.  
SJIT Terminal(sterm)의 화면을 여러 클라이언트가 실시간으로 시청할 수 있도록 중계합니다.

- **포트**: `8766/TCP`
- **프로토콜**: WebSocket
- **구조**: Host(공유자) ↔ **릴레이 서버** ↔ Client(시청자)
- **룸 코드**: 6자리 숫자, Host 접속 시 자동 발급

```
[SJIT Terminal (Host)]
        │  ws://server:8766
        ▼
  [Relay Server]
        │  room code: 123456
        ├─▶ [Client 1]
        ├─▶ [Client 2]
        └─▶ [Client N]
```

> [!TIP]
> 이 문서(`.md`)를 브라우저에서 보려면 크롬 웹스토어에서 **Markdown Viewer** 플러그인을 설치하고,  
> 확장프로그램 관리(`chrome://extensions`)에서 **[로컬 파일 액세스 허용]** 을 활성화하세요.

---

## 폴더 구조

<details>
<summary>세부 내용 보기</summary>

```
server-tool-sjit-term-relay/
├── ws_relay_server.py          # 메인 서버 소스
├── requirements.txt            # Python 패키지 목록
│
├── scripts/
│   ├── setup_venv.cmd                  # [Windows] 가상환경 최초 셋업
│   ├── start.cmd                       # [Windows] 서버 실행
│   ├── install_relay_server.sh         # [Linux]   systemd 서비스 설치
│   ├── relay_server_manage.sh          # [Linux]   서비스 관리 (start/stop/log)
│   ├── deploy_rpi.sh                   # [RPi4]    Docker 빌드·배포 스크립트
│   ├── deploy_rpi-history.txt          # [RPi4]    배포 이력 (gitignore — 저장소 미포함)
│   ├── deploy_cloudrun.sh              # [GCP]     Cloud Run 빌드·배포 스크립트
│   └── deploy_cloudrun-history.txt     # [GCP]     배포 이력 (gitignore — 저장소 미포함)
│
├── docker/                     # 컨테이너 배포용
│   ├── Dockerfile.cloudrun             # GCP Cloud Run (amd64)
│   └── Dockerfile.rpi4                 # Raspberry Pi 4 (arm64)
│
├── .vscode/
│   └── launch.json             # VS Code 실행/디버그 설정
│
├── documents/
│   ├── original/               # 담당자 릴리즈 원본 보관 (zip)
│   └── pic/                    # 문서용 이미지
│
└── .venv/                      # 가상환경 (gitignore — 저장소 미포함)
```

</details>

---

## 환경 설정 (Windows)

### 1. Host PC 필수 도구 설치

아래 도구가 설치되어 있지 않다면 설치가 필요합니다.

<details>
<summary>세부 내용 보기</summary>

| 도구 | 버전 | 다운로드 |
|------|------|----------|
| **Python** | 3.10 이상 | [python.org](https://www.python.org/downloads/) |
| **Git** | 최신 | [git-scm.com](https://git-scm.com/download/win) |

> ⚠️ **Python 설치 시 주의**  
> 설치 화면에서 **"Add Python to PATH"** 를 반드시 체크하세요.

설치 후 확인:
```cmd
python --version
```

</details>

### 2. 가상환경 셋업

저장소를 clone한 후 1회 실행합니다. `.venv` 폴더가 없다면 셋업이 필요합니다.

<details>
<summary>세부 내용 보기</summary>

프로젝트에 필요한 Python 패키지를 **프로젝트 내 가상환경**에 설치합니다.  
사용자 계정 Python 환경을 오염시키지 않습니다.

```
scripts\setup_venv.cmd
```

실행하면 다음이 자동으로 진행됩니다:
1. 프로젝트 루트에 `.venv/` 가상환경 생성
2. `requirements.txt` 기반 패키지 설치 (`websockets`)

> [!TIP]
> `.venv/` 폴더는 `.gitignore` 에 등록되어 있어 저장소에 올라가지 않습니다.

</details>

---

## 실행 방법 (Windows)

가상환경 셋업 완료 후, 아래 스크립트로 서버를 실행합니다:

```
scripts\start.cmd
```

포트를 바꾸고 싶다면:
```
scripts\start.cmd --port 9000
```

실행 확인:
```
2026-04-24 10:00:00 [INFO] Term.py Relay Server v2.0 (보안 강화)
2026-04-24 10:00:00 [INFO] Listen         : 0.0.0.0:8766
2026-04-24 10:00:00 [INFO] 릴레이 서버 준비 완료 — Ctrl+C 로 종료
```

**종료:** `Ctrl+C`

---

## VS Code 개발 환경

### 1. 확장 프로그램 설치

PC에 한 번만 설치합니다.

<details>
<summary>세부 내용 보기</summary>

VS Code에서 아래 확장 프로그램을 설치합니다:

| 확장 프로그램 | 용도 |
|--------------|------|
| **Python** (Microsoft) | Python 언어 지원, 디버거 |
| **Pylance** (Microsoft) | 코드 자동완성, 타입 힌트 |

</details>

### 2. Python 인터프리터 설정

저장소를 clone한 후 1회 설정합니다. `.venv` 가상환경 셋업 완료 후 진행합니다.

<details>
<summary>세부 내용 보기</summary>

1. VS Code에서 프로젝트 폴더 열기
2. 우하단 Python 버전 클릭 (또는 `Ctrl+Shift+P` → `Python: Select Interpreter`)
3. `.venv\Scripts\python.exe` 선택

> [!TIP]
> `.vscode/launch.json` 이 이미 포함되어 있어 별도 설정 없이 바로 실행됩니다.

</details>

### 3. 실행 및 디버깅

| 동작 | 단축키 |
|------|--------|
| 서버 실행 | `F5` |
| 브레이크포인트 토글 | `F9` |
| 한 줄씩 실행 (Step Over) | `F10` |
| 함수 안으로 진입 (Step Into) | `F11` |
| 실행 재개 | `F5` |
| 서버 종료 | `Shift+F5` |

실행 구성은 2가지 제공됩니다 (`F5` 누르면 선택 가능):
- **Run Relay Server** — 기본 포트 `8766`
- **Run Relay Server (port 9000)** — 포트 `9000`

### 4. 디버깅 팁

브레이크포인트는 주요 지점에 걸어두면 유용합니다:

```python
# 클라이언트 접속 시 확인
rooms[room_code]["clients"].add(ws)   # ← 여기에 브레이크포인트

# 메시지 수신 시 확인
inner = json.loads(raw)               # ← 여기에 브레이크포인트
```

### 5. 원격 개발 (Remote SSH)

Windows PC에서 VS Code로 라즈베리파이 소스코드를 SSH로 열고 편집하는 방법입니다.

<details>
<summary>세부 내용 보기 (1회 설정)</summary>

**1. VS Code 확장 프로그램 설치**

| 확장 프로그램 | 용도 |
|--------------|------|
| **Remote - SSH** (Microsoft) | SSH를 통한 원격 서버 개발 |

---

**2. VS Code에서 접속**

1. `Ctrl+Shift+P` → `Remote-SSH: Connect to Host`
2. 아래 형식으로 입력:
```
ssh [사용자명]@[IP주소] -p [포트번호]
```
3. config 파일 저장 여부 묻는 팝업 → `[사용자폴더]/.ssh/config` 선택
4. 비밀번호 입력
5. 열 폴더 선택 → 라즈베리파이의 소스코드 폴더 지정 → SSH로 열기

> [!TIP]
> 2회차부터는 저장된 항목이 목록에 표시되어 바로 선택할 수 있습니다.

</details>

접속 후 라즈베리파이 파일을 로컬처럼 편집/저장할 수 있으며, VS Code 터미널이 라즈베리파이 터미널로 동작합니다.

---

## 보안 설정

| 항목 | 기본값 | 설명 |
|------|--------|------|
| 포트 | `8766` | `--port` 옵션으로 변경 가능 |
| 룸당 최대 인원 | `10명` | `MAX_CLIENTS_PER_ROOM` |
| IP당 연결 속도 제한 | `20회/분` | `RATE_LIMIT_PER_MIN` |
| 메시지 최대 크기 | `512 KB` | `MAX_MSG_SIZE` |
| 핸드셰이크 타임아웃 | `15초` | `HANDSHAKE_TIMEOUT` |
| 룸 자동 만료 | `60분` | `ROOM_IDLE_TIMEOUT` |

---

## 원본 소스 보관

담당자로부터 릴리즈받은 원본 소스를 `documents/original/` 에 보관합니다.  
파일명 형식: `[이름]_v[버전]_[날짜].zip`

| 파일 | 버전 | 날짜 | 설명 |
|------|------|------|------|
| `relay_server_wss_org_v2.1_20260427.zip` | v2.1 | 2026-04-27 | WSS 지원 추가 버전 |

> [!TIP]
> zip 파일은 수작업으로 관리합니다. 새 버전 릴리즈 수령 시 동일한 형식으로 파일명을 지정하여 추가하세요.

---

## Linux 서버 배포

### 1단계: GitHub SSH 키 설정

라즈베리파이에서 GitHub에 SSH 키 인증으로 접속하는 방법입니다.

<details>
<summary>세부 내용 보기</summary>

**1. SSH 키 생성**

```bash
ssh-keygen -t ed25519 -C "rpi-pye0828google-github" -f ~/.ssh/id_ed25519_pye0828google_github
```

passphrase 입력 없이 Enter 두 번 눌러서 진행합니다.

---

**2. `~/.ssh/config` 설정**

```
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_pye0828google_github
```

---

**3. 공개키 확인 후 GitHub 등록**

```bash
cat ~/.ssh/id_ed25519_pye0828google_github.pub
```

GitHub → Settings → SSH and GPG keys → **New SSH key** → 공개키 붙여넣기

---

**4. 연결 테스트**

```bash
ssh -T git@github.com
```

> [!TIP]
> `Hi pye0828-lab!` 응답이 오면 성공입니다.

---

**5. 저장소 클론**

```bash
git clone git@github.com:pye0828-lab/server-tool-sjit-term-relay.git
```

</details>

### 2단계: Docker 설치

<details>
<summary>세부 내용 보기 (1회 설치)</summary>

**Docker Engine 설치**

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

그룹 반영을 위해 **재로그인** 하거나, 재로그인 없이 즉시 적용하려면:
```bash
newgrp docker
```

확인:
```bash
docker --version
```

---

**Docker 부팅 시 자동 시작 설정**

```bash
sudo systemctl enable docker
```

</details>

### 3단계: 배포

저장소 루트에서 실행합니다.

<details>
<summary>세부 내용 보기</summary>

```bash
bash scripts/deploy_rpi.sh
```

실행 흐름:
```
[1/3] Building image      → docker build (Dockerfile.rpi4)
[2/3] Replacing container → docker stop/rm → docker run --restart=always
[3/3] Saving info         → deploy_rpi-history.txt
[Done] 컨테이너 실행 중
```

> [!TIP]
> `--restart=always` 옵션으로 재부팅 시 자동으로 컨테이너가 시작됩니다.  
> 업데이트 배포 시에는 `git pull` 후 스크립트를 다시 실행하면 됩니다.

</details>

### 4단계: 서비스 확인

<details>
<summary>세부 내용 보기</summary>

**실행 상태 확인**
```bash
docker ps -f name=term-relay
```

**로그 확인**
```bash
docker logs term-relay       # 전체 로그
docker logs -f term-relay    # 실시간 로그
```

> [!TIP]
> 로그는 파일당 최대 10MB, 최대 3개 파일로 자동 로테이션됩니다 (최대 30MB).

---

**수동 중지 / 재시작**
```bash
docker stop    term-relay
docker restart term-relay
```

</details>

---

## GCP Cloud Run 배포

> [!NOTE]
> Cloud Run은 TLS(WSS)를 자동으로 처리합니다. 컨테이너 내부는 ws:// 로 동작하고, 클라이언트는 wss:// 로 접속합니다.  
> SSL 인증서는 Google이 자동 관리하므로 certbot이 필요 없습니다.

### 서비스 접속 주소

배포 완료 후 아래 두 가지 주소로 접속 가능합니다.

| 구분 | 주소 |
|------|------|
| GCP 기본 URL | `wss://sjit-term-relay-xxxxxxxxxx-xx.a.run.app` |

- **GCP 기본 URL**: 배포 시 GCP가 자동 발급. 서비스 이름이 같으면 재배포해도 유지됩니다.

> [!TIP]
> 최신 배포 URL 및 배포 이력은 [scripts/deploy_cloudrun-history.txt](scripts/deploy_cloudrun-history.txt) 를 참조하세요.

### 1단계: Google Cloud 준비

<details>
<summary>세부 내용 보기</summary>

**1. Google Cloud 계정 생성**

- https://cloud.google.com 접속
- 구글 계정으로 로그인
- 신용카드 등록 필요 (최초 가입 시 $300 무료 크레딧 제공)
- Cloud Run은 월 200만 요청까지 무료

**2. 프로젝트 생성**

- [Cloud Console](https://console.cloud.google.com) 접속
- 상단 프로젝트 선택 > 새 프로젝트
- 프로젝트 이름 예: `sjit-term-relay`
- 생성 후 프로젝트 ID 메모 (예: `sjit-term-relay`, `sjit-term-relay-123456`)

**3. API 활성화**

콘솔 검색창에서 아래 API를 찾아 활성화:

| API 이름 | 용도 |
|----------|------|
| **Cloud Run Admin API** | 서버리스 컨테이너 실행 및 관리 |
| **Artifact Registry API** | 컨테이너 이미지 저장소 |

또는 PowerShell에서 한 번에 활성화:
```powershell
gcloud config set project sjit-term-relay
gcloud services enable run.googleapis.com artifactregistry.googleapis.com
```

</details>

### 2단계: 로컬 환경 준비

이미지 빌드/푸시/배포는 모두 **WSL2 Ubuntu** 에서 실행합니다.

<details>
<summary>세부 내용 보기</summary>

**[Windows PowerShell] WSL2 + Ubuntu 24.04 설치 (관리자 권한)**

```powershell
wsl --install -d Ubuntu-24.04
```

설치 완료 후 시작 메뉴에 **Ubuntu 24.04** 아이콘이 생성됩니다. 클릭하면 Ubuntu 터미널이 열립니다.

> [!WARNING]
> Docker Desktop은 **직원 250명 이상 또는 연매출 $10M(약 140억원) 이상** 기업은 유료 라이선스가 필요합니다.
> WSL2 + Docker Engine 은 완전 무료입니다.

---

**[WSL2 Ubuntu] Docker Engine 설치**

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

터미널을 **재시작** 후 확인:
```bash
docker --version
```

---

**[WSL2 Ubuntu] Google Cloud SDK 설치**

```bash
curl -fsSL https://sdk.cloud.google.com | bash
exec -l $SHELL
```

설치 확인:
```bash
gcloud --version
```

---

**[WSL2 Ubuntu] gcloud 로그인 및 프로젝트 설정**

```bash
gcloud auth login
gcloud config set project sjit-term-relay
```

---

**[WSL2 Ubuntu] Docker 인증 설정 (Artifact Registry push 권한)**

```bash
gcloud auth configure-docker asia-northeast3-docker.pkg.dev
```

> [!TIP]
> VS Code에서 **WSL** 확장 프로그램(Microsoft)을 설치하면 VS Code 터미널에서 직접 WSL2 환경을 사용할 수 있습니다.

</details>

### 3단계: Artifact Registry 저장소 생성

컨테이너 이미지를 저장할 저장소를 생성합니다. **최초 1회만 실행합니다.**

<details>
<summary>세부 내용 보기</summary>

**[WSL2 Ubuntu]**
```bash
gcloud artifacts repositories create sjit-term-relay \
  --repository-format=docker \
  --location=asia-northeast3 \
  --description="SJIT Term Relay Server container images"
```

생성 확인:
```bash
gcloud artifacts repositories list --location=asia-northeast3
```

</details>

### 4단계: 이미지 빌드 및 배포

<details>
<summary>세부 내용 보기</summary>

모두 **WSL2 Ubuntu 터미널**에서 실행합니다.  
Windows의 `D:\` 드라이브는 WSL2에서 `/mnt/d/` 로 접근합니다.

**[WSL2 Ubuntu] 프로젝트 디렉토리로 이동**

```bash
cd /mnt/d/WorkFolder/Project/MyPrj/server/sjit_term_relay_server/relay_server
```

확인:
```bash
ls
# ws_relay_server.py  requirements.txt  docker/  scripts/  ...
```

**[WSL2 Ubuntu] 빌드 → 푸시 → 배포 한번에 실행**

```bash
bash scripts/deploy_cloudrun.sh
```

실행 흐름:
```
[1/4] Building image  → docker build
[2/4] Pushing image   → docker push (Artifact Registry)
[3/4] Deploying       → gcloud run deploy
[4/4] Saving info     → deploy_cloudrun-history.txt / deploy_cloudrun-history.log
[Done] Service URL 출력
```

> [!TIP]
> `--min-instances 1` 옵션이 포함되어 있어 콜드 스타트(첫 연결 지연)를 방지합니다. WebSocket 서버는 항상 인스턴스가 떠 있어야 하므로 권장합니다.

배포 완료 후 아래와 같은 서비스 URL이 출력됩니다:
```
https://sjit-term-relay-xxxxxxxxxx-xx.a.run.app
```

이 URL로 즉시 접속 가능합니다 (wss://):
```
wss://sjit-term-relay-xxxxxxxxxx-xx.a.run.app
```

</details>

### 5단계: 커스텀 도메인 연결

> [!NOTE]
> GCP 제공 URL(`*.run.app`)로도 바로 사용 가능합니다. 커스텀 도메인이 필요한 경우에만 진행합니다.

<details>
<summary>세부 내용 보기</summary>

Cloud Run은 커스텀 도메인 연결 시 **SSL 인증서를 자동으로 발급·갱신**합니다. certbot은 필요 없습니다.

**1. GCP 콘솔에서 도메인 연결**

- [Cloud Run 콘솔](https://console.cloud.google.com/run) 접속
- `sjit-term-relay` 서비스 선택
- **도메인 관리** 탭 → **도메인 매핑 추가**
- 도메인 입력: `[커스텀도메인]`

**2. GCP가 안내하는 DNS 레코드를 Cloudflare에 추가**

GCP 콘솔이 아래와 같은 CNAME 값을 표시합니다:

| 항목 | 값 |
|------|-----|
| Type | CNAME |
| Name | `term-relay` |
| Content | GCP가 알려준 값 (예: `ghs.googlehosted.com`) |
| TTL | Auto |
| Proxy status | **DNS only** (회색 구름) |

> [!WARNING]
> Cloudflare Proxy(주황 구름)를 활성화하면 WebSocket이 차단됩니다. 반드시 **DNS only(회색 구름)** 으로 설정하세요.

**3. 연결 확인**

DNS 전파 후 (최대 수 분) GCP 콘솔에서 인증서 상태가 **Active** 로 변경됩니다.

접속 확인:
```
wss://[커스텀도메인]
```

</details>

---

## 서버 동작 테스트

클라이언트 프로그램 없이 서버가 정상 동작하는지 확인합니다.  
Cloud Run, 라즈베리파이, 로컬 모두 동일한 방법으로 테스트합니다.

<details>
<summary>세부 내용 보기</summary>

**접속 주소**

| 환경 | 접속 주소 |
|------|----------|
| Cloud Run | `wss://sjit-term-relay-xxxxxxxxxx-xx.a.run.app` |
| 로컬 (Windows) | `ws://localhost:8766` |

---

**curl — 서버 생존 확인**

```bash
curl -i https://sjit-term-relay-xxxxxxxxxx-xx.a.run.app
```

`HTTP/2 426` 응답이 오면 서버가 정상적으로 동작하고 있는 것입니다.

> [!TIP]
> GCP 콘솔 → Cloud Run → 서비스 선택 → **로그** 탭에서 실시간 접속 로그를 확인할 수 있습니다.

</details>
