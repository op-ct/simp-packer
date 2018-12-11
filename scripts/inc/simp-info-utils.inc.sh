#!/bin/sh
#
# Helpers to provide commonly-requested SIMP/Puppet info
#
# Example usage:
#
#    source '/var/local/simp/inc/simp-info-utils.sh'
#    hieradata_dir="$(simp_hieradata_path)"
#    pupenvdir="$(puppet_env_path)"

# Ensure the PATH can reach Puppet binaries
export PATH="/opt/puppetlabs/puppet/bin:${PATH}"

# Returns the SIMP version information by setting various shell variables
#
#   `$simp_semver`  ordered array of SemVer parts that had been delimited by `.`
#   `$simp_major`   major version of SIMP
#   `$simp_minor`   minor version of SIMP
#
simp_semver_vars()
{
  simp_version="$(cat /etc/simp/simp.version)"
  simp_semver=( ${simp_version//./ } )
  simp_major="${simp_semver[0]}"
  simp_minor="${simp_semver[1]}"
}

# memoized puppet environmentpath
puppet_env_path()
{
  _simp_puppet_environment_dir="${_simp_puppet_environment_dir:-$(puppet config print environmentpath)}"
  echo "$_simp_puppet_environment_dir"
}


# Return what the Hiera data path should be as `$hieradata_dir`
simp_hieradata_path()
{
  pupenvdir="$(puppet_env_path)"
  hieradata_dir="${pupenvdir}/simp/data"

  simp_semver_vars
  # Use old hieradata path when SIMP < 6.3.0
  if [[ ( "$simp_major" -eq 6  &&  "$simp_minor" -lt 3 ) || "$simp_major" -le 5 ]]; then
    hieradata_dir="$pupenvdir/simp/hieradata"
  fi

  echo "$hieradata_dir"
}

# TODO: No one really needs this any more because we set the PATH to puppet's
#       bin...should we get rid of it?
find_ruby_path_or_die()
{
  ERR_NO_RUBY_EXE=71

  for pth in /opt/puppetlabs/puppet/bin /opt/puppetlabs/bin; do
    if [ -z "$RUBY_EXE" ] && [ -x "$pth/ruby" ]; then
      export PATH="$pth:${PATH}"
      RUBY_EXE="$pth/ruby"
    fi
  done
  [ -z "$RUBY_EXE" ]&& { echo "ERROR: could not find a ruby executable"; exit "${ERR_NO_RUBY_EXE}"; }
  echo "$RUBY_EXE"
}
