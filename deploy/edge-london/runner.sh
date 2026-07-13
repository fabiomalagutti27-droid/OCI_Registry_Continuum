#!/bin/bash

##############################################################################
# File: runner.sh
# Author: Fabio Malagutti
# Student ID: 0001247400
# Course: Infrastructures for Cloud Computing and Big Data M (A.Y. 2025/2026)
# Instructors: Prof. Antonio Corradi, Prof. Andrea Sabbioni
# File Scope: Client-side k6 experiment orchestration for the London node.
# Data Integrity: Student ID explicitly standardized for academic traceability.
##############################################################################
# @node: Edge Node (London)
# @component: Client-Side Experiment Orchestrator
# @objective: Generate k6 traffic toward the Core Server to measure SLA, QoS,
#             and latency differences between stateless and stateful paths.
##############################################################################
set -euo pipefail

TARGET_IP="${TARGET_IP:?set TARGET_IP}"
BLOB_DIGEST="${BLOB_DIGEST:?set BLOB_DIGEST}"
RUNS=3
WAIT_TIME=15

mkdir -p results
echo "🚀 INIZIO SUITE DI TEST..."

for i in $(seq 1 "$RUNS"); do
    echo "--- RUN $i ---"
    
    # [METADATA PROBE] Registry A: manifest GET to evaluate sidecar tax.
    k6 run -e TARGET_URL="http://${TARGET_IP}:5000" --out "csv=results/run${i}_metadata_registryA.csv" script_a_metadata.js
    sleep "$WAIT_TIME"

    # [METADATA PROBE] Harbor: manifest GET on the stateful path to measure
    # middleware and control-plane overhead.
    k6 run -e TARGET_URL="http://${TARGET_IP}:8080" --out "csv=results/run${i}_metadata_harbor.csv" script_a_metadata.js
    sleep "$WAIT_TIME"

    # [PAYLOAD PROBE] Registry A: blob pull to isolate I/O wait and throughput.
    k6 run -e TARGET_URL="http://${TARGET_IP}:5000" -e BLOB_DIGEST="${BLOB_DIGEST}" --out "csv=results/run${i}_payload_registryA.csv" script_b_payload.js
    sleep "$WAIT_TIME"

    # [PAYLOAD PROBE] Harbor: blob pull to compare the stateful backend.
    k6 run -e TARGET_URL="http://${TARGET_IP}:8080" -e BLOB_DIGEST="${BLOB_DIGEST}" --out "csv=results/run${i}_payload_harbor.csv" script_b_payload.js
    
    sleep 30
done

# -----------------------------------------------------------------------------
# RUN 4 - PEAK STRESS TEST MANUAL COMMANDS
# Use the dynamic flat-profile override to force 500 VUs for 5 minutes.
# Metadata probe:
# k6 run -e TARGET_URL="http://${TARGET_IP}:5000" -e VUS=500 -e DURATION=5m --out csv=results/run4_metadata_registryA.csv script_a_metadata.js
# k6 run -e TARGET_URL="http://${TARGET_IP}:8080" -e VUS=500 -e DURATION=5m --out csv=results/run4_metadata_harbor.csv script_a_metadata.js
# Payload probe:
# k6 run -e TARGET_URL="http://${TARGET_IP}:5000" -e BLOB_DIGEST="${BLOB_DIGEST}" -e VUS=500 -e DURATION=5m --out csv=results/run4_payload_registryA.csv script_b_payload.js
# k6 run -e TARGET_URL="http://${TARGET_IP}:8080" -e BLOB_DIGEST="${BLOB_DIGEST}" -e VUS=500 -e DURATION=5m --out csv=results/run4_payload_harbor.csv script_b_payload.js
echo "✅ ESPERIMENTO COMPLETATO."
