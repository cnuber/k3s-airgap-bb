Vagrant.configure("2") do |config|
  config.vm.box = "generic/centos8"
  config.vm.synced_folder ".", "/vagrant"
if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false  
end
end
