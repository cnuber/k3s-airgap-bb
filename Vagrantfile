Vagrant.configure("2") do |config|
  config.vm.box = "generic/centos7"
  config.vm.synced_folder ".", "/vagrant"
  config.vm.provision "shell",
    inline: "/bin/sh /vagrant/download-scripts/airgap-artifact-download.sh",
    privileged: true
end
