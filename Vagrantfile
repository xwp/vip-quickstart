# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

vagrant_dir = File.expand_path(File.dirname(__FILE__))

#Vagrant.require_version ">= 1.5.0"
if `vagrant --version` < 'Vagrant 1.5.0'
    abort('Your Vagrant is too old. Please install at least 1.5.0')
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = "precise32"
  config.vm.box_url = "http://files.vagrantup.com/precise32.box"
  config.vm.provider "vmware_fusion" do |v, override|
    override.vm.box = "precise64-vmware"
    override.vm.box_url = "http://files.vagrantup.com/precise64_vmware.box"
  end
  config.vm.hostname = 'vip.local'
  config.vm.network :private_network, ip: "10.86.73.80"

  # Use 1GB of memory in virtualbox
  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
  end

  # Use 1GB of memory in vmware_fusion
  config.vm.provider "vmware_fusion" do |v|
    v.memory = 1024
  end

  config.vm.synced_folder ".", "/srv"

  # Customfile - POSSIBLY UNSTABLE
  # Copied from VVV: https://github.com/Varying-Vagrant-Vagrants/VVV/blob/9ecf595fc873433bac0aaf745aaa8a495ed1ee5a/Vagrantfile#L140-L150
  #
  # Use this to insert your own (and possibly rewrite) Vagrant config lines. Helpful
  # for mapping additional drives. If a file 'Customfile' exists in the same directory
  # as this Vagrantfile, it will be evaluated as ruby inline as it loads.
  #
  # Note that if you find yourself using a Customfile for anything crazy or specifying
  # different provisioning, then you may want to consider a new Vagrantfile entirely.
  if File.exists?(File.join(vagrant_dir,'Customfile')) then
    eval(IO.read(File.join(vagrant_dir,'Customfile')), binding)
  end

  # Address a bug in an older version of Puppet
  # See http://stackoverflow.com/questions/10894661/augeas-support-on-my-vagrant-machine
  config.vm.provision :shell, :inline => "if ! dpkg -s puppet > /dev/null; then sudo apt-get update --quiet --yes && sudo apt-get install puppet --quiet --yes; fi"

  # Provision everything we need with Puppet
  config.vm.provision :puppet do |puppet|
    puppet.module_path = "puppet/modules"
    puppet.manifests_path = "puppet/manifests"
    puppet.manifest_file  = "init.pp"
    puppet.options = ['--templatedir', '/vagrant/puppet/files']
    puppet.facter = {
      "quickstart_domain" => 'vip.local',
    }
  end

end
