plan simp_packer::do(
 TargetSpec $targets          = get_targets('localhost'),
 Stdlib::Absolutepath $pwd     = system::env('PWD'),
 String[1]  $fips             = 'fips=1',
 Boolean    $disk_encrypt     = true,
 String[1]  $firmware         = 'bios',
 String[1]  $vagrant_password = 'vagrant',
 String[1]  $umask            = '0027',
 Stdlib::Absolutepath $simp_conf_file = "${pwd}/testfiles/simp_conf.yaml",
){
  ### # NOTE we may no longer need these uploads now that we're using Bolt
  ### ['files','scripts','puppet'].each |$dir| {
  ###   upload_file("${pwd}/${dir}", '/var/local/simp/', $targets, { '_catch_errors'             => true })
  ### }
  ### run_command( "find /var/local/simp/scripts -type f -name '*.sh' -print -exec chmod +x {} \\;", $targets )

  run_task( "simp_packer::check_settings_at_boot",
    $targets,
    {
      'fips'         => $fips,
      'disk_encrypt' => $disk_encrypt,
      'firmware'     => $firmware,
    }
  )
  run_task( 'simp_packer::check_partitions', $targets )

  apply( $targets, {'_description' => 'Set up vagrant user and root umask' }){
    class{ 'simp_setup::vagrant_user': password => $vagrant_password }
    class{ 'simp_setup::root_umask': umask => $umask }
    include 'simp_setup::puppet_environment_dirs'
  }

  # TODO: create simp_conf.yaml
  #   - pull data from hiera
  #   - edit with this run's settings (possibly from Hiera)
  #   - probably create it from hiera data
  upload_file("${simp_conf_file}", '/var/local/simp/simp_conf.yaml', $targets, { '_catch_errors' => true })
  $force_config='--force-config'
  run_command(
    "echo \"umask: $(umask)\"; simp config -a /var/local/simp/simp_conf.yaml ${force_config}",
    $targets,
    'Run simp config',
  )

  apply( $targets, {'_description' => 'Set up Hiera defaults' }){
    include 'simp_setup::hiera'
  }

  run_command(
    '/opt/puppetlabs/bin/puppet resource service NetworkManager ensure=stopped enable=false',
    $targets,
    'Disable NetworkManager',
  )

  debug::break()
  run_task( 'simp_packer::run_simp_bootstrap', $targets )

}
