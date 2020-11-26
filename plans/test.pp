plan simp_packer::test(
 TargetSpec $targets          = get_targets('localhost'),
 Stdlib::Absolutepath $pwd     = system::env('PWD'),
){
  out::message( lookup('test_key') )
}
