module Simp
  module Packer
    module Config
      module VBoxNetUtils
        # @return [Array] List of VirtualBox host-only networks
        def hostonlyifs
          %x(VBoxManage list hostonlyifs).split("\n\n")
        end

        # Get the name of the vboxnet for network, or create it
        # @return [String] Name of vboxnet
        # @return [Nil] if unsuccessful
        def vboxnet_for_network(network)
          hostonlyif_ips = {}
          name           = nil
          ipaddr         = nil

          hostonlyifs.each do |lines|
            lines.split("\n").each do |line|
              entry = line.split(':')
              case entry[0]
              when 'Name'
                name = entry[1].strip
              when 'IPAddress'
                ipaddr = entry[1].strip
              end
            end
            hostonlyif_ips[name] = ipaddr
          end

          # Check if the network exists and return it name if it does
          hostonlyif_ips.each { |net_name, ip| return(net_name) if ip.eql?(network) }

          # Network does not exist, create it and return the name
          create_hostonlyif_for(network)
        end

        # @return [String] Name of vboxnet that was created
        # @return [Nil] if unsuccessful
        def create_hostonlyif_for(network)
          puts "creating new Virtualbox hostonly network for #{network}" if @verbose

          cmd_output = %x(VBoxManage hostonlyif create)
          unless cmd_output.include? 'was successfully created'
            raise "ERROR: Creation of network unsuccesful: #{cmd_output}"
          end
          vboxnet = cmd_output.split("'")[1]
          ipconfig_cmd = "VBoxManage hostonlyif ipconfig #{vboxnet} --ip #{network} --netmask 255.255.255.0"
          return vboxnet if system(ipconfig_cmd)
          raise "ERROR: Failure to configure: #{ipconfig_cmd}"
        end
      end
    end
  end
end
