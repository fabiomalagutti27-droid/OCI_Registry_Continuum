// ==============================================================================
// File: script_b_payload.js
// Author: Fabio Malagutti
// Student ID: 0001247400
// Course: Infrastructures for Cloud Computing and Big Data M (A.Y. 2025/2026)
// Instructors: Prof. Antonio Corradi, Prof. Andrea Sabbioni
// File Scope: Payload-oriented k6 load generation for blob download tests.
// Data Integrity: Student ID explicitly standardized for academic traceability.
// ==============================================================================
// @node: Edge Node (London)
// @component: Load Generator Client / Blob I/O Probe
// @objective: Validate the hypothesis that heavy layer downloads measure the
//             I/O bottleneck and the effective TCP window.
// ==============================================================================
import http from 'k6/http';
import { check, sleep } from 'k6';

const hasFlatProfile = __ENV.VUS && __ENV.DURATION;

const buildOptions = () => {
    if (hasFlatProfile) {
        return {
            insecureSkipTLSVerify: true,
            vus: Number(__ENV.VUS),
            duration: __ENV.DURATION,
            thresholds: {
                // Latencies for 100MB blobs will necessarily be higher.
                // P95 and P99 indicate whether there is anomalous queueing at disk level (SLA).
                http_req_duration: ['p(95)<3000', 'p(99)<6000'],
                http_req_failed: ['rate<0.05'], 
            },
        };
    }

    return {
        insecureSkipTLSVerify: true,
        
        // Because payloads are heavy, the maximum VU target is lower than for
        // metadata to observe disk saturation and TCP windowing behavior.
        stages: [
            { duration: '30s', target: 20 },  // [RAMP-UP] 30 seconds / 20 VUs
            { duration: '1m', target: 20 },   // [BASELINE] 60 seconds / 20 VUs
            { duration: '30s', target: 50 },  // [STEP-UP] 30 seconds / 50 VUs
            { duration: '1m', target: 50 },   // [STEADY STATE] 60 seconds / 50 VUs
            { duration: '30s', target: 100 }, // [SPIKE TEST] 30 seconds / 100 VUs
            { duration: '30s', target: 0 },   // [DRAIN] 30 seconds / 0 VUs
        ],
        
        thresholds: {
            // Latencies for 100MB blobs will necessarily be higher.
            // P95 and P99 indicate whether there is anomalous queueing at disk level (SLA).
            http_req_duration: ['p(95)<3000', 'p(99)<6000'],
            http_req_failed: ['rate<0.05'], 
        },
    };
};

// ==========================================
// CONFIGURAZIONE DEL TEST I/O E PAYLOAD PESANTI
// ==========================================
export const options = buildOptions();

// [WORKLOAD] Download del blob per stressare il backend e la rete.
export default function () {
    const baseUrl = __ENV.TARGET_URL || 'http://localhost:5000';
    
    // Adjust this if the repository name used in Harbor differs.
    const imageRepo = 'my-alpine';
    
    // The digest is passed correctly by runner.sh via __ENV.BLOB_DIGEST.
    const blobDigest = __ENV.BLOB_DIGEST; 

    // Correct URL for downloading the layer (blob).
    const url = `${baseUrl}/v2/${imageRepo}/blobs/${blobDigest}`;
    
    const params = {
        headers: {
            'Accept': 'application/octet-stream',
            // Engineering design rationale: keep-alive removes transport handshake
            // overhead and makes backend throughput directly measurable.
            'Connection': 'keep-alive',
        },
        tags: { name: 'PullLayer_Heavy' },
        timeout: '120s', // [TIMEOUT] 120 seconds for a 100MB layer transfer.
        
        // Critical to prevent client crashes (London):
        // k6 downloads the payload to measure network and server disk behavior,
        // but discards it immediately without storing it in client RAM.
        responseType: 'none', // [MEMORY MODE] discard body to avoid client OOM.
    };

    const res = http.get(url, params);

    check(res, {
        'status is 200': (r) => r.status === 200,
    });

    // Longer pause to avoid an unmanaged DDoS-like burst.
    sleep(1);
}
