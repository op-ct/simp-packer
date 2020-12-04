#
class simp_setup::bashrc_extras(
){
  file{ '/root/.bashrc-extras':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => file("${module_name}/_bashrc_extras")
  }

  file_line{ 'source extras from .bashrc':
    path    => '/root/.bashrc',
    line    => '[ -f /root/.bashrc-extras ] && source /root/.bashrc-extras'
  }
}
