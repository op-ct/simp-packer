#
class simp_setup::site_pp(
  Stdlib::Absolutepath $pupenvdir = '/etc/puppetlabs/code/environments',
  String[1]            $env = 'production',
  Stdlib::Absolutepath $manifests_dir = "${pupenvdir}/${env}/manifests",
  Stdlib::Absolutepath $manifest = "${manifests_dir}/site.pp",
){

  $line = @(HOSTGROUP)
    case $facts['fqdn'] {
       /^ws\d+.*/: { $hostgroup = 'workstations' }
       default:    { $hostgroup = 'default'}
    }
    | HOSTGROUP

  file_line{ 'assign hostgroups':
    path    => $manifest,
    line    => $line,
    match   => /^\$hostgroup\s*=\s*['"]default['"]$/,
    replace => true,
    append_on_no_match => false,
  }
}
