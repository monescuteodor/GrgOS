#!/usr/bin/env bash
# =============================================================================
#  scripts/75-ai.sh — GrgOS local AI (Ollama)
#  Private, offline LLMs that run entirely on your machine — nothing leaves it.
#  Perfect for the privacy-focused Security edition and for the AI Desktop.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"
require_user "$@"

echo "== GrgOS local AI (Ollama) =="

# Prefer a GPU build if a GPU is present; fall back to CPU.
if lspci 2>/dev/null | grep -qi 'nvidia'; then
  pac ollama-cuda 2>/dev/null || pac ollama || aur ollama
elif lspci 2>/dev/null | grep -Eqi 'amd/ati|radeon'; then
  pac ollama-rocm 2>/dev/null || pac ollama || aur ollama
else
  pac ollama || aur ollama
fi

sudo systemctl enable --now ollama 2>/dev/null || warn "ollama service not started"

# Pull a small, capable default model (best effort — needs internet + a few GB).
if [[ "${GRGOS_AI_PULL:-1}" == "1" ]]; then
  log "Downloading a starter model (llama3.2, ~2 GB) — best effort"
  ollama pull llama3.2 2>/dev/null || warn "Model not pulled; get one later: ollama run llama3.2"
fi

cat <<'NOTE'

  Local AI ready (private & offline):
    ollama run llama3.2         # chat in the terminal
    ollama run qwen2.5-coder    # coding/hacking helper (pull first)
    ollama list                 # your models
  Everything runs on THIS machine — no data leaves it.
NOTE
ok "AI setup complete"
