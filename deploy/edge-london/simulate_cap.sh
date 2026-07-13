#!/bin/bash

##############################################################################
# File: simulate_cap.sh
# Author: Fabio Malagutti
# Student ID: 0001247400
# Course: Infrastructures for Cloud Computing and Big Data M (A.Y. 2025/2026)
# Instructors: Prof. Antonio Corradi, Prof. Andrea Sabbioni
# File Scope: Demonstration script for CP versus AP/BASE replication semantics.
# Data Integrity: Student ID explicitly standardized for academic traceability.
##############################################################################
# @node: Edge Node (London)
# @component: Replication Semantics Demonstrator
# @objective: Compare, in a demonstrative manner, the latency of the CP model
#             against the AP/BASE model in push/pull flows.
##############################################################################

set -euo pipefail

IMAGE="${IMAGE:-ubuntu:latest}"
CORE="${CORE:?set CORE}"
EDGE="${EDGE:?set EDGE}"

echo "🔄 Preparing the test environment (pulling base image)..."
docker pull "$IMAGE" > /dev/null 2>&1
docker tag "$IMAGE" "$CORE/ubuntu-test:cp"
docker tag "$IMAGE" "$EDGE/ubuntu-test:cp"
docker tag "$IMAGE" "$CORE/ubuntu-test:ap"

echo "---------------------------------------------------"
echo "⚖️ CP MODEL TEST (Strong Consistency / Synchronous)"
echo "The system waits for the write ACK from both Core and Edge."
echo "Latency equation: L = Baseline + Geographical RTT"
echo "---------------------------------------------------"
# Execute the blocking push sequence and time it.
time (docker push "$CORE/ubuntu-test:cp" > /dev/null 2>&1 && docker push "$EDGE/ubuntu-test:cp" > /dev/null 2>&1)

echo ""
echo "---------------------------------------------------"
echo "⚡ AP MODEL TEST (Eventual Consistency / BASE)"
echo "The system waits for the ACK only from the Core node. Replication is asynchronous."
echo "Latency equation: L = Baseline"
echo "---------------------------------------------------"
# Execute the push only on the Core node and time it.
time docker push "$CORE/ubuntu-test:ap" > /dev/null 2>&1

echo ""
echo "✅ Simulation completed."
