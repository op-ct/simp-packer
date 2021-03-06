# frozen_string_literal: true

require 'fileutils'
require 'json'

module Simp
  module Packer
    module Publish
      # Create and manage a local (atlus-like) directory tree for vagrant boxes
      #
      #   ### Directory structure
      #
      #   The local directory tree is structured more-or-less like the
      #   VagrantCloud box API:
      #
      #   ```
      #   VAGRANT_TREE_ROOT/
      #   +-- simpci/                            # <-- Vagrant "org" name
      #       +-- boxes/                         #
      #           +-- box-name.json              # <-- points to latest version
      #           +-- box-name/                  # <-- contains box data
      #           |   +-- versions/              #
      #           |       +-- 20180918.123456/   # <-- version number/
      #           |       |   +-- virtualbox.box # <-- 1 version per hypervisor
      #           |       |   +-- virtualbox.json
      #           |       [...]
      #           [...]
      #   ```
      #
      #   ### Notes
      #
      #   * A .box file is placed in its versioned directory
      #   * Box metadata .json files are placed in the relevant directories:
      #     - One pointing to the latest version
      #   * If the directory tree does not exist, it will be created.
      #   * To overwite existing files/links with `:hardlink`, set the
      #       environment variable `SIMP_PACKER_publish_force=yes`.
      #
      # @see https://www.vagrantup.com/docs/vagrant-cloud/api.html#read-a-box
      #   Vagrant Cloud API documentation for "Read a box"
      class LocalDirTree
        include FileUtils

        attr_accessor :verbose

        def initialize(base_dir)
          @base_dir = base_dir
          @verbose  = ((ENV['SIMP_PACKER_verbose'] || 'no') == 'yes')
        end

        # @return [Array] list of boxes
        def list
          data = { orgs: {}, invalid_orgs: [], base_path: @base_dir }
          Dir["#{@base_dir}/*"].each do |org_path|
            org = File.basename(org_path)
            unless File.directory?(File.join(org_path, 'boxes'))
              data[:invalid_orgs] << org
              next
            end
            data[:orgs][org] = {}
            data[:orgs][org][:boxes] = {}
            Dir.chdir File.join(org_path, 'boxes') do |_dir|
              data[:orgs][org][:toplevel_json_files] = Dir['*.json']
              Dir['*/versions/*'].each do |version_path|
                box = File.dirname(File.dirname(version_path))
                version = File.basename(version_path)
                data[:orgs][org][:boxes][box] ||= { versions: [] }
                data[:orgs][org][:boxes][box][:versions] << version
              end
            end
          end
          data
        end

        def list_str
          lines = []
          list[:orgs].map do |org, v|
            lines << "#{org}/"
            v[:boxes].map do |box, y|
              lines << "  - #{box}:"
              lines << y[:versions].map { |version| "    - #{version}" }.sort.join("\n")
            end
          end
          lines.join("\n")
        end

        # Install vagrant box into a local directory tree, generate version metadata
        #
        # @param [String] box_path path to the `.box` file
        # @param [Symbol] link  Action taken to place `.box` file.  Valid
        #   symbols are `:hardlink`, `:copy`, or `:move` (Default: :hardlink)
        def self.publish(vars_json_path, box_path, vagrant_box_dir, link = :hardlink)
          converter = Simp::Packer::VarsJsonToVagrantBoxJson.new(vars_json_path)
          box_data  = converter.vagrant_box_json(box_path)
          dir_tree  = Simp::Packer::Publish::LocalDirTree.new(vagrant_box_dir)
          dir_tree.publish(box_data, link) # TODO: env var for copy/link action?
        end

        # Install vagrant box into a local directory tree, generate version metadata
        #
        # @param [Hash] box_data The Vagrant Cloud data structure,
        #   as generated by {Simp::Packer::VarsJsonToVagrantBoxJson#vagrant_box_json}
        # @param [Symbol] action Action taken to place `.box` file.  Valid
        #   symbols are `:hardlink`, `:copy`, or `:move` (Default: :hardlink)
        def publish(box_data, action = :hardlink)
          username = box_data['username']
          name     = box_data['name']
          version  = box_data['versions'].first['version']
          provider = box_data['versions'].first['providers'].first['name']
          box_file_src = box_data['versions'].first['providers'].first['url']
          box_file_dest = File.expand_path(File.join(@base_dir, username, 'boxes', name, 'versions', version, "#{provider}.box"))
          box_json_dest = File.expand_path(File.join(@base_dir, username, 'boxes', name, 'versions', version, "#{provider}.json"))
          box_dir = File.dirname box_file_dest
          boxname_json_dest = File.expand_path(File.join(@base_dir, username, 'boxes', "#{name}.json"))

          # Below this line: local file stuff
          mkdir_p box_dir, verbose: @verbose
          box_data['versions'].first['providers'].first['url'] = "file://#{box_file_dest}"
          case action
          when :copy
            migrate = ->(src, dst, verbose = true) { FileUtils.cp src, dst, verbose: verbose }
          when :move
            migrate = ->(src, dst, verbose = true) { FileUtils.mv src, dst, verbose: verbose }
          when :hardlink
            migrate = ->(src, dst, verbose = true) do
              FileUtils.ln src, dst, verbose: verbose, force: (ENV['SIMP_PACKER_publish_force'] == 'yes')
            end
          else
            raise 'ERROR: `action` must be :copy, :move, or :hardlink'
          end
          src_path = box_file_src.sub(%r{^file://}, '')
          puts "\nPlacing (action: #{action}) box file at path:\n  #{box_file_dest}"
          migrate.call src_path, box_file_dest

          # copy Vagrantfile erb templates (use with `vagrant init BOX --template VAGRANT_ERB_FILE`)
          Dir[File.expand_path('../Vagrantfile*.erb', src_path)].each do |v|
            migrate.call v, File.dirname(box_file_dest), @verbose
          end
          write_box_json(box_json_dest, box_data)

          # this is the latest top-level box
          # TODO: This should eventually scan/collect/prune all box_json_dest
          #       files for this boxname and aggregate them here.
          write_box_json(boxname_json_dest, box_data)
          puts_vagrant_init_message(boxname_json_dest, box_data)
        end

        def write_box_json(box_json_path, box_metadata)
          # write box metadata file
          puts "\nWriting Vagrant box metadata to:"
          puts "\n   #{box_json_path}\n"
          File.open(box_json_path, 'w') do |f|
            f.puts JSON.pretty_generate(box_metadata)
          end
        end

        # construct a relevant usage message for the new box
        def puts_vagrant_init_message(box_json_path, box_data)
          require 'pathname'
          pn = Pathname.new(box_json_path)
          vf_json_url = if pn.absolute?
                          "file://#{pn.realpath}"
                        elsif pn.realpath.relative_path_from(Pathname.getwd).to_s =~ %r{^\..}
                          "file://#{pn.realpath}"
                        else
                          "file://./#{pn}"
                        end
          box_path = box_data['versions'].first['providers'].first['url'].sub(%r{^file://}, '')
          vagrant_template_path = File.join(File.dirname(box_path), 'Vagrantfile.erb')
          extra = File.file?(vagrant_template_path) ? "--template '#{vagrant_template_path}'" : ''
          puts '', 'You can use the new box by running:', ''
          puts '  ' + "vagrant box add #{vf_json_url}", ''
          puts 'or:', ''
          puts '  ' + "vagrant init #{box_data['tag']} #{vf_json_url} #{extra}".strip, ''
        end
      end
    end
  end
end
