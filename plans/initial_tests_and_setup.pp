# Runs initial tests, setup, `simp config` and `simp bootstrap`
plan simp_packer::initial_tests_and_setup(
  TargetSpec $targets          = get_targets('localhost'),
  Stdlib::Absolutepath $pwd    = system::env('PWD'),
  String[1]  $fips             = 'fips=1',
  Boolean    $disk_encrypt     = true,
  String[1]  $firmware         = 'bios',
  String[1]  $vagrant_password = 'vagrant',
  String[1]  $umask            = '0027',
  Stdlib::Absolutepath $local_simp_conf_file = "${pwd}/testfiles/simp_conf.yaml",
  Stdlib::Absolutepath $pup_env_dir = '/etc/puppetlabs/code/environments/production',
){
  $puppetserver = get_target($targets)
  $transport_defaults = { 'user' => 'root', 'tmpdir' => '/var/local/simp' }
  $puppetserver.set_config('ssh', $puppetserver.config['ssh'].merge($transport_defaults))

  out::message( "\n====== Testing initial settings after ISO installation\n")
  run_task( "simp_packer::check_settings_at_boot", $puppetserver, {
    'fips'          => $fips,
    'disk_encrypt'  => $disk_encrypt,
    'firmware'      => $firmware,
  })
  run_task( 'simp_packer::check_partitions', $puppetserver )


  # TODO : generate simp_conf.yaml
  #   - pull data from hiera
  #   - edit with this run's settings (possibly from Hiera)
  #   - probably create it from hiera data
  apply( $puppetserver, {'_description' => 'Set up root umask' }){
    class{ 'simp_setup::root_umask': umask => $umask }
  }
  upload_file("${local_simp_conf_file}", '/var/local/simp/simp_conf.yaml', $puppetserver)
  run_command(
    "umask $umask; echo \"umask: $(umask)\"; simp config -a /var/local/simp/simp_conf.yaml",
    $puppetserver,
    'Run simp config',
  )

  apply( $puppetserver, {'_description' => 'Set up Hiera defaults' }){
    class{ 'simp_setup::vagrant_user': password => $vagrant_password }
    class{ 'simp_setup::root_umask': umask => $umask }
    include 'simp_setup::puppet_environment_dirs'
    include 'simp_setup::hiera'
  }
  upload_file("${pwd}/puppet/modules/simpsetup", "${pup_env_dir}/site/simpsetup", $puppetserver)
  run_command("/bin/chown --reference='${pup_env_dir}' -R '${pup_env_dir}'", $puppetserver )
  run_command("/bin/chcon --reference='${pup_env_dir}' -R '${pup_env_dir}'", $puppetserver )

  run_command(
    '/opt/puppetlabs/bin/puppet resource service NetworkManager ensure=stopped enable=false',
    $puppetserver,
    'Disable NetworkManager',
  )

  run_task( 'simp_packer::run_simp_bootstrap', $puppetserver )
}
