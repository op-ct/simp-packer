#!/bin/bash

function join_by { local IFS="$1"; shift; echo "$*"; }

#export SIMP_PACKER_matrix_label="build_SIMP-5548_e71b"

export VAGRANT_BOX_DIR="${VAGRANT_BOX_DIR:-$ctvagrant}"
SIMP_PACKER_big_sleep="${SIMP_PACKER_big_sleep:-240}"
export  SIMP_PACKER_big_sleep
export SIMP_PACKER_clean_virtualbox=yes

#export SIMP_ISO_JSON_FILES="$(join_by : $(printf " ${iso_releases}%s" "${simp_iso_json_files[@]}"))"

iso_testing=/net/ISO/Testing_isos/SIMP-6.3.0-PreRelease
simp_iso_json_files=( \
  "${iso_testing}/SIMP-6.3.0-BETA.el7-CentOS-7.0-x86_64.json" \
  "${iso_testing}/SIMP-6.3.0-BETA.el6-CentOS-6.10-x86_64.json" \
)
export SIMP_PACKER_matrix_label="build_SIMP-6.3.0"
export SIMP_ISO_JSON_FILES="$(join_by : $(printf " %s" "${simp_iso_json_files[@]}"))"

echo
echo == SIMP_ISO_JSON_FILES=$SIMP_ISO_JSON_FILES
echo
bundle exec rake clean
TMPDIR="$PWD/tmp" time bundle exec rake "simp:packer:matrix[os=el7:el6,fips=on:off,encryption=off:on]"

date
bc
