# gnr-sandbox-miner

One-paste GENORYN (GNR) sandbox miner. Auto-detects CPU/RAM/glibc, downloads the prebuilt release (glibc >= 2.33) or builds from source, then mines to AriaPool.

## Usage

```bash
curl -sSL https://raw.githubusercontent.com/kangbaxso/gnr-sandbox-miner/main/mine-gnr-sandbox.sh | bash
```

Env overrides: `WALLET`, `POOL`, `WORKER`, `WORKDIR`, `MAX_SECONDS` (0 = run forever).

CPU RandomX mining (no GPU). Tested on Ubuntu 20.04 (build path) and release-binary path.
