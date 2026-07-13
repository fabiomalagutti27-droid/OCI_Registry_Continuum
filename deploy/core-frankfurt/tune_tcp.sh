#!/bin/bash

##############################################################################
# File: tune_tcp.sh
# Author: Fabio Malagutti
# Student ID: 0001247400
# Course: Infrastructures for Cloud Computing and Big Data M (A.Y. 2025/2026)
# Instructors: Prof. Antonio Corradi, Prof. Andrea Sabbioni
# File Scope: Kernel TCP tuning utility for the BDP experiment on the Core node.
# Data Integrity: Student ID explicitly standardized for academic traceability.
##############################################################################
# @node: Core Server (Frankfurt)
# @component: Core Server TCP Tuning Utility
# @objective: Validate the hypothesis that reducing the TCP window alters the
#             BDP and exposes the dependency on FRA-LON latency.
##############################################################################

# ==============================================================================
# TCP TUNING SCRIPT - BDP EXPERIMENT (Blueprint v3.0)
# ==============================================================================
# This script modifies Linux kernel TCP buffers on the fly.
# It must be executed on the SERVER node (Frankfurt) to constrain the send
# window.
# ==============================================================================

set -euo pipefail

# Verify root privileges (required for sysctl).
if [ "$EUID" -ne 0 ]; then
  echo "❌ ERRORE: Questo script deve essere eseguito come root. Usa: sudo ./tune_tcp.sh <modalita>"
  exit 1
fi

# Argument check.
if [ -z "$1" ]; then
  echo "🛠️  Usage: sudo ./tune_tcp.sh [default | medium | collapse]"
  echo "  default  -> Restore Ubuntu standard autotuning (maximum performance)"
  echo "  medium   -> Limit buffers to 256KB (moderate throttling)"
  echo "  collapse -> Limit buffers to 64KB (total BDP collapse)"
  exit 1
fi

MODE="$1"

echo "====================================================="
echo "⚙️  APPLICAZIONE PROFILO TCP: $MODE"
echo "====================================================="

case "$MODE" in
  default)
    # Restore Ubuntu 24.04 defaults (autotuning enabled, large buffers).
    # tcp_wmem / tcp_rmem format: "minimum default maximum" (in bytes).
    sysctl -w net.ipv4.tcp_rmem="4096 131072 6291456"
    sysctl -w net.ipv4.tcp_wmem="4096 16384 4194304"
    sysctl -w net.core.rmem_max=212992
    sysctl -w net.core.wmem_max=212992
    echo "✅ TCP autotuning restored. No BDP limitation is applied."
    ;;
  medium)
    # [TCP WINDOW LIMIT] 256KB = 262144 bytes; a compromise between throughput
    # and latency to observe a window smaller than the theoretical BDP.
    sysctl -w net.ipv4.tcp_rmem="4096 87380 262144"
    sysctl -w net.ipv4.tcp_wmem="4096 16384 262144"
    sysctl -w net.core.rmem_max=262144
    sysctl -w net.core.wmem_max=262144
    echo "⚠️  TCP buffers limited to 256KB. A slight degradation may be visible on WAN traffic."
    ;;
  collapse)
    # [ENGINEERING DESIGN RATIONALE] 64KB = 65536 bytes forces BDP collapse,
    # stalling TCP windowing under the geographical FRA-LON latency.
    sysctl -w net.ipv4.tcp_rmem="4096 16384 65536"
    sysctl -w net.ipv4.tcp_wmem="4096 16384 65536"
    sysctl -w net.core.rmem_max=65536
    sysctl -w net.core.wmem_max=65536
    echo "🚨 BDP COLLAPSE: TCP buffers locked at 64KB. Throughput will be severely limited by RTT."
    ;;
  *)
    echo "❌ Invalid parameter. Choose among: default, medium, collapse."
    exit 1
    ;;
esac

echo "====================================================="
echo "📊 CURRENT BUFFER STATE:"
sysctl net.ipv4.tcp_wmem
sysctl net.ipv4.tcp_rmem
echo "====================================================="