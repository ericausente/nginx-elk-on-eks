#!/bin/bash
set -e

NAMESPACE=elk

# 1. Create Namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 2. Add Elastic Helm repo
helm repo add elastic https://helm.elastic.co
helm repo update

# 3. Deploy Elasticsearch (ephemeral, single node)
helm upgrade --install elasticsearch elastic/elasticsearch \
  --namespace $NAMESPACE \
  --set replicas=1 \
  --set minimumMasterNodes=1 \
  --set persistence.enabled=false

echo "Waiting for Elasticsearch pod to be ready..."
kubectl wait --for=condition=Ready pod -l app=elasticsearch-master -n $NAMESPACE --timeout=300s

# 4. Retrieve ES Password
ES_PASSWORD=$(kubectl get secrets --namespace=$NAMESPACE elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d)
echo "Elasticsearch username: elastic"
echo "Elasticsearch password: $ES_PASSWORD"

# 5. Get Elasticsearch ClusterIP
CLUSTERIP=$(kubectl get svc elasticsearch-master -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
echo "Elasticsearch ClusterIP is $CLUSTERIP"

# 6. Deploy Kibana as LoadBalancer, use ClusterIP
helm upgrade --install kibana elastic/kibana \
  --namespace $NAMESPACE \
  --set env.ELASTICSEARCH_USERNAME=elastic \
  --set env.ELASTICSEARCH_PASSWORD="$ES_PASSWORD" \
  --set env.ELASTICSEARCH_HOSTS="http://$CLUSTERIP:9200" \
  --set service.type=LoadBalancer

echo "Waiting for Kibana LoadBalancer endpoint..."
for i in {1..30}; do
  KIBANA_LB=$(kubectl get svc kibana-kibana -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [[ -n "$KIBANA_LB" ]]; then break; fi
  sleep 10
done
echo "Kibana URL: http://$KIBANA_LB:5601"

# 7. Deploy NGINX demo (JSON logs, LoadBalancer service)
cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-json-demo-conf
data:
  nginx.conf: |
    events { }
    http {
      log_format json_combined escape=json
        '{'
          '"time":"\$time_iso8601",'
          '"remote_addr":"\$remote_addr",'
          '"request_id":"\$request_id",'
          '"request":"\$request",'
          '"status":\$status,'
          '"body_bytes_sent":\$body_bytes_sent,'
          '"request_time":\$request_time,'
          '"upstream_addr":"\$upstream_addr",'
          '"upstream_response_time":"\$upstream_response_time",'
          '"http_referrer":"\$http_referer",'
          '"http_user_agent":"\$http_user_agent"'
        '}';
      access_log /var/log/nginx/access.log json_combined;
      server {
        listen 80;
        location / {
          return 200 'NGINX JSON Log Demo';
        }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-json-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-json-demo
  template:
    metadata:
      labels:
        app: nginx-json-demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-conf
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: nginx-conf
        configMap:
          name: nginx-json-demo-conf
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-json-demo
spec:
  type: LoadBalancer
  selector:
    app: nginx-json-demo
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF

echo "Waiting for NGINX LoadBalancer endpoint..."
for i in {1..30}; do
  NGINX_LB=$(kubectl get svc nginx-json-demo -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [[ -n "$NGINX_LB" ]]; then break; fi
  sleep 10
done
echo "NGINX Demo URL: http://$NGINX_LB"

# 8. Create Filebeat values.yaml for NGINX JSON logs (persistent, field-level parsing)
cat <<EOF > filebeat-values.yaml
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
EOF

# 9. Deploy Filebeat with Helm (using values file)
helm upgrade --install filebeat elastic/filebeat \
  --namespace $NAMESPACE \
  --set daemonset.enabled=true \
  --set deployment.enabled=false \
  -f filebeat-values.yaml


echo ""
echo "# ELK Stack (ephemeral), demo NGINX, and Filebeat deployed!"
echo "# Elastic username: elastic"
echo "# Elastic password: $ES_PASSWORD"
echo "# Kibana URL: http://$KIBANA_LB:5601"
echo "# NGINX Demo URL: http://$NGINX_LB"
echo "# Search in Kibana Discover: 'kubernetes.deployment.name: nginx-json-demo'"
