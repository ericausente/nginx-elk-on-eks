#!/bin/bash
set -euo pipefail

NAMESPACE=elk

echo "Uninstalling Helm releases..."
helm uninstall filebeat -n $NAMESPACE || true
helm uninstall kibana -n $NAMESPACE --no-hooks || true
helm uninstall elasticsearch -n $NAMESPACE || true

echo "Deleting leftover Kibana Helm hook resources..."
kubectl delete serviceaccount pre-install-kibana-kibana -n $NAMESPACE --ignore-not-found
kubectl delete serviceaccount post-delete-kibana-kibana -n $NAMESPACE --ignore-not-found
kubectl delete role pre-install-kibana-kibana -n $NAMESPACE --ignore-not-found
kubectl delete role post-delete-kibana-kibana -n $NAMESPACE --ignore-not-found
kubectl delete rolebinding pre-install-kibana-kibana -n $NAMESPACE --ignore-not-found
kubectl delete rolebinding post-delete-kibana-kibana -n $NAMESPACE --ignore-not-found
kubectl delete configmap kibana-kibana-helm-scripts -n $NAMESPACE --ignore-not-found
kubectl delete job -n $NAMESPACE -l "release=kibana" --ignore-not-found

echo "Deleting NGINX demo deployment/configmap..."
kubectl delete deployment nginx-json-demo -n $NAMESPACE --ignore-not-found
kubectl delete configmap nginx-json-demo-conf -n $NAMESPACE --ignore-not-found

echo "Deleting Filebeat values file if present..."
rm -f filebeat-values.yaml || true

echo "Deleting namespace $NAMESPACE (this removes any leftovers)..."
kubectl delete ns $NAMESPACE --ignore-not-found

echo "Cleanup complete."
