# frozen_string_literal: true

module Simp
  module Tests
    # Puppet testing helpers
    module Puppet
      # Pass through environment variables that users/CI should be able to influence
      def filtered_env_vars
        (
          ENV.to_h.select do |k, _v|
            k =~ %r{^SIMP_|^BEAKER_|^PUPPET_|^FACTER_|^DEBUG|^VERBOSE|^FLAGS$}
          end
        )
      end

      def run_rake_tasks(cmds)
        #  Bundler 2.1+ = :with_unbundled_env, old Bundler = :with_clean_env
        clean_env_method = Bundler.respond_to?(:with_unbundled_env) ? :with_unbundled_env : :with_clean_env
        ::Bundler.send(clean_env_method) do
          cmds.each do |cmd|
            line = cmd.to_s
            puts "\n\n==== EXECUTING: #{line}\n"
            exit 1 unless system(filtered_env_vars, line)
          end
        end
      end

      # Try fetching from local resources before using remote resources
      def careful_bundle_install_cmd
        bundle = 'bundle install --no-binstubs'
        %[bundle check || rm -f Gemfile.lock \
          && (#{bundle} --local || #{bundle} || bundle pristine || #{bundle}) \
          || { echo "bundler couldn't find everything"; exit 88 ; }]
      end

      def run_puppet_rake_tests
        run_rake_tasks [
          careful_bundle_install_cmd,
          'bundle exec rake validate',
          'bundle exec rake lint',
          'bundle exec rake metadata_lint',
          'bundle exec rake test',
        ]
      end
    end
  end
end
