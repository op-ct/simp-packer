# Copy some site manifests to the the site module
#
# simp-packer/simp-testing contains a script that puts these classes into
# hiera.
#
#  @param  $env            The environment containing the site module directory
#  @param  $manifests_dir  Path to the site module's manifests directory
#
class simpsetup::site_module(
  String               $env      = $simpsetup::environment,
  Stdlib::Absolutepath $manifests_dir  = "/etc/puppetlabs/code/environments/${env}/site/site/manifests"
){
  assert_private()

  $file_perms = {
    'ensure'  => 'file',
    'owner'   => 'root',
    'group'   => 'puppet',
    'mode'    => '0640',
  }

  file {
    default: * => $file_perms;
    "${manifests_dir}/tftpboot.pp":
      content => template('simpsetup/site_module/manifests/tftpboot.pp.erb'),
    ;
    "${manifests_dir}/workstations.pp":
      content => template('simpsetup/site_module/manifests/workstations.pp.erb'),
    ;
    "${manifests_dir}/wsmodules.pp":
      content => template('simpsetup/site_module/manifests/wsmodules.pp.erb'),
    ;
  }
}
