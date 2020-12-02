#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'yaml'

class SettingsError < StandardError; end

# Check that fips, selinux, puppet are set up
class CheckSettings < TaskHelper

  # Verifies that the system hiera setting for FIPS and the actual
  # FIPS mode match the test setting.  The check for the system
  # hiera setting verifies that 'simp config' sets the hiera value
  # to match the current FIPS mode.
  def check_fips_mode
    expected_conf = @expected_conf['simp_options::fips']
    actual_conf = @actual_conf['simp_options::fips']

    if actual_conf == expected_conf
      # get the actual system setting of fips
      fips = IO.read('/proc/sys/crypto/fips_enabled').to_i
      fips_enabled = (fips == 1)

      if fips_enabled == expected_conf
        puts "The system fips setting '#{fips}' and configuration" \
             " setting '#{expected_conf}' agree."
      else
        err_msg = "System setting fips = #{fips} does not agree with" \
                  " configuration setting '#{expected_conf}'."
        raise SettingsError, err_msg
      end
    else
      err_msg = "Expected FIPs configuration is '#{expected_conf}' but" \
                " the actual configuration has '#{actual_conf}'."
      raise SettingsError, err_msg
    end
  end

  # Verifies that puppet is operating with the SIMP default for the
  # masterport and the test configured ca_port.
  def check_puppet_ports
    # Currently, the default values of pupmod::master::masterport is
    # not modified by any tests.  So, the masterport should be 8410,
    # instead of the default of 8150.
    # TODO read configured value from the hieradata
    expected = 8140
    actual = `puppet config print masterport`.to_i

    if actual == expected
      puts "The puppet masterport setting matches the configured value '#{expected}'."
    else
      err_msg = "Puppet master port should be '#{expected}', but is set to #{actual}."
      raise SettingsError, err_msg
    end

    # For the test configuration, the puppet master is also the CA server.
    expected = @expected_conf['simp_options::puppet::ca_port']
    actual = `puppet config print ca_port`.to_i

    if actual == expected
      puts "The puppet ca_port setting matches the configured value '#{expected}'."
    else
      err_msg =  "The puppet ca_port setting should be '#{expected}'," \
                 " but is '#{actual}'."
      raise SettingsError, err_msg
    end
  end

  # Verifies that the puppetserver and puppetdb services are running.
  def check_puppet_services_running
    check_service_status('puppetserver', 'running')
    check_service_status('puppetdb', 'running')
  end

  # Verifies that the system is set to the SIMP default for selinux mode.
  def check_selinux
    # Currently, the default values of simp_options::selinux or
    # selinux::ensure are not modified by any tests.  So, selinux
    # should be 'Enforcing'.
    # TODO read configured value from the hieradata
    expected = 'Enforcing'
    actual = `/usr/sbin/getenforce`.strip
    if actual == expected
      puts "The system selinux setting agrees with the configured value '#{expected}'."
    else
      err_msg = "Selinux should be '#{expected}', but is set to '#{actual}'."
      raise SettingsError, err_msg
    end
  end

  # Verifies that the named service has the expected status.
  # The expected status should be 'running' or 'stopped', which
  # are the 'ensure' values returned by
  #   puppet resource service <service name>
  def check_service_status(service, expected_status = 'running')
    result = `puppet resource service #{service}`
    match = result.match(%r{ensure\s+=> '(stopped|running)',})
    if match
      if match[1] == expected_status
        puts "Service '#{service}' status matches expected value '#{expected_status}'."
      else
        err_msg = "Service '#{service}' status should be '#{expected_status}'," \
                  " but is '#{match[1]}'."
        raise SettingsError, err_msg
      end
    else
      # even if the service doesn't exist, the puppet CLI will return
      #  service { '<service name>':
      #    ensure => 'stopped',
      #    enable => 'false'
      #   }
      # So we must really be broken, if the puppet CLI doesn't work!
      err_msg = "Unable to determine #{service} status using 'puppet resource service':"
      err_msg += "\n#{result}"
      raise SettingsError, err_msg
    end
  end

  def execute_checks
    check_fips_mode
    check_selinux
    check_puppet_services_running
    check_puppet_ports
  end

  def task(name: nil, **kwargs)
    @expected_conf_file = kwargs[:simp_config_file]
    @actual_conf_file   = kwargs[:simp_config_settings_file]
    File.exist?(@expected_conf_file) ? $stderr.puts("File exists: '#{@expected_conf_file}'") : raise( "File not found: '#{@expected_conf_file}'")
    File.exist?(@actual_conf_file) ? $stderr.puts("File exists: '#{@actual_conf_file}'") : raise( "File not found: '#{@actual_conf_file}'")
    @expected_conf = YAML.load_file(@expected_conf_file)
    @actual_conf = YAML.load_file(@actual_conf_file)
    run_checks
  end

  # Load the configuration specified by command line arguments
  # and then execute the checks
  def run_checks
    begin
      execute_checks
      result = 0
    rescue SettingsError => e
      # check failure
      if @never_fail
        puts "Settings error ignored: #{e.message}"
        result = 0
      else
        warn "ERROR: #{e.message}"
        result = 1
      end
    rescue ArgumentError, Psych::SyntaxError => e
      # YAML parsing error
      warn "ERROR: #{e.message}"
      result = 1
    rescue StandardError => e
      # everything else
      warn "FAILURE: #{e.message}"
      e.backtrace.first(10).each { |l| warn l }
      result = 1
    end

    result
  end
end

CheckSettings.run if $PROGRAM_NAME == __FILE__
