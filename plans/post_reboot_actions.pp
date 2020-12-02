# This is the structure of a simple plan. To learn more about writing
# Puppet plans, see the documentation: http://pup.pt/bolt-puppet-plans

# The summary sets the description of the plan that will appear
# in 'bolt plan show' output. Bolt uses puppet-strings to parse the
# summary and parameters from the plan.
# @summary A plan created with bolt plan new.
# @param targets The targets to run on.
plan simp_packer::post_reboot_actions (
  TargetSpec $targets          = get_targets('localhost'),
  Stdlib::Absolutepath $pwd    = system::env('PWD'),
  String[1]  $fips             = 'fips=1',
  Boolean    $disk_encrypt     = true,
  String[1]  $firmware         = 'bios',
  String[1]  $vagrant_password = 'vagrant',
  String[1]  $umask            = '0027',
  Stdlib::Absolutepath $local_simp_conf_file = "${pwd}/testfiles/simp_conf.yaml",
  Stdlib::Absolutepath $pup_env_dir = '/etc/puppetlabs/code/environments/production',
) {
  $puppetserver = get_target($targets)
  $transport_defaults = { 'user' => 'vagrant', 'run-as' => 'root', 'tmpdir' => '/home/vagrant' }
  $puppetserver.set_config('ssh', $puppetserver.config['ssh'].merge($transport_defaults))

  ### TODO re-enable
  ### run_command( '/opt/puppetlabs/bin/puppet agent -t || :', $puppetserver, 'Run puppet agent -t (1/2)')
  ### run_command( '/opt/puppetlabs/bin/puppet agent -t || :', $puppetserver, 'Run puppet agent -t (2/2)')

  run_task( "simp_packer::check_post_reboot_settings", $puppetserver, {
    'simp_config_file'          => '/var/local/simp/simp_conf.yaml',
    'simp_config_settings_file' => "${pup_env_dir}/data/simp_config_settings.yaml",
  })
    debug::break()

  ### TODO
  ###   {
  ###     "type": "shell",
  ###     "remote_path": "/var/local/simp/scripts/inline-run-simpsetup.sh",
  ###     "inline": ["sudo /var/local/simp/scripts/config/simpsetup.sh"]
  ###   },
  ###   {
  ###     "type": "shell",
  ###     "environment_vars" : [
  ###       "SIMP_PACKER_environment={{user `simpenvironment`}}"
  ###     ],
  ###     "remote_path": "/var/local/simp/scripts/inline-run-sitepp_edit-rb.sh",
  ###     "inline": ["sudo {{user `ruby_path`}} /var/local/simp/scripts/config/sitepp_edit.rb"]
  ###   },
  ###   {
  ###     "type": "shell",
  ###     "environment_vars" : [
  ###       "SIMP_PACKER_environment={{user `simpenvironment`}}"
  ###     ],
  ###     "remote_path": "/var/local/simp/scripts/inline-run-hiera_update-rb.sh",
  ###     "inline": ["sudo {{user `ruby_path`}} /var/local/simp/scripts/config/hiera_update.rb"]
  ###   },
  ###   {
  ###     "type": "puppet-server",
  ###     "ignore_exit_codes": true,
  ###     "extra_arguments": "--test",
  ###     "puppet_bin_dir": "/opt/puppetlabs/bin"
  ###   },
  ###   {
  ###     "type": "puppet-server",
  ###     "extra_arguments": "--test",
  ###     "puppet_bin_dir": "/opt/puppetlabs/bin"
  ###   },
  ###   {
  ###     "type": "shell",
  ###     "remote_path": "/var/local/simp/inline-bashrc-extras.sh",
  ###     "execute_command": "sudo chmod +x {{.Path}}; {{.Vars}} sudo bash '{{.Path}}'",
  ###     "inline" : [
  ###       "if [ -f /var/local/simp/root/.bashrc-extras ]; then",
  ###         "cat /var/local/simp/root/.bashrc-extras >> /root/.bashrc",
  ###       "fi"
  ###     ]
  ###   },

  ###   {
  ###     "type": "shell",
  ###     "remote_path": "/var/local/simp/inline-simp-done.sh",
  ###     "execute_command": "chmod +x {{.Path}}; {{.Vars}} sh '{{.Path}}'",
  ###     "expect_disconnect": true,
  ###     "skip_clean": true,
  ###     "inline" : [
  ###        "echo 'done'"
  ###      ]
  ###  }
  return $command_result
}
