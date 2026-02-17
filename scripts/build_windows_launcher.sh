#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/dist"
mkdir -p "$OUTPUT_DIR"

cd "$ROOT_DIR"
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -ldflags="-s -w -H=windowsgui" -o "$OUTPUT_DIR/RunPirateRPG.exe" ./tools/launcher/main.go

echo "Built $OUTPUT_DIR/RunPirateRPG.exe"
