#!/bin/bash

artifact_dir="/opt/artifacts"

# Create necessary directories
mkdir -p ${artifact_dir} ${artifact_dir}/images ${artifact_dir}/git ${artifact_dir}/rpms

# Get IronBank Credentials

while getopts b:k:u:p: flag
do
    case "${flag}" in
        b) bigbang_version=${OPTARG};;
        k) k3s_version=${OPTARG};;
        u) registry1_user=${OPTARG};;
        p) registry1_pass=${OPTARG};;
    esac
done

if [[ -z "$bigbang_version" ]] ; then
  echo "You must specify the Big Bang version  with the -b flag (i.e. 1.15.2)"
  exit 1
fi

if [[ -z "$k3s_version" ]] ; then
  echo "You must specify the k3s version with the -b flag (i.e. v1.21.4+k3s1)"
  exit 1
fi

if [[ -z "$registry1_user" ]] ; then
  echo "You must specify the registry1 (ironbank) username with the -u flag (i.e. First_Last)"
  exit 1
fi

# Download k3s artifacts

grabK3S () {

# download k3s binary
curl -L https://github.com/k3s-io/k3s/releases/download/${k3s_version}/k3s --output ${artifact_dir}/k3s
chmod +x ${artifact_dir}/k3s

# download k3s airgap images
curl -L https://github.com/k3s-io/k3s/releases/download/${k3s_version}/k3s-airgap-images-${architecture}.tar --output ${artifact_dir}/k3s-airgap-images-amd64.tar

# download k3s rpms
curl -L https://rpm.rancher.io/k3s/latest/common/centos/8/noarch/k3s-selinux-0.2-1.el7_8.noarch.rpm --output ${artifact_dir}/rpms/k3s-selinux.noarch.rpm

# Download k3s installation script
curl -L https://get.k3s.io --output ${artifact_dir}/k3s-install.sh
chmod +x ${artifact_dir}/k3s-install.sh

# Run k3s for cri utilities 

curl -sfL https://get.k3s.io | sh -

}

# Download IronBank images

grabImages () {

until [ -f /usr/local/bin/ctr ]
do
     sleep 5
done

while read imageUrl; do
 /usr/local/bin/ctr image pull -u $registry1_user:$registry1_pass ${imageUrl} && /usr/local/bin/ctr image export ${artifact_dir}/images/$(echo ${imageUrl} |sed 's/\//-/g' |sed 's/\:/-/g').tar ${imageUrl}
done <images.txt
}

# Get Big Bang artifacts

grabBB () {

# Download bigbang repository

curl -L https://repo1.dso.mil/platform-one/big\-bang/bigbang/\-/archive/${bigbang_version}/bigbang\-${bigbang_version}.tar.gz | tar -xz -C ${artifact_dir}/ && tar -czvf ${artifact_dir}/bigbang-${bigbang_version}.tgz -C ${artifact_dir}/bigbang-${bigbang_version}/chart/ .

# Download Big Bang repos
curl -L https://umbrella-bigbang-releases.s3-us-gov-west-1.amazonaws.com/umbrella/${bigbang_version}/repositories.tar.gz | tar -xz -C ${artifact_dir}/git/

# Istio version workaround
#git --git-dir=${artifact_dir}/git/repos/istio-controlplane/.git reset HEAD --hard
#git --git-dir=${artifact_dir}/git/repos/istio-controlplane/.git checkout tags/1.9.8-bb.0

# copy flux manifest

/usr/local/bin/kubectl kustomize /opt/artifacts/bigbang-${bigbang_version}/base/flux -o ${artifact_dir}/flux.yaml

# get local git repo image

/usr/local/bin/ctr image pull docker.io/bgulla/git-http-backend:latest && /usr/local/bin/ctr image export ${artifact_dir}/images/git-http-backend.tar docker.io/bgulla/git-http-backend:latest

}

# Copy git-http-backend manifests to artifact dir
cp -rf artifacts/git-http-backend ${artifact_dir}/git-http-backend

osDeps () {

# install utilities needed by download script

yum install git yum-utils -y

# download pre-req RPMs

mkdir -p ${artifact_dir}/rpms
yumdownloader --resolve --destdir=${artifact_dir}/rpms/ container-selinux selinux-policy-base iscsi-initiator-utils

# copy deployment scripts
cp -rf destination-scripts ${artifact_dir}/deploy

}

grabK3S
grabImages
grabBB
osDeps

# package it all up nice and tidy
tar -czvf ~/artifacts-airgap.tar.gz ${artifact_dir}
