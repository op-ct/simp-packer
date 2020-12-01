# Runs initial tests, setup, `simp config` and `simp bootstrap`
plan simp_packer::initial_tests_and_setup(
 TargetSpec $targets          = get_targets('localhost'),
 Stdlib::Absolutepath $pwd     = system::env('PWD'),
 String[1]  $fips             = 'fips=1',
 Boolean    $disk_encrypt     = true,
 String[1]  $firmware         = 'bios',
 String[1]  $vagrant_password = 'vagrant',
 String[1]  $umask            = '0027',
 Stdlib::Absolutepath $local_simp_conf_file = "${pwd}/testfiles/simp_conf.yaml",
 Stdlib::Absolutepath $pup_env_dir = '/etc/puppetlabs/code/environments/production',
){
  run_task( "simp_packer::check_settings_at_boot", $targets, {
    'fips'         => $fips,
    'disk_encrypt' => $disk_encrypt,
    'firmware'     => $firmware,
  })
  run_task( 'simp_packer::check_partitions', $targets )

  apply( $targets, {'_description' => 'Set up vagrant user and root umask' }){
    class{ 'simp_setup::vagrant_user': password => $vagrant_password }
    class{ 'simp_setup::root_umask': umask => $umask }
  }

  # TODO: create simp_conf.yaml
  #   - pull data from hiera
  #   - edit with this run's settings (possibly from Hiera)
  #   - probably create it from hiera data
  upload_file("${local_simp_conf_file}", '/var/local/simp/simp_conf.yaml', $targets, { '_catch_errors' => true })
  run_command(
    "umask $umask; echo \"umask: $(umask)\"; simp config -a /var/local/simp/simp_conf.yaml",
    $targets,
    'Run simp config',
  )

  upload_file("${pwd}/puppet/modules/simpsetup", "${pup_env_dir}/site/", $targets, { '_catch_errors' => true })
  apply( $targets, {'_description' => 'Set up Hiera defaults' }){
    class{ 'simp_setup::vagrant_user': password => $vagrant_password }
    class{ 'simp_setup::root_umask': umask => $umask }
    include 'simp_setup::puppet_environment_dirs'
  }

  run_command(
    '/opt/puppetlabs/bin/puppet resource service NetworkManager ensure=stopped enable=false',
    $targets,
    'Disable NetworkManager',
  )

  run_task( 'simp_packer::run_simp_bootstrap', $targets )
}
