#!/usr/bin/env bash

# Kernel Patch Generator
#
# ./patch-generator.sh <KERNEL> <PATCHNAME> <PATCHTARGET>
#
# Assumes that source files are organized as follows:
#
# - Files to append to existing files such as Makefiles and Kconfigs.
#   The files are appended to the kernel tree files in place. Folder
#   structure hash to match the kernel tree.
#
# append/
#   .../file
#
# - Files to copy into the kernel. Folder structure hash to match
#   the kernel tree.
#
# copy/
#   .../file.x
#
# Arguments:
#
# <KERNEL>       - Git URL to kernel source
# <PATCHNAME>    - Name of patch to generate
# <PATCHTARGET>  - Target folder to generate patch to

set -euo pipefail

usage="Usage: $0 <KERNEL> <PATCHNAME> <PATCHTARGET>"

KERNEL=$1
PATCHNAME=$2
PATCHTARGET=$3

[[ -z $KERNEL ]] && echo $usage && exit 1
[[ -z $PATCHNAME ]] && echo $usage && exit 1
[[ -z $PATCHTARGET ]] && echo $usage && exit 1

[[ -d kernel ]] && rm -rf kernel
[[ ! -d kernel ]] && git clone $KERNEL kernel

mkdir -p target/$PATCHTARGET

pushd kernel
  git reset --hard
  git clean -xdf
popd

for append in $(find append/ -type f); do
  dst=$(echo $append | sed -e 's/append/kernel/')
  cat $append >> $dst
done

cp -Rv copy/* kernel/

pushd kernel
  git add .
  git commit -m $PATCHNAME
  git format-patch -k -1 -o ../target/$PATCHTARGET
popd

rm -rf kernel

NIX_MODULE_PATH=target/$PATCHTARGET/$PATCHNAME.nix
NIX_MODULE="
# Autogenerated by patch-generator.sh, don't change manually!
{
  boot.kernelPatches = [
    {
      name = $PATCHNAME;
      patch = "./0001-$PATCHNAME.patch";
    }
  ];
}
"

echo "$NIX_MODULE" > $NIX_MODULE_PATH