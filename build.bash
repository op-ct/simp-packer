#!/bin/bash
#export SIMP_ISO_JSON_FILES="$ctiso_prereleases/cjt/SIMP-6.3.0-BETA.el7-CentOS-7.0-x86_64__3d41-SIMP-5557.json"
#export SIMP_ISO_JSON_FILES="/net/ISO/Testing_isos/SIMP-6.3.0-PreRelease/2018-11-13/SIMP-6.3.0-BETA.el6-CentOS-6.10-x86_64__e71b.json:/net/ISO/Testing_isos/SIMP-6.3.0-PreRelease/2018-11-13/SIMP-6.3.0-BETA.el7-CentOS-7.0-x86_64__e71b.json"
#export SIMP_PACKER_matrix_label="build_SIMP-5548_e71b"

export VAGRANT_BOX_DIR="${VAGRANT_BOX_DIR:-$ctvagrant}"

###iso_releases=/net/ISO/Releases/
###simp_iso_json_files=( \
###  SIMP-6.2.0-0.el6-CentOS-6.9-x86_64.json \
###  SIMP-6.2.0-0.el7-CentOS-7.0-x86_64.json \
###)
function join_by { local IFS="$1"; shift; echo "$*"; }
#export SIMP_ISO_JSON_FILES="$(join_by : $(printf " ${iso_releases}%s" "${simp_iso_json_files[@]}"))"

iso_releases=/net/ISO/Releases
iso_testing=/net/ISO/Testing_isos/SIMP-6.3.0-PreRelease
simp_iso_json_files=( \
  "${iso_testing}/2018-12-10/SIMP-6.3.0-BETA.el7-CentOS-7.0-x86_64.json" \
)
export SIMP_PACKER_matrix_label="build_SIMP-6.3.0"

#  "${iso_releases}/SIMP-6.2.0-0.el7-CentOS-7.0-x86_64.json" \
#  "${iso_releases}/SIMP-6.2.0-0.el6-CentOS-6.9-x86_64.json" \
export SIMP_ISO_JSON_FILES="$(join_by : $(printf " %s" "${simp_iso_json_files[@]}"))"

echo
echo == SIMP_ISO_JSON_FILES=$SIMP_ISO_JSON_FILES
echo
#TMPDIR="$PWD/tmp" time bundle exec rake "simp:packer:matrix[os=el6:el7,fips=on:off,encryption=off:on]"
TMPDIR="$PWD/tmp" time bundle exec rake "simp:packer:matrix[os=el7:el6,fips=on:off]"
TMPDIR="$PWD/tmp" time bundle exec rake "simp:packer:matrix[os=el7:el6,fips=on:off,encryption=on]"

date
bc
