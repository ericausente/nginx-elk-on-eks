# nginx-elk-on-eks


# NGINX JSON Log Ingestion to Elastic Stack on EKS (with Filebeat)

**Simple, production-inspired EKS + Helm stack for real-time, field-level NGINX log analytics using Elasticsearch, Kibana, and Filebeat.**

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
- AWS EKS cluster (or any Kubernetes cluster)
- kubectl and helm installed/configured (with admin rights)
- bash shell

2. Deployment (One-Liner)

```
curl -sSL https://raw.githubusercontent.com/your-org/nginx-json-elk-on-eks/main/deploy.sh | bash
```

The script will:
- Deploy ElasticSearch (with password, via Helm)
- Deploy Kibana, expose via AWS LoadBalancer
- Deploy a demo NGINX (with JSON log format)
- Deploy Filebeat with field-level JSON parsing
- Print access details for Kibana/Elastic

3. Access Kibana

Get the Kibana URL and Elastic password from the script output.
Login to Kibana (elastic user) and go to Discover.

Query:
```
kubernetes.deployment.name: nginx-json-demo
```

🎉 You’ll see NGINX logs as structured fields, not just a "message"!


4. Clean Up
```
curl -sSL https://raw.githubusercontent.com/your-org/nginx-json-elk-on-eks/main/cleanup.sh | bash
```

🔍 How It Works

NGINX writes JSON logs to /var/log/nginx/access.log.
Filebeat runs as a DaemonSet, reads /var/log/containers/*.log, parses the JSON from the message field.
ElasticSearch stores, indexes, and secures all logs.
Kibana visualizes/searches by field (e.g., remote_addr, status, request_id, etc.)

📚 Tips, Troubleshooting & FAQs

Why do logs land in the message field at first?
Kubernetes log files contain a timestamp prefix and the log line. Filebeat reads the line as message. We parse the JSON inside message with the decode_json_fields processor.

I see errors about SSL/connection:
Make sure the ElasticSearch host in Filebeat config uses https:// and disables SSL verification for quick tests (set ssl.verification_mode: none). In production, use real certs.

Nothing shows up in Kibana?
Check Filebeat logs: kubectl logs -l app=filebeat-filebeat -n elk

Make sure NGINX logs are JSON (see ConfigMap!)

Check network, Helm status, and pod readiness.

How do I customize log fields or add more NGINX apps?
Edit the NGINX ConfigMap in the script—add or remove keys in the log_format.
Add more deployments; Filebeat will pick them up automatically!

🔒 Security Notes
This example disables certificate verification for quick testing. For real-world use, configure Elastic with real SSL certs, secure passwords, network policies, etc.
Never commit real passwords or secrets!

🧹 Clean Removal
Run cleanup.sh to remove all demo resources and Helm releases.


