# @summary Finish setting up a SIMP server after bootstrap + rebooting
# @param targets The targets to run on.
plan simp_packer::post_reboot_actions (
  TargetSpec $targets,
  Stdlib::Absolutepath $pwd    = system::env('PWD'),
  Stdlib::Absolutepath $pup_env_dir = '/etc/puppetlabs/code/environments/production',
) {
  $puppetserver = get_target($targets)
  $transport_defaults = { 'user' => 'vagrant', 'run-as' => 'root', 'tmpdir' => '/home/vagrant' }
  $puppetserver.set_config('ssh', $puppetserver.config['ssh'].merge($transport_defaults))

  $disable_puppet_agent_cmd = '/opt/puppetlabs/bin/puppet agent --disable "Packer setup"'
  $enable_puppet_agent_cmd  = '/opt/puppetlabs/bin/puppet agent --enable'
  $run_puppet_agent_cmd     = '/opt/puppetlabs/bin/puppet agent -t'

  out::message( '=== simp_packer::post_reboot_actions' )
  run_command(
    $disable_puppet_agent_cmd, $puppetserver, 'Temporarily disable Puppet agent'
  )

  run_task( 'simp_packer::check_post_reboot_settings', $puppetserver, {
    'simp_config_file'          => '/var/local/simp/simp_conf.yaml',
    'simp_config_settings_file' => "${pup_env_dir}/data/simp_config_settings.yaml",
  })

  apply_prep($puppetserver)
  apply( $puppetserver ){
    include 'simpsetup' # FIXME : Exec[packer_addto_ldap] is not idempotent
    include 'simp_setup::site_pp'
    include 'simp_setup::bashrc_extras'
  }

  run_task(
    'simp_packer::setup_hiera_classifications',
    $puppetserver,
    'Add classifications to Hiera'
  )

  run_command(
     "${enable_puppet_agent_cmd}; ${run_puppet_agent_cmd} ||: ; ${disable_puppet_agent_cmd}",
     $puppetserver,
     'Run puppet agent -t (1/2) NOTE: this can take a while'
  )
  run_command(
    "${enable_puppet_agent_cmd}; ${run_puppet_agent_cmd}",
    $puppetserver,
    'Run puppet agent -t (2/2)'
  )
}
