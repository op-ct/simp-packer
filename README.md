# WIP

```sh
VAR_FILE="$PWD/testfiles/workingdir.vars.el7.json"

TMPDIR=$PWD/tmp PACKER_LOG=1 PACKER_LOG_PATH=$PWD/packer.log \
  time packer build \
    -var-file="$VAR_FILE" \
    -on-error=ask \
    template.json


packer validate -var-file="$VAR_FILE" template.json
```
