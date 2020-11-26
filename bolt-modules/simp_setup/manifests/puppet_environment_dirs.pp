#
class simp_setup::puppet_environment_dirs(
  Stdlib::Absolutepath $pupenvdir = '/etc/puppetlabs/code/environments',
  String[1]            $environment = 'production',
  Stdlib::Absolutepath $puppetsitemodpath = "${pupenvdir}/${environment}/site",
){
  $ppdir ='/etc/puppetlabs/code/environments/production'
  file{ [
    $puppetsitemodpath,
    "${puppetsitemodpath}/profile",
    "${puppetsitemodpath}/profile/manifests",
    "${puppetsitemodpath}/role",
    "${puppetsitemodpath}/role/manifests",
    "${puppetsitemodpath}/site",
    "${puppetsitemodpath}/site/manifests",
  ]:
    ensure => directory,
    owner  => 'puppet',
    group  => 'puppet',
    mode   => '0750',
  }
  ->
  file{ "${puppetsitemodpath}/site/manifests/vagrant.pp":
    owner  => 'puppet',
    group  => 'puppet',
    mode   => '0640',
    content => file("${module_name}/vagrant.pp"),
  }
}
