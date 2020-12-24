plan simp_packer::packer_template_file(
 TargetSpec $targets                   = 'localhost',
 Stdlib::Absolutepath $pwd             = system::env('PWD'),
 Boolean $fips_mode                    = false,
 Boolean $disk_encrypt                 = false,
 Optional[String[1]]     $box          = 'simp-server',
 Optional[String[1]]     $build_type   = 'simp_iso_to_vagrant_box',
 Optional[String[1]]     $template_key = undef,
){
  out::message( '==== begin plan' )

  $template_comments_hash   = lookup('packer_build::template::comments')
  $template_keys_hash       = lookup('packer_build::template::keys')
  $packer_template_hash     = $template_comments_hash.merge($template_keys_hash)

  $packer_template_json     = inline_epp(to_json_pretty($packer_template_hash))
  $packer_template_filename = lookup('packer_build::template::file_name')

  file::write("${pwd}/${packer_template_filename}", $packer_template_json)
  out::message( "  ++ wrote packer template file: '${pwd}/${packer_template_filename}'" )

  out::message( '==== finish plan' )
}
