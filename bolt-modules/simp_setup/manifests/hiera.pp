#
class simp_setup::hiera(
  Stdlib::Absolutepath $pupenvdir = '/etc/puppetlabs/code/environments',
  String[1]            $environment = 'production',
  Stdlib::Absolutepath $puppetmodpath = "${pupenvdir}/${environment}/modules",
  Stdlib::Absolutepath $hieradata_dir = "${pupenvdir}/${environment}/data",
){
  file{ "${hieradata_dir}/default.yaml":
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => file("${module_name}/default.yaml"),
  }
}
