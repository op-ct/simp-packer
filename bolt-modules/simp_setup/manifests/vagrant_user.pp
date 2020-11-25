#
class simp_setup::vagrant_user(
  String[1] $password,
  String[1] $home = '/home/vagrant',
){
  user{ 'vagrant':
    password => $password,
    home     => $home,
  }

  file {
    default:
      owner  => 'vagrant',
      mode   => '0600',
    ;
    [ $home, "${home}/.ssh"]:
      ensure => directory,
    ;
    [ "${home}/.ssh/authorized_keys" ]:
      ensure => file,
      content => file("${module_name}/_vagrant_ssh_authorized_keys"),
    ;
  }

}
