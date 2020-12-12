# frozen_string_literal: true

require 'simp/packer/config/prepper'
require 'fileutils'
require 'rake'
require 'rake/file_utils'

module Simp
  module Packer
    module Build
      # Run the simp-packer build
      #
      #   The test directory should contain 3 files:
      #
      #     vars.json:  json file created when the iso is made.  This points
      #                 to the iso file the output directory and the checksum
      #                 for the iso.  Make sure these are all set correctly.
      #     packer.yaml  YAML containing the settings for the rest of the script
      #                  and will be used to configure the simp.json
      #                  file.  Examples are given in the sample directory.
      #     simp_conf.yaml:  YAML generated by simp_cli.  My script will over
      #                  write things in simp_conf.yaml from settings
      #                  in the packer.yaml file.  See the samples/README for
      #                  more information.
      #
      #   TMPDIR:   When running this script make sure you set the linux
      #             environment variable TMPDIR to point to a directory
      #             that is writeable and has enough space for packer to
      #             create the disk for the machine.
      #
      #
      class Runner
        include FileUtils

        attr_accessor :verbose

        # @param [String] test_dir  Directory where the test files exist
        # @param [String] base_dir  The simp-packer directory
        # @param [Boolean] verbose  be verbose?
        def initialize(
          test_dir = nil,
          base_dir = File.expand_path("#{__dir__}/../../../.."),
          verbose  = true
        )
          @test_dir    = test_dir || File.expand_path(Dir.pwd, 'simp-packer')
          @base_dir    = base_dir
          @verbose     = verbose
        end

        # Create test dir and copy in files
        def prep(vars_json, simp_conf_yaml, packer_yaml)
          mkdir_p @test_dir, verbose: @verbose
          cp vars_json, File.join(@test_dir, 'vars.json'), verbose: @verbose
          cp simp_conf_yaml, File.join(@test_dir, 'simp_conf.yaml'), verbose: @verbose
          cp packer_yaml, File.join(@test_dir, 'packer.yaml'), verbose: @verbose
        end

        # Raise a decriptive error if any build requirements are missing
        def fail_without_prereqs(packer_yaml, simp_conf_yaml, vars_json)
          raise "ERROR: Test dir not found at '#{@test_dir}'" unless File.directory?(@test_dir)

          if @verbose
            warn(
              '', "Contents of test_dir (#{@test_dir}):",
              Dir["#{@test_dir}/*"].map { |x| "  #{File.basename(x)}\n" }.join, ''
            )
          end
          # TODO: we shouldn't handle these files, we should accept data
          raise "ERROR: packer.yaml not found at '#{packer_yaml}'" unless File.file?(packer_yaml)
          raise "ERROR: simp.conf.yaml not found at '#{simp_conf_yaml}'" unless File.file?(simp_conf_yaml)
          raise "ERROR: vars.json not found at '#{vars_json}'" unless File.file?(vars_json)
        end

        # @param opts [Hash] optional
        # @option opts [String] :working_dir
        # @option opts [String] :vars_json
        # @option opts [String] :packer_yaml
        # @option opts [String] :simp_conf_yaml
        # @option opts [String] :dry_run
        def run(opts = {})
          date              = opts[:date_time]      || Time.now.strftime('%Y%m%d-%H%M%S')
          working_dir       = opts[:working_dir]    || File.join(@test_dir, "working.#{date}")
          opts[:log_file] ||= File.join(@test_dir, "#{date}.simp-packer.log")
          opts[:plog_file] || ENV['PACKER_LOGPATH'] || File.join(@test_dir, "#{date}.packer.log")
          opts[:tmp_dir] ||= nil
          opts[:dry_run] ||= ENV.fetch('SIMP_PACKER_dry_run', 'no') == 'yes'
          # The files are currently needed by Simp::Packer::Config::Prepper (the
          # old simp_config.rb).  They have to exist before this method is called.
          opts[:packer_yaml] ||= File.join(@test_dir, 'packer.yaml')
          opts[:simp_conf_yaml] ||= File.join(@test_dir, 'simp_conf.yaml')
          opts[:vars_json] ||= File.join(@test_dir, 'vars.json')
          opts[:extra_packer_args] ||= ENV['SIMP_PACKER_extra_args'] || ''

          fail_without_prereqs(opts[:packer_yaml], opts[:simp_conf_yaml], opts[:vars_json])

          # scaffold working directory
          rm_rf(working_dir, verbose: @verbose) if File.exist?(working_dir)
          mkdir_p working_dir, verbose: @verbose
          ['files', 'puppet', 'scripts'].each do |f|
            copy_entry(File.join(@base_dir, f), File.join(working_dir, f), verbose: @verbose)
          end

          # set up specific simp-packer configurations (formerly simp_config.rb)
          simp_packer_config = Simp::Packer::Config::Prepper.new(working_dir, @test_dir, @base_dir)
          simp_packer_config.verbose = @verbose
          simp_packer_config.run

          Dir.chdir working_dir do |_dir|
            puts "Logs will be written to #{opts[:log_file]}" if @verbose

            fix_cmd = <<~FIX_CMD
              set -e; set -o pipefail;
               #{opts[:tmp_dir] ? "TMP_DIR=#{opts[:tmp_dir]} " : ''}PACKER_LOG="#{ENV['PACKER_LOG'] || 1}" \
                 PACKER_LOG_PATH="#{opts[:plog_file]}.fix.log" \
                    packer fix "#{working_dir}/simp.json" > "#{working_dir}/simp.json.fixed"; mv "#{working_dir}/simp.json" "#{working_dir}/simp.json.old"; mv "#{working_dir}/simp.json.fixed" "#{working_dir}/simp.json"
            FIX_CMD
            if opts[:dry_run]
              puts cmd fix_cmd if @verbose
            else
              sh fix_cmd
            end

            cmd = <<-CMD.gsub(%r{ {10}}, '')
              set -e; set -o pipefail;
              #{opts[:tmp_dir] ? "TMP_DIR=#{opts[:tmp_dir]} " : ''}PACKER_LOG="#{ENV['PACKER_LOG'] || 1}" \
                PACKER_LOG_PATH="#{opts[:plog_file]}" \
                packer build -var-file="#{working_dir}/vars.json" #{opts[:extra_packer_args]} "#{working_dir}/simp.json" \
                |& tee "#{opts[:log_file]}"
            CMD

            if opts[:dry_run]
              puts cmd if @verbose
            else
              sh cmd
            end
          end
        end
      end
    end
  end
end
