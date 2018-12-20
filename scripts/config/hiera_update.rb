#!/usr/bin/env ruby
require 'yaml'
require 'fileutils'
require 'socket'

@hieradir = '/etc/puppetlabs/code/environments/simp/data'
simp_version = File.read('/etc/simp/simp.version').strip
simp_version.gsub!(%r{\A(\d+(?:(?:\.\d+)?\.\d+)?).*}, '\1')
if Gem::Version.new(simp_version) < Gem::Version.new('6.3.0')
  @hieradir = '/etc/puppetlabs/code/environments/simp/hieradata'
end

@time = Time.new

# Update the puppetservers hiera file to add new classes for
# kickstart server and install extra modules require by
#  other configuration modules
#
#  NOTE: The site classes added here are created by the simpsetup manifest
def update_hiera_data(item)
  file = "#{@hieradir}/#{item}.yaml"
  data = {}
  if File.exist?(file)
    backup = "#{file}.#{@time.strftime('%Y%m%d%H%M%S')}"
    FileUtils.cp(file, backup)
    data = YAML.load_file(file.to_s)
  end

  data = yield data

  File.open(file.to_s, 'w') do |h|
    h.write data.to_yaml
    h.close
  end
  FileUtils.chmod 0o0640, file
  FileUtils.chown 'root', 'puppet', file
end

# Add classes to the puppetserver
hostname = Socket.gethostbyname(Socket.gethostname).first
update_hiera_data("hosts/#{hostname}") do |data|
  data.merge(
    'classes' => (data['classes'] + [
      'simp::server::kickstart',
      'site::tftpboot',
      'site::wsmodules'
    ]).uniq
  )
end

# The puppet agent cron should *never* run during simp integration tests
update_hiera_data('default') do |data|
  data.merge YAML.load <<-YAML.gsub(%r{^ {4}}, '')
    ---
    pupmod::agent::cron::weekday: '0'
    pupmod::agent::cron::hour: '0'
    pupmod::agent::cron::minute: '0'
    pupmod::agent::cron::month: '2'
    pupmod::agent::cron::monthday: '31'
    pupmod::agent::cron:break_puppet_lock: false
    pupmod::agent::cron:max_disable_time: 999999

    # tlog breaks vagrant at the moment
    #
    #   See: https://simp-project.atlassian.net/browse/SIMP-5892
    #
    simp::admin::force_logged_shell: false
  YAML
end

# Create hiera file for the workstations host group.
update_hiera_data('hostgroups/workstations') do |_data|
  YAML.load <<-YAML.gsub(%r{^ {4}}, '')
    ---
    classes:
      - site::workstations
    simp::runlevel: graphical
  YAML
end
