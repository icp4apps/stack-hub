#!/bin/bash -e

script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
base_dir=$(cd "${script_dir}/.." && pwd)

echo
echo "= Removing build and assets directories."
echo

rm -rf "${base_dir}/build" "${base_dir}/assets"
