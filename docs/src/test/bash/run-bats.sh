#!/bin/bash

[[ -z $DEBUG ]] || set -o xtrace

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

"${ROOT_DIR}"/build-helper.sh "initialize-submodules"
"${ROOT_DIR}"/build-helper.sh "download-shellcheck"
"${ROOT_DIR}"/build-helper.sh "run-shellcheck"
"${ROOT_DIR}"/build-helper.sh "download-bats"
"${ROOT_DIR}"/build-helper.sh "run-bats"