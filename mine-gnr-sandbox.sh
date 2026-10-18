#!/usr/bin/env bash
# =============================================================================
# GENORYN (GNR) sandbox miner — one-paste setup
# Tested: Ubuntu 20.04 (build path) + release-binary path (glibc >= 2.33)
# Pool: AriaPool (PPLNS, 3% fee, custodial) · CPU RandomX mining
# =============================================================================
set -euo pipefail

# ---------------- config (override via env sebelum paste) --------------------
WALLET="${WALLET:-gnr19mymj54r9kwqhgnmxcu4hwkpvzchx230lfcndgz74f6kl5hhz9fhvy0gdnr86h640zgfsc8cpkz}"
POOL="${POOL:-tls://gnr.ariabrain.com:3351}"
WORKER="${WORKER:-sandbox-$(hostname)-$RANDOM}"
WORKDIR="${WORKDIR:-$HOME/genoryn-sandbox}"
MAX_SECONDS="${MAX_SECONDS:-0}"   # 0 = jalan terus; set mis. 3600 buat bounded run

# ---------------- auto-detect resources --------------------------------------
CPU_N=$(nproc)
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
# RandomX: auto = 1 dataset 2GiB shared (fast); light = 256MiB per thread (max 16)
if [ "$RAM_MB" -ge 4096 ]; then RX_MODE="auto"; THREADS="$CPU_N"
else RX_MODE="light"; THREADS=$(( RAM_MB / 400 )); [ "$THREADS" -lt 1 ] && THREADS=1; [ "$THREADS" -gt 16 ] && THREADS=16; fi
[ "$THREADS" -gt "$CPU_N" ] && THREADS="$CPU_N"
GLIBC_VER=$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | tail -1); GLIBC_VER="${GLIBC_VER:-0.0}"

echo "[*] worker=$WORKER cpu=$CPU_N ram=${RAM_MB}MB mode=$RX_MODE threads=$THREADS glibc=$GLIBC_VER"
mkdir -p "$WORKDIR" && cd "$WORKDIR"

SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

# unzip dibutuhkan fast path; python3 jadi fallback kalau unzip gak ada
command -v unzip >/dev/null 2>&1 || { command -v apt-get >/dev/null 2>&1 && $SUDO apt-get install -y -qq unzip; } || true
extract_zip() {
  if command -v unzip >/dev/null 2>&1; then unzip -qo "$1"
  else python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall()" "$1"; fi
}

# ---------------- fast path: prebuilt binary (glibc >= 2.33) -----------------
glibc_ge() { [ "$(printf '%s\n2.33\n' "$1" | sort -V | head -1)" = "2.33" ]; }

if glibc_ge "$GLIBC_VER" && [ ! -x genoryn-miner ]; then
  echo "[*] glibc >= 2.33 — download prebuilt release v1.2.0"
  REL="genoryn-1.2.0-mainnet-linux-x86_64.zip"
  curl -sSL -o "$REL" "https://github.com/genoryn/genoryn/releases/download/v1.2.0/$REL"
  curl -sSL -o "$REL.sha256" "https://github.com/genoryn/genoryn/releases/download/v1.2.0/$REL.sha256"
  sha256sum -c "$REL.sha256"
  extract_zip "$REL"
  cp "genoryn-1.2.0-mainnet-linux-x86_64/genoryn-miner" . && chmod +x genoryn-miner
fi

# ---------------- slow path: build from source -------------------------------
if [ ! -x genoryn-miner ]; then
  echo "[*] building from source (butuh ~5-15 menit tergantung CPU)"
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq cmake build-essential curl git unzip
  if ! command -v cargo >/dev/null 2>&1; then
    curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
    export PATH="$HOME/.cargo/bin:$PATH"
  fi
  [ -d genoryn ] || git clone --depth 1 https://github.com/genoryn/genoryn.git
  cd genoryn
  cargo build --release --bin genoryn-miner
  cp target/release/genoryn-miner "$WORKDIR/" && cd "$WORKDIR"
fi

# ---------------- run --------------------------------------------------------
echo "[*] starting miner -> $POOL"
MAX_ARGS=(); [ "$MAX_SECONDS" != "0" ] && MAX_ARGS=(--max-seconds "$MAX_SECONDS")
exec ./genoryn-miner \
  --pool "$POOL" \
  --wallet "$WALLET" \
  --worker "$WORKER" \
  --threads "$THREADS" \
  --randomx-mode "$RX_MODE" \
  "${MAX_ARGS[@]}"
