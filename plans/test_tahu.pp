plan simp_packer::test_tahu(
 TargetSpec $targets            = get_targets('localhost'),
 Stdlib::Absolutepath $pwd      = system::env('PWD'),
 Stdlib::Absolutepath $tmp_file = "${pwd}/tmp_file.${system::env('$$')}",
){
  out::message( '==== begin plan' )

  $box = 'simp-server'
  $build_type = 'simp_iso_to_vagrant_box'
  $template_key = undef
  $a = lookup('packer_build::template_key::structure')
  file::write("${pwd}/tmp.json", to_json_pretty($a))
###  apply('localhost'){
###    $box        = 'simp-server'
###    $build_type = 'simp_iso_to_vagrant_box'
###
###    $template_keys = lookup('packer_build::template_key::structure')
###
###    # Construct a packer template hash by looking up each section in
###    # packer_build::template_key::structure
###    #
###    # TODO - recursive / subsection value lookups
###    $h = $template_keys.reduce({}) |$m0, $k| {
###       $v = lookup( "packer_build::template_key::${k}", {'default_value' => Undef})
###       if $k == 'comments' {
###         $m0.merge( $v.map |$k2, $v2| { Hash( [$k2, $v2] ) }.reduce({}) |$m3,$v3| { $m3.merge($v3) } )
###       } else {
###         $m0.merge( Hash([ $k, $v ]) )
###       }
###    }
###
###    # write results to a file for packer to consume
###    # TODO There will be several files:
###    #   - template.json
###    #   - vars.json
###    #   - simp_conf.yaml (an uploaded file)
###    file{ "$tmp_file": content => to_yaml($h) }
###  }
###  $y = parseyaml(file::read($tmp_file))
  debug::break()
  out::message( '==== finish plan' )
}
