require 'rake/clean'

CLEAN << FileList.new('puppet/modules/*/spec/fixtures')

def vb_list_vms(boxname_regex = %r{.})
  data = %x(VBoxManage list vms).lines.grep(boxname_regex)
  data.map! { |x| x.split('{').map { |y| y.gsub(%r{["\s\}]}, '') } }
end

task :clean do
  require 'find'
  Find.find('puppet', 'assets', 'scripts', 'files') do |path|
    File.unlink(path) if File.symlink? path
  end

  # remove left-over VirtualBox boxes
  if ENV.fetch('SIMP_PACKER_clean_virtualbox', 'no') == 'yes'
    boxname_regex = %r{SIMP.*FIPS}
    vboxes = Hash[vb_list_vms(boxname_regex)]

    # Delete any VM that is left over
    vboxes.each do |vm_name, _uuid|
      sh "VBoxManage controlvm '#{vm_name}' poweroff; :"
      sh "VBoxManage unregistervm '#{vm_name}' --delete; :"
    end

    # Remove any box files that weren't removed
    vbox_dir = %x(VBoxManage list systemproperties).lines.grep(%r{default machine folder}i).first.split(%r{:\s+})[1].strip

    Dir[File.join(vbox_dir, '*')].grep(boxname_regex).each do |vm_dir|
      rm_rf "echo rm -rf '#{vm_dir}'"
    end
  end

  unless ENV['SIMP_PACKER_clean_virtualbox']
    warn 'NOTE: Run with `SIMP_PACKER_clean_virtualbox=yes` to remove VMs and files'
  end
end
