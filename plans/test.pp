plan simp_packer::test(
 TargetSpec $targets            = get_targets('localhost'),
 Stdlib::Absolutepath $pwd      = system::env('PWD'),
 Stdlib::Absolutepath $tmp_file = "${pwd}/tmp_file.${system::env('$$')}",
){
  out::message( '==== begin plan' )

  $a = apply('localhost'){
    $box        = 'simp-server'
    $build_type = 'simp_iso_to_vagrant_box'

    $template_keys = lookup('packer_build::template_key::structure')
    $h = $template_keys.reduce({}) |$m0, $k| {
       $v = lookup( "packer_build::template_key::${k}", {'default_value' => Undef})
       if $k == 'comments' {
         $m0.merge( $v.map |$k2, $v2| { Hash( [$k2, $v2] ) }.reduce({}) |$m3,$v3| { $m3.merge($v3) } )
       } else {
         $m0.merge( Hash([ $k, $v ]) )
       }
    }
    file{ "$tmp_file": content => to_yaml($h) }
  }
  $y = parseyaml(file::read($tmp_file))
  debug::break()
  out::message( '==== finish plan' )
}
