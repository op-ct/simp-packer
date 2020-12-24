plan simp_packer::test_tahu(
 TargetSpec $targets                   = get_targets('localhost'),
 Stdlib::Absolutepath $pwd             = system::env('PWD'),
 Stdlib::Absolutepath $tmp_file        = "${pwd}/tmp_file.${system::env('$$')}",
 Optional[String[1]]     $box          = 'simp-server',
 Optional[String[1]]     $build_type   = 'simp_iso_to_vagrant_box',
 Optional[String[1]]     $template_key = undef,
 String[1] $template_filename          = lookup('packer_build::template::file_name'),
 Hash $template_comments_hash          = lookup('packer_build::template::comments'),
 Hash $template_keys_hash              = lookup('packer_build::template::keys'),
){
  out::message( '==== begin plan' )

  # variables for Hiera lookup in plan_hierarchy
  $packer_template_hash   = $template_comments_hash.merge($template_keys_hash)

  $packer_template_json = to_json_pretty($packer_template_hash)
  file::write("${pwd}/${template_filename}", $packer_template_json)

  out::message( '==== finish plan' )
}
