#!/usr/bin/env bash
# =============================================================================
# GENORYN (GNR) sandbox miner — one-paste setup
# Primary: download prebuilt binary dari repo ini (no zip, no build)
# Fallback: official release zip -> build from source
# Pool: AriaPool (PPLNS, 3% fee, custodial) · CPU RandomX mining
# =============================================================================
set -euo pipefail

# ---------------- config (override via env) ----------------------------------
WALLET="${WALLET:-gnr19mymj54r9kwqhgnmxcu4hwkpvzchx230lfcndgz74f6kl5hhz9fhvy0gdnr86h640zgfsc8cpkz}"
POOL="${POOL:-tls://gnr.ariabrain.com:3351}"
WORKER="${WORKER:-sandbox-$(hostname)-$RANDOM}"
WORKDIR="${WORKDIR:-$HOME/genoryn-sandbox}"
MAX_SECONDS="${MAX_SECONDS:-0}"   # 0 = jalan terus; set mis. 3600 buat bounded run
REPO_DL="https://github.com/kangbaxso/gnr-sandbox-miner/releases/download/v1.0.0"

# ---------------- auto-detect resources --------------------------------------
CPU_N=$(nproc)
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
# RandomX: auto = 1 dataset 2GiB shared (fast); light = 256MiB per thread (max 16)
if [ "$RAM_MB" -ge 4096 ]; then RX_MODE="auto"; THREADS="$CPU_N"
else RX_MODE="light"; THREADS=$(( RAM_MB / 400 )); [ "$THREADS" -lt 1 ] && THREADS=1; [ "$THREADS" -gt 16 ] && THREADS=16; fi
[ "$THREADS" -gt "$CPU_N" ] && THREADS="$CPU_N"
GLIBC_VER=$(ldd --version 2>/dev/null | awk 'NR==1{for(i=NF;i>0;i--)if($i ~ /^[0-9]+\.[0-9]+$/){print $i; break}}'); GLIBC_VER="${GLIBC_VER:-0.0}"

echo "[*] worker=$WORKER cpu=$CPU_N ram=${RAM_MB}MB mode=$RX_MODE threads=$THREADS glibc=$GLIBC_VER"
mkdir -p "$WORKDIR" && cd "$WORKDIR"

SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

# version compare: ver_ge A B -> true kalau A >= B (sed baca semua input, aman dari SIGPIPE)
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | sed -n '1p')" = "$2" ]; }

# ---------------- primary: prebuilt binary dari repo ini ---------------------
if [ ! -x genoryn-miner ]; then
  if ver_ge "$GLIBC_VER" "2.34"; then BIN="genoryn-miner"               # official release build
  else BIN="genoryn-miner-ubuntu2004"; fi                                # source build, glibc 2.31+
  echo "[*] downloading $BIN dari repo (glibc $GLIBC_VER)"
  if curl -fsSL -m 300 -o "$BIN" "$REPO_DL/$BIN" && curl -fsSL -m 60 -o "$BIN.sha256" "$REPO_DL/$BIN.sha256"; then
    sha256sum -c "$BIN.sha256" && mv "$BIN" genoryn-miner && chmod +x genoryn-miner
  else
    echo "[!] download dari repo gagal — fallback ke official release"
  fi
fi

# ---------------- fallback 1: official release zip (full package) ------------
if [ ! -x genoryn-miner ]; then
  echo "[*] download official release v1.2.0 (full package)"
  command -v unzip >/dev/null 2>&1 || { command -v apt-get >/dev/null 2>&1 && $SUDO apt-get install -y -qq unzip; } || true
  REL="genoryn-1.2.0-mainnet-linux-x86_64.zip"
  curl -sSL -m 500 -o "$REL" "https://github.com/genoryn/genoryn/releases/download/v1.2.0/$REL"
  curl -sSL -o "$REL.sha256" "https://github.com/genoryn/genoryn/releases/download/v1.2.0/$REL.sha256"
  sha256sum -c "$REL.sha256"
  if command -v unzip >/dev/null 2>&1; then unzip -qo "$REL"
  else python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall()" "$REL"; fi
  cp "genoryn-1.2.0-mainnet-linux-x86_64/genoryn-miner" . && chmod +x genoryn-miner
fi

# ---------------- fallback 2: build from source ------------------------------
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
