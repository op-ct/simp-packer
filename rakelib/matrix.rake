require 'simp/packer/build/matrix'
require 'rake'
namespace :simp do
  namespace :packer do
    desc <<-DESCRIPTION.gsub(%r{^ {6}}, '')
      Run simp-packer in a matrix of various conditions

      Examples:

        rake simp:packer:matrix[os=el6:el7]
        rake simp:packer:matrix[os=el6:el7,fips=on:off]

      ENV vars:

       * TMPDIR               A POSIX environment variable that is often **critical to
                              set** when running packer: the directory _must_ be able
                              to store over 4GB as each box is being built. The
                              default location is `/tmp`, which on many systems is
                              unable to store that much data.
      * VAGRANT_BOX_DIR       Path to top of Vagrant box tree
      * SIMP_ISO_JSON_FILES   (Optional) List of absolute paths/globs to SIMP ISO
                              `.json` files to consider (delimiters: `:`, `,`).  This
                              variable can be used as an alternative to the matrix
                              entry `json=`. Non-existent paths will be discarded with
                              a warning message.
      * `SIMP_PACKER_matrix_label`        (Optional) Label for this matrix run that will prefix
                              each iteration's directory name (default:
                              `build_<YYYYmmdd>_<HHMMSS>`)


    DESCRIPTION

    task :matrix => [:clean] do |task, args|
      if args.extras.empty?
        t = task.application.tasks.select { |x| x.name == task.name }.first
        raise ArgumentError, <<FAIL

--------------------------------------------------------------------------------
ERROR: Task arguments must provide a matrix string
--------------------------------------------------------------------------------

Usage:

  rake #{t.name_with_args}[MATRIX]

#{t.full_comment.sub(%r{^#{t.comment}}, '').strip}

--------------------------------------------------------------------------------

FAIL
      end
      Simp::Packer::Build::Matrix.new(args.extras).run
    end
  end
end
