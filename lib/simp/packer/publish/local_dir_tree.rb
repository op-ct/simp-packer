require 'fileutils'
require 'json'

module Simp
  module Vagrant
    module DirTree
      class Root
        def initialize(base_dir, opts={})
          @base_dir = base_dir
          @opts = opts.dup
          @data = { orgs: {}, invalid_orgs: [], base_path: @base_dir }
        end

        # Build tree based on box .json files
        def scan
          Dir["#{@base_dir}/*"].each do |org_path|
            org = File.basename(org_path)
            boxes_path = File.join(org_path, 'boxes')
            unless File.directory?(boxes_path)
              @data[:invalid_orgs] << org
              next
            end
            @data[:orgs][org] = {:boxes => Boxes.new(boxes_path, @opts)}
            h = @data[:orgs]['simpci'][:boxes].to_h
            validate!
          end
          self
        end

        # rebuild top-level box data (JSON files)
        # TODO: implement
        def rebuild
          raise 'not implemented'
        end

        def validate!
          @data[:orgs].each do |name,org|
            org[:boxes].validate!
          end
        end

        def to_h
          @data.select{|k,v| k != :orgs}.merge({
           :orgs => @data[:orgs].map do |name,org|
             [name, {boxes: org[:boxes].to_h}]
            end
          })
        end
      end

      class Boxes
        attr_reader :boxes, :path, :toplevel_json_files
        def initialize(boxes_path, opts={})
          @path = boxes_path
          @boxes = {}
          @opts = opts.dup
          scan
        end

        # - [x] scan directory for JSON
        # - [x] load from JSON
        # - [ ] TODO: identify json with missing boxes
        # - [ ] TODO: identify boxes with missing top-level json
        def scan
          @toplevel_json_files = Dir["#{@path}/*.json"]
          @toplevel_json_files.each do |box_json|
            box = Box.new(box_json)
            @boxes[box.data['name']] = box
          end
        end

        # rebuild top-level box data (JSON files)
        # TODO: implement
        def rebuild
          raise 'not implemented'
        end

        def validate!
          @boxes.each{|k,v| v.validate!}
        end

        def to_h
          Hash[@boxes.map{ |name,box| [name, box.to_h] }]
        end
      end

      class Box
        attr_reader :data, :versions
        def initialize(box_json, opts={})
          @data = JSON.parse(File.read(box_json))
          @opts = opts.dup
          @versions = @data['versions'].map { |v| Version.new(v,@opts) }
        end

        def validate!
          @versions.each(&:validate!)
        end

        def to_h
          @data.merge({
            'versions' => Hash[@versions.map{ |v| [v.data['version'], v.to_h] }]
          })
        end
      end

      class Version
        attr_reader :data, :providers
        def initialize(data, opts={})
          @data = data.dup
          @opts = opts.dup
          providers = @data['providers']
          unless @opts.fetch(:providers,[]).empty?
            providers = @data['providers'].select{|x| @opts[:providers].include?(x['name'])}
          end
          @providers = providers.map do |p|
            Provider.new(p, opts)
          end
        end
        def validate!
          @providers.each(&:validate!)
        end
        def to_h
          @data.merge({
            'providers' => @providers.map(&:to_h)
          })
        end
      end

      class Provider
        def initialize(data, opts={})
          @data = data.dup
          @opts = opts.dup
          @file = @data['url'].sub(%r{^file://},'')
        end

        def exists?
          File.exists? @file
        end

        def checksum
          warn "Calculating sha256sum of '#{@file}'..."
          require 'digest'
          Digest::SHA256.file(@file).hexdigest
        end

        def validate!
          @data['exists'] = exists?
          puts "VERBOSE: Provider x (#{@file})"  if @opts['verbose']
        end

        def to_h
          @data.to_h
        end
      end
    end
  end
end

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

        # scan a tree
        #
        # sort_by:
        #   - [x] :name
        #   - [x] :updated
        #   - [x] :versions
        #   - [x] :reverse_sort
        # TODO: filter_by:
        #
        # @return [Array] list of boxes
        def list(opts={providers: []})
          root = Simp::Vagrant::DirTree::Root.new(@base_dir,opts)
          root.scan
          tree = root.to_h
          opts = {
            sort_by: :name,
            reverse_sort: true,
          }.merge(opts)
          mod = opts[:reverse_sort] ? -1 : 1
          Hash[tree[:orgs].map do |org,data|
            if(opts[:sort_by] == :name)
              sorted_boxes = Hash[data[:boxes].sort do |a,b|
                (a[1]['name'] <=> b[1]['name']) * mod
              end ]
            elsif(opts[:sort_by] == :updated)
              sorted_boxes = Hash[data[:boxes].sort do |a,b|
                aa = a[1]['versions'].map{|k,v| v['updated_at']}
                bb = b[1]['versions'].map{|k,v| v['updated_at']}
                (aa <=> bb) * mod
              end ]
            elsif(opts[:sort_by] == :versions)
              sorted_boxes = Hash[data[:boxes].sort do |a,b|
                (a[1]['versions'].size <=> bb = b[1]['versions'].size) * mod
              end ]
            end
            [org,data]
          end
          ]
        end

        def list_str( opts={} )
          tree=list
          lines = []
          tree.map do |org, v|
            lines << "#{org}/"
            v[:boxes].map do |box, y|
              lines << "  - #{box}:"
              lines << y['versions'].map do |version,vdata|
                "    - #{version}"
              end.sort.join("\n")
            end
          end
          lines.join("\n")
        end

        # Install vagrant box into a local directory tree, generate version metadata
        #
        # @param [String] box_path path to the `.box` file
        # @param options [Hash] options
        #
        # @option options [String]         :link    Action to place `.box` file.
        #   Valid symbols are `:hardlink`, `:copy`, or `:move`
        #   (Default: :hardlink)
        # @option options [Array<String>] :flavors  (active)
        def self.publish(vars_json_path, box_path, vagrant_box_dir, options={})
          opts = { link: :hardlink, flavors: [] }.merge(options)
          converter = Simp::Packer::VarsJsonToVagrantBoxJson.new(vars_json_path)
          box_data  = converter.vagrant_box_json(box_path, flavors: opts[:flavors])
          dir_tree  = Simp::Packer::Publish::LocalDirTree.new(vagrant_box_dir)
          dir_tree.publish(box_data, opts[:link]) # TODO: env var for copy/link action?
        end


        def place_box_method(action)
          case action
          when :copy
            migrate = ->(src, dst, verbose = true) { FileUtils.cp src, dst, verbose: verbose }
          when :move
            migrate = ->(src, dst, verbose = true) { FileUtils.mv src, dst, verbose: verbose }
          when :hardlink
            migrate = lambda do |src, dst, verbose = true|
              FileUtils.ln src, dst, verbose: verbose, force: (ENV['SIMP_PACKER_publish_force'] == 'yes')
            end
          else
            raise 'ERROR: `action` must be :copy, :move, or :hardlink'
          end
          migrate
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
          src_path = box_file_src.sub(%r{^file://}, '')
          puts "\nPlacing (action: #{action}) box file at path:\n  #{box_file_dest}"
          migrate = place_box_method(action)
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
