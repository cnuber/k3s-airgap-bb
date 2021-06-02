# k3s airgap deployment with p1 big-bang option

## Getting Started

### Pre-requisites
* a CentOS 7 system with internet access to download artifacts that matches your destination system version.
* a copy of this repository on the internet-connected system

### Downloading the necessary artifacts

On the internet-connected system:
```
cd k3s-airgap-bb
# For an air-gapped k3s with no Big Bang or Iron Bank artifacts
download-scripts/airgap-artifact-download.sh
# For an airgapped k3s with Big Bang and Iron Bank artifacts
download-scripts/airgap-artifact-download.sh -b true -i true -u Your_IronBank_Username -p YourIronBankPassword # you can retrieve these credentials from https://registry1.dso.mil under your user profile (username and cli_token for the password)
```

This will create an archive with all of the items needed in your user's home directory, ie /root/artifacts-airgap.tar.gz

You then will need to transfer this to the destination system somehow (scp, rsync, optical disc, flash drive, etc)

### Extracting the archive on the destination system

Once you've transferred the artifacts-airgap.tar.gz file to the destination system, you'll need to extract it with the following command:

Run the extract_artifacts.sh script
```
tar -xzvf artifacts-airgap.tar.gz -C /
```

### Deploying an airgapped k3s installation with the necessary OS dependencies

For a server node:

Replace interfacename in the command below with your actual network interface name (ie eth0, ens33, etc..)
```
cd /opt/artifacts/deployment
destination-scripts/deploy_k3s.sh -i interfacename -n server
```

For an agent node:
In addition to the interface name and node type, you will also need to pass the k3s server url and the k3s join token as follows:
```
cd /opt/artifacts/deployment
destination-scripts/deploy_k3s.sh -i interfacename -n agent -s https://your.k3s.server.ip:6443 -t yourk3sservernodetoken
```

Verify the installation was successful:

```
watch kubectl get pods -A # this should return running pods after a couple of minutes at most
```
### Deploying Big Bang and the necessary IronBank images in an airgap
```
cd /opt/artifacts/deployment
destination-scripts/deploy_bigbang.sh
```
