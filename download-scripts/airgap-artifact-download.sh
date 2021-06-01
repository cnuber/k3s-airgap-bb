#!/bin/bash

while getopts b:i:u:p: flag
do
    case "${flag}" in
        b) bigbang=${OPTARG};;
        i) ironbank=${OPTARG};;
        u) registry1_user=${OPTARG};;
        p) registry1_pass=${OPTARG};;
    esac
done

artifact_dir="/opt/artifacts"

k3s_artifacts() {
k3s_version="v1.21.1+k3s1" # choose your version from https://github.com/k3s-io/k3s/releases
architecture="amd64" # amd64,arm,arm64, armhf supported
bigbang_version="1.5.0"
registry1_url="registry1.dso.mil"

# install utilities needed by download script

yum install git yum-utils -y

# download pre-req RPMs

mkdir -p ${artifact_dir}/rpms
yumdownloader --resolve --destdir=${artifact_dir}/rpms/ container-selinux selinux-policy-base iscsi-initiator-utils

# download k3s binary
curl -L https://github.com/k3s-io/k3s/releases/download/${k3s_version}/k3s --output ${artifact_dir}/k3s
chmod +x ${artifact_dir}/k3s

# download k3s airgap images
curl -L https://github.com/k3s-io/k3s/releases/download/${k3s_version}/k3s-airgap-images-${architecture}.tar --output ${artifact_dir}/k3s-airgap-images-amd64.tar

# download k3s rpms
curl -L https://rpm.rancher.io/k3s/latest/common/centos/7/noarch/k3s-selinux-0.2-1.el7_8.noarch.rpm --output ${artifact_dir}/rpms/k3s-selinux.noarch.rpm

# Download k3s installation script
curl -L https://get.k3s.io --output ${artifact_dir}/k3s-install.sh
chmod +x ${artifact_dir}/k3s-install.sh
}

bigbang_artifacts() {

# Download flux manifest

curl -L https://repo1.dso.mil/platform-one/big-bang/bigbang/-/raw/${bigbang_version}/scripts/deploy/flux.yaml --output ${artifact_dir}/flux.yaml

# Download bigbang repository

curl -L https://repo1.dso.mil/platform-one/big-bang/bigbang/-/archive/${bigbang_version}/bigbang-${bigbang_version}.tar.gz | tar -xzvf - -C ${artifact_dir}/
tar -czvf ${artifact_dir}/bigbang.tgz ${artifact_dir}/bigbang-${bigbang_version}/chart

# Copy flux manifest

\cp -r ${artifact_dir}/bigbang-${bigbang_version}/scripts/deploy/flux.yaml ${artifact_dir}/flux.yaml

# Download bigbang application repositories
mkdir -p ${artifact_dir}/git
for repo in $(grep "repo: https://repo1" ${artifact_dir}/bigbang-${bigbang_version}/chart/values.yaml |awk '{print $2}') ; do
  rm -rf ${artifact_dir}/git/$(echo $repo |cut -d / -f8 |cut -d . -f1) ;
  git clone $repo ${artifact_dir}/git/$(echo $repo |cut -d / -f8 |cut -d . -f1) ;
done

# package up the artifacts for airgap transfer
}

ironbank_artifacts() {
mkdir -p ${artifact_dir}/images

# Install K3S for containerd utils

curl -sfL https://get.k3s.io | sh -

if [[ -z "$registry1_user" ]] ; then
echo "you must provide your registry1 username with a -u flag and your registry1 password with a -p flag"
exit 1
fi

# get ironbank images

for fluximage in $(grep "image: registry1" ${artifact_dir}/flux.yaml  |awk '{print $2}') ; do
  /usr/local/bin/ctr image pull -u $registry1_user:$registry1_pass $fluximage && /usr/local/bin/ctr image export ${artifact_dir}/images/$(echo $fluximage |sed 's/\//-/g' |sed 's/\:/-/g').tar $fluximage
done

ibImages=(
opensource/openpolicyagent/gatekeeper:v3.1.2
opensource/istio/operator:1.7.3
opensource/istio/pilot:1.7.3
opensource/jaegertracing/all-in-one:1.19.2
opensource/istio-1.7/proxyv2-1.7:1.7.7
opensource/kiali/kiali:v1.23.0
opensource/coreos/kube-state-metrics:v1.9.7
opensource/prometheus/node-exporter:v1.0.1
opensource/jet/kube-webhook-certgen:v1.5.1
opensource/coreos/prometheus-operator:v0.42.1
opensource/jimmidyson/configmap-reload:v0.4.0
opensource/coreos/prometheus-config-reloader:v0.42.1
opensource/kubernetes-1.19/kubectl-1.19:latest
opensource/prometheus/prometheus:v2.22.0
opensource/grafana/grafana:7.1.3-1
opensource/fluent/fluent-bit:1.7.2
elastic/kibana/kibana:7.9.2
elastic/eck-operator/eck-operator:1.3.0
elastic/elasticsearch/elasticsearch:7.9.2
kiwigrid/k8s-sidecar:1.3.0
)

for image in ${ibImages[@]} ; do
/usr/local/bin/ctr image pull -u $registry1_user:$registry1_pass $registry1_url/ironbank/$image && /usr/local/bin/ctr image export ${artifact_dir}/images/$(echo $image |sed 's/\//-/g' |sed 's/\:/-/g').tar $registry1_url/ironbank/$image
done

# get local git repo image

/usr/local/bin/ctr image pull docker.io/bgulla/git-http-backend:latest && /usr/local/bin/ctr image export ${artifact_dir}/images/git-http-backend.tar docker.io/bgulla/git-http-backend:latest
}

k3s_artifacts

if [[ $bigbang == true ]] ; then  
  bigbang_artifacts
else
  echo "skipping bigbang artifact download as -b flag not set as true"
fi

if [[ $ironbank == true ]] ; then
  ironbank_artifacts
else
  echo "skipping ironbank image downloads as -i flag not set as true"
fi

tar -czvf ~/artifacts-airgap.tar.gz ${artifact_dir}
