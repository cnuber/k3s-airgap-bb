#!/bin/bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
WAIT_TIMEOUT=120
k3s_root_dir=/var/lib/rancher/k3s
bigbang_version=1.5.0
git_mirror_url=http://git-http-backend.git.svc.cluster.local/git
artifact_dir="/opt/artifacts"

loadIronBankImages() {
cp ${artifact_dir}/images/*.tar /var/lib/rancher/k3s/agent/images/ && systemctl restart k3s
}

deployGitServer() {
/usr/local/bin/kubectl apply -k artifacts/git-http-backend
/usr/local/bin/kubectl wait --for=condition=available --timeout "${WAIT_TIMEOUT}s" -n "git" "deployment/git-http-backend"
}

deployFlux() {
/usr/local/bin/kubectl get ns flux-system || /usr/local/bin/k3s kubectl create ns flux-system
/usr/local/bin/kubectl kustomize artifacts/flux > artifacts/flux/flux-deploy.yaml # transform flux manifest with edge settings
cp artifacts/flux/flux-deploy.yaml ${k3s_root_dir}/server/manifests/flux-deploy.yaml
sleep 30
/usr/local/bin/kubectl wait --for=condition=available --timeout "${WAIT_TIMEOUT}s" -n "flux-system" "deployment/helm-controller"
/usr/local/bin/kubectl wait --for=condition=available --timeout "${WAIT_TIMEOUT}s" -n "flux-system" "deployment/source-controller"
/usr/local/bin/kubectl wait --for=condition=available --timeout "${WAIT_TIMEOUT}s" -n "flux-system" "deployment/kustomize-controller"
/usr/local/bin/kubectl wait --for=condition=available --timeout "${WAIT_TIMEOUT}s" -n "flux-system" "deployment/notification-controller"
}

deployBB() {
/usr/local/bin/kubectl get ns bigbang || /usr/local/bin/kubectl create ns bigbang
cp ${artifact_dir}/bigbang-${bigbang_version}.tgz /var/lib/rancher/k3s/server/static/charts/
cat << EOF > /var/lib/rancher/k3s/server/manifests/bigbang.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: bigbang
  namespace: bigbang
spec:
  chart: https://%{KUBERNETES_API}%/static/charts/bigbang-${bigbang_version}.tgz
  valuesContent: |-
    fluentbit:
      enabled: false
      git:
        repo: ${git_mirror_url}/fluentbit
    istio:
      enabled: true
      git:
        repo: ${git_mirror_url}/istio-controlplane
        tag: 1.7.3-bb.14
      values:
        imagePullPolicy: Never
    istiooperator:
      enabled: true
      git:
        repo: ${git_mirror_url}/istio-operator
      values:
        imagePullPolicy: Never
    clusterAuditor:
      enabled: false
    logging:
      enabled: true
      repo: ${git_mirror_url}/logging
      values:
        kibana:
          count: 1
          resources:
            requests:
              cpu: 100m
              memory: 96Mi
            limits:
              cpu: 1000m
              memory: 512Mi
            securityContext:
              runAsUser: 1000
              runAsGroup: 1000
              fsGroup: 1000
        elasticsearch:
          data:
            heap:
              min: 512m
              max: 512m
            count: 1
            resources:
              requests:
                cpu: 100m
                memory: 96Mi
              limits:
                cpu: 1000m
                memory: 512Mi
            persistence:
              size: 10Gi
            securityContext: 
              runAsUser: 1000
              runAsGroup: 1000
              fsGroup: 1000
          master:
            heap:
              min: 512m
              max: 512m
            count: 1
            resources:
              requests:
                cpu: 100m
                memory: 96Mi
              limits:
                cpu: 1000m
                memory: 512Mi
            securityContext:
              runAsUser: 1000
              runAsGroup: 1000
              fsGroup: 1000
    eckoperator:
      enabled: false
    monitoring:
      enabled: true
      git:
        repo: ${git_mirror_url}/monitoring
      values:
        istio:
          alertmanager:
            enabled: false
          grafana:
            enabled: true
          prometheus:
            enabled: true
        alertmanager:
          enabled: false
        grafana:
          enabled: true
        prometheus:
          enabled: true
          prometheusSpec:
            resources:
              limits:
                cpu: 200m
                memory: 200Mi
              requests:
                cpu: 100m
                memory: 100Mi
        prometheusOperator:
          enabled: true
          resources:
            limits:
              cpu: 200m
              memory: 200Mi
            requests:
              cpu: 100m
              memory: 100Mi
        kubeEtcd:
          enabled: false
    twistlock:
      enabled: false
    gatekeeper:
      enabled: false
EOF
}

loadIronBankImages
deployGitServer
deployFlux
deployBB
