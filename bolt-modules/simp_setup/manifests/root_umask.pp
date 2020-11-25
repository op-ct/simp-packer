#
class simp_setup::root_umask(
  String[1] $umask = '0027',
){
  file_line{ 'root umask':
    path   => '/root/.bash_profile',
    line   => "umask ${umask}",
    match  => '^umask .*',
  }
}
