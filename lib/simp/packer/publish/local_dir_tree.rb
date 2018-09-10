require 'fileutils'
require 'json'

module Simp
  module Packer
    module Publish
      # Create and manage a local (atlus-like) directory tree for vagrant boxes
      class LocalDirTree
        include FileUtils

        attr_accessor :verbose
        def initialize(base_dir)
          @base_dir = base_dir
          @verbose  = false
        end

        # Install vagrant box into a local directory tree, generate version metadata
        #
        #   This places a vagrant .box file into a directory tree that is
        #   structured more-or-less like the VagrantCloud box API.
        #
        #   * The .box file is placed in the versioned directory.
        #   * metadata .json files are placed in the relevant directories.
        #   * If the directory tree does not exist, it will be created.
        #   * To overwite existing files/links with `:hardlink`, set the
        #     environment variable `SIMP_PACKER_publish_force=yes`.
        #
        # @param [Hash] box_data The Vagrant Cloud
        # @param [Symbol] action  :hardlink, :copy, or :move .box (Default: :hardlink)
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
            migrate = lambda do |src, dst, verbose = true|
              FileUtils.ln src, dst, verbose: verbose, force: ENV['SIMP_PACKER_publish_force'] == 'yes'
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
