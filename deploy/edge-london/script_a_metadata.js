// ==============================================================================
// File: script_a_metadata.js
// Author: Fabio Malagutti
// Student ID: 0001247400
// Course: Infrastructures for Cloud Computing and Big Data M (A.Y. 2025/2026)
// Instructors: Prof. Antonio Corradi, Prof. Andrea Sabbioni
// File Scope: Metadata-oriented k6 load generation for registry manifest reads.
// Data Integrity: Student ID explicitly standardized for academic traceability.
// ==============================================================================
// @node: Edge Node (London)
// @component: Load Generator Client / Metadata Probe
// @objective: Validate the hypothesis that manifest GET latency exposes
//             middleware cost and the sidecar tax of the stateful registry.
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
                // The test fails if the 95th or 99th percentile exceeds these latencies (ms).
                http_req_duration: ['p(95)<500', 'p(99)<1000'],
                // Maximum error tolerance: 1%.
                http_req_failed: ['rate<0.01'], 
            },
        };
    }

    return {
        insecureSkipTLSVerify: true,
        
        // Load phases (ramp-up, baseline, step-up, drain).
        stages: [
            { duration: '30s', target: 20 },  // [RAMP-UP] 30 seconds / 20 Virtual Users (VUs)
            { duration: '1m', target: 20 },   // [BASELINE] 60 seconds / 20 VUs
            { duration: '30s', target: 50 }, // [STEP-UP] 30 seconds / 50 VUs
            { duration: '30s', target: 0 },   // [DRAIN] 30 seconds / 0 VUs
        ],
        
        // Validation metrics (the core of the QoS analysis).
        thresholds: {
            // The test fails if the 95th or 99th percentile exceeds these latencies (ms).
            http_req_duration: ['p(95)<500', 'p(99)<1000'],
            // Maximum error tolerance: 1%.
            http_req_failed: ['rate<0.01'], 
        },
    };
};

// ==========================================
// CONFIGURAZIONE DEL TEST (QoS & SLA)
// ==========================================
export const options = buildOptions();

// ==========================================
// LOGICA DI ESECUZIONE (WORKLOAD)
// ==========================================
export default function () {
    // Dynamic target acquisition (Port 5000 = Registry2, Port 8080 = Harbor).
    // If not provided, a local default is used for safety.
    const baseUrl = __ENV.TARGET_URL || 'https://localhost:5000';
    
    // Test image (must already exist in the registry before the test runs).
    const imageRepo = 'my-alpine';
    
    // Use tag 'v1' (already pushed to both registries).
    const tag = 'v1'; 
    
    // Build the URL using tag v1.
    const url = `${baseUrl}/v2/${imageRepo}/manifests/${tag}`;
    const params = {
        headers: {
            // Accept both Docker V2 and OCI manifest formats.
            'Accept': 'application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json',
            // Engineering design rationale: keep-alive reduces handshake overhead
            // and exposes the pure middleware latency.
            'Connection': 'keep-alive',
            'Authorization': 'Basic YWRtaW46SGFyYm9yMTIzNDU=',
        },
        timeout: '30s',
        tags: { name: 'GetManifest' }
    };


    // Execute the GET request.
    const res = http.get(url, params);

    check(res, {
        'status is 200': (r) => {
            return r.status === 200;
        },
        'is valid json': (r) => r.json() !== null,
    });

    // Short pause to avoid artificial CPU saturation on the client (London).
    sleep(0.1);
}
