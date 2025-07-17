<img width="3617" height="1982" alt="Screenshot 2025-07-17 094035" src="https://github.com/user-attachments/assets/9a1b7e19-ee26-4e81-8846-1784c59e0067" /># Kubernetes ELK Stack with NGINX JSON Logs and Filebeat (EKS-Ready)

A one-script quickstart for observability:  
Deploy ephemeral **Elasticsearch**, **Kibana**, **Filebeat**, and a demo **NGINX** pod (with JSON-formatted access logs) in your Kubernetes cluster.  
Good for PoC, labs, or as a bootstrap for prod patterns.

---

## 📖 Overview

This repo lets you **deploy and ingest Kubernetes NGINX logs (JSON format)** into Elastic Stack (Elasticsearch + Kibana) on AWS EKS, using Filebeat as the shipper.  
No guesswork: *NGINX emits JSON logs → Filebeat parses and enriches → Elasticsearch → Kibana (search and visualize fields!)*

### Architecture

```plaintext
+-----------------+      +---------------------+      +-------------------+      +--------------+
|  NGINX PODS     | ---> |   Filebeat Daemon   | ---> |  Elasticsearch    | ---> |   Kibana     |
| (Structured     |      | (K8s, parses        |      | (Helm, HTTPS)     |      | (Helm)       |
| JSON logs)      |      | JSON logs)          |      |                   |      |              |
+-----------------+      +---------------------+      +-------------------+      +--------------+
```


🚀 Quickstart

1. Prerequisites
- `kubectl` and `helm` installed and pointing to your cluster
- Cluster allows LoadBalancer service (e.g., AWS EKS)
- Bash shell


2. Deployment (One-Liner)

```
curl -sSL https://raw.githubusercontent.com/ericausente/nginx-elk-on-eks/refs/heads/main/deploy.sh | bash
```

What This Script Does
- Creates a dedicated namespace for all resources
- Adds the Elastic Helm repo
- Deploys Elasticsearch (ephemeral, single node, no persistent disk)
- Prints the auto-generated elastic password
- Deploys Kibana as a LoadBalancer service (get real AWS/GCP/Azure URL)
- Deploys a demo NGINX pod with production-style JSON log format, exposed via LoadBalancer
- Creates a Filebeat values file for optimal JSON log parsing (parsing logs from /var/log/containers/)
- Deploys Filebeat as a DaemonSet using Helm and your custom values
- Prints the ready-to-use URLs for Kibana and NGINX demo

Output Example
After a few minutes, you’ll see output similar to:
```
Elasticsearch username: elastic
Elasticsearch password: [auto-generated]
Kibana URL: http://a1b2c3d4e5fbc7h8.ap-southeast-1.elb.amazonaws.com:5601
NGINX Demo URL: http://a9b8c7d6e5f4g3i2.ap-southeast-1.elb.amazonaws.com
```

3. Access Kibana

Get the Kibana URL and Elastic password from the script output.
Login to Kibana (elastic user) and go to Discover (index: filebeat*).

Query:
```
kubernetes.deployment.name: nginx-json-demo
```

🎉 You’ll see NGINX logs as structured fields, not just a "message"!

Sample Screenshot
Non-working JSON parsing: 
<img width="1720" height="917" alt="Screenshot 2025-07-16 235356" src="https://github.com/user-attachments/assets/975aa38d-90a9-4bfb-93f9-cc932d00b8e9" />

Working (Successfully parsing the JSON from the message field): 
<img width="3617" height="1982" alt="Screenshot 2025-07-17 094035" src="https://github.com/user-attachments/assets/a16cd808-2447-400e-b78f-532483296f1f" />

4. Clean Up
```
curl -sSL https://raw.githubusercontent.com/ericausente/nginx-elk-on-eks/refs/heads/main/cleanup.sh | bash
```

🔍 How It Works

NGINX writes JSON logs to /var/log/nginx/access.log.
Filebeat runs as a DaemonSet, reads /var/log/containers/*.log, parses the JSON from the message field.
ElasticSearch stores, indexes, and secures all logs.
Kibana visualizes/searches by field (e.g., remote_addr, status, request_id, etc.)

### Filebeat Parsing Logic
- Monitors /var/log/containers/*.log (K8s best practice)
- Adds k8s metadata (namespace, pod, deployment)
- Parses JSON fields for each log line (from message field)

Snippet (see filebeat-values.yaml in the script):
```
filebeatConfig:
  filebeat.yml: |-
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*.log
      processors:
        - add_kubernetes_metadata:
            matchers:
              - logs_path:
                  logs_path: "/var/log/containers/"
        - decode_json_fields:
            fields: ["message"]
            target: ""
            overwrite_keys: true
    output.elasticsearch:
      hosts: ["https://$CLUSTERIP:9200"]
      username: "elastic"
      password: "$ES_PASSWORD"
      protocol: https
      ssl.verification_mode: none
```

📚 Tips, Troubleshooting & FAQs

### Why do logs land in the message field at first?
Kubernetes log files contain a timestamp prefix and the log line. Filebeat reads the line as message. We parse the JSON inside message with the decode_json_fields processor.

### I see errors about SSL/connection:
Make sure the ElasticSearch host in Filebeat config uses https:// and disables SSL verification for quick tests (set ssl.verification_mode: none). In production, use real certs.

### Nothing shows up in Kibana?
Check Filebeat logs: kubectl logs -l app=filebeat-filebeat -n elk
Make sure NGINX logs are JSON (see ConfigMap!)
Check network, Helm status, and pod readiness.

### How do I customize log fields or add more NGINX apps?
Edit the NGINX ConfigMap in the script—add or remove keys in the log_format.
Add more deployments; Filebeat will pick them up automatically!

### Wait for LoadBalancer provisioning (can take 2–3 minutes on EKS).


🔒 Security Notes
This example disables certificate verification for quick testing. For real-world use, configure Elastic with real SSL certs, secure passwords, network policies, etc.
Never commit real passwords or secrets!

🧹 Clean Removal
Run cleanup.sh to remove all demo resources and Helm releases.
