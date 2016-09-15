#!/bin/bash

set -e

# Either clones or pulls the repo for given project
# Params:
# $1 organization e.g. spring-cloud
# $2 repo name e.g. spring-cloud-sleuth
function clone_or_pull() {
    if [ "$#" -ne 2 ]
    then
      echo "You haven't provided 2 args... \$1 organization e.g. spring-cloud; \$2 repo name e.g. spring-cloud-sleuth"
      exit 1
    fi
    if [[ "${JUST_PUSH}" == "yes" ]] ; then
        echo "Skipping cloning since the option to just push was provided"
        exit 0
    fi
    local ORGANIZATION=$1
    local REPO_NAME=$2
    local LOCALREPO_VC_DIR=${REPO_NAME}/.git
    if [ ! -d ${LOCALREPO_VC_DIR} ]
    then
        echo "Repo [${REPO_NAME}] doesn't exist - will clone it!"
        git clone git@github.com:${ORGANIZATION}/${REPO_NAME}.git
    else
        echo "Repo [${REPO_NAME}] exists - will pull the changes"
        cd ${REPO_NAME} && git pull || echo "Not pulling since repo is up to date"
        cd ${ROOT_FOLDER}
    fi
}

# For the given branch updates the docs/src/main/asciidoc/ghpages.sh
# with the one from spring-cloud-build. Then commits and pushes the change
# Params:
# $1 repo name e.g. spring-cloud-sleuth
# $2 branch name
function update_mvnw_script() {
    if [ "$#" -ne 2 ]
    then
      echo "You haven't provided 2 args... \$1 repo name e.g. spring-cloud-sleuth; \$2 branch name e.g. master"
      exit 1
    fi
    local REPO_NAME=$1
    local BRANCH_NAME=$2
    echo "Updating ghpages script for [${REPO_NAME}] and branch [${BRANCH_NAME}]"
    cd  ${REPO_NAME}
    echo "Checking out [${BRANCH_NAME}]"
    git checkout ${BRANCH_NAME}
    echo "Resetting the repo and pulling before commiting"
    git reset --hard origin/${BRANCH_NAME} && git pull origin ${BRANCH_NAME}
    # If the user wants to just push we will not copy / add / commit files
    if [[ "${JUST_PUSH}" != "yes" ]] ; then
        echo "Copying [${MVNW_LOCATION}] to [${MVNW_IN_REPO_PATH}]"
        cp -rf ${MVNW_LOCATION} ${MVNW_IN_REPO_PATH}
        echo "Adding and committing [${MVNW_IN_REPO_PATH}] with message [${COMMIT_MESSAGE}]"
        git add ${MVNW_IN_REPO_PATH}
        git commit -m "${COMMIT_MESSAGE}" || echo "Proceeding to the next repo"
    fi
    if [[ "${AUTO_PUSH}" == "yes" ]] ; then
        echo "Pushing the branch [${BRANCH_NAME}]"
        wait_if_manual_proceed
        git push origin ${BRANCH_NAME}
    fi
    cd ${ROOT_FOLDER}
}

# Either clones or pulls the repo for given project and then updates gh-pages for the given project
# Params:
# $1 organization e.g. spring-cloud
# $2 repo name e.g. spring-cloud-sleuth
# $3 branch name e.g. master
function clone_and_update_mvnw() {
    if [ "$#" -ne 3 ]
    then
      echo "You haven't provided 3 args... \$1 organization e.g. spring-cloud; \$2 repo name e.g. spring-cloud-sleuth; \$3 branch name e.g. master"
      exit 1
    fi
    local ORGANIZATION=$1
    local REPO_NAME=$2
    local BRANCH_NAME=$3
    local VAR
    echo -e "\n\nWill clone the repo and update scripts for org [${ORGANIZATION}], repo [${REPO_NAME}] and branch [${BRANCH_NAME}]\n\n"
    clone_or_pull ${ORGANIZATION} ${REPO_NAME}
    update_mvnw_script ${REPO_NAME} ${BRANCH_NAME}
    echo "Proceeding to next project"
    wait_if_manual_proceed
}

function wait_if_manual_proceed() {
    if [[ "${AUTO_PROCEED}" != "yes" ]] ; then
        echo -n "Press [ENTER] to continue..."
        read VAR
    fi
}

# Prints the provided parameters
function print_parameters() {
cat <<EOF
Running the script with the following parameters
GHPAGES_URL=${GHPAGES_URL}
GHPAGES_DOWNLOAD_PATH=${GHPAGES_DOWNLOAD_PATH}
COMMIT_MESSAGE=${COMMIT_MESSAGE}
MVNW_IN_REPO_PATH=${MVNW_IN_REPO_PATH}
MVNW_LOCATION=${MVNW_LOCATION}
AUTO_PROCEED=${AUTO_PROCEED}
AUTO_PUSH=${AUTO_PUSH}
JUST_PUSH=${JUST_PUSH}
ROOT_FOLDER=${ROOT_FOLDER}
EOF
}

# Prints the usage
function print_usage() {
cat <<EOF
The idea of this script is to batch update all ghpages scripts for all projects that we have in Spring Cloud.
If you don't provide any options by default the script will copy the latest ghpages.sh, commit it for each repo
and then push it to the appropriate branch.

USAGE:

You can use the following options:

-p|--nopush         - the script will not push the changes
-m|--manualproceed  - if you want to do a manual proceed after every step
-f|--file           - provide where your mvnw is located. Defaults to the current folder
-x|--justpush       - if you want to go to every single repo and just push the changes
-h|--help           - present this help message

EOF
}

# ==========================================
#    ____   ____ _____  _____ _____ _______
#  / ____|/ ____|  __ \|_   _|  __ \__   __|
# | (___ | |    | |__) | | | | |__) | | |
#  \___ \| |    |  _  /  | | |  ___/  | |
#  ____) | |____| | \ \ _| |_| |      | |
# |_____/ \_____|_|  \_\_____|_|      |_|
#
# ==========================================

while [[ $# > 0 ]]
do
key="$1"
case ${key} in
    -p|--nopush)
    AUTO_PUSH="no"
    ;;
    -m|--manualproceed)
    AUTO_PROCEED="no"
    ;;
    -x|--justpush)
    JUST_PUSH="yes"
    ;;
    -f|--file)
    MVNW_LOCATION="$2"
    shift
    ;;
    -h|--help)
    print_usage
    exit 0
    ;;
    *)
    echo "Invalid option: [$1]"
    print_usage
    exit 1
    ;;
esac
shift # past argument or value
done

export COMMIT_MESSAGE=${COMMIT_MESSAGE:-Updating mvnw for all projects}
export MVNW_IN_REPO_PATH=${MVNW_IN_REPO_PATH:-mvnw}
export MVNW_LOCATION=${MVNW_LOCATION:-`pwd`/mvnw}
export AUTO_PROCEED=${AUTO_PROCEED:-yes}
export AUTO_PUSH=${AUTO_PUSH:-yes}
export JUST_PUSH=${JUST_PUSH:-no}
export ROOT_FOLDER=`pwd`


print_parameters
if [[ ! -f "${MVNW_LOCATION}" ]]; then
    echo -e "\n\nWARNING: In order to run the script you need to have the mvnw file present. You've provided [${MVNW_LOCATION}] and the file is missing."
    exit 1
fi
clone_and_update_mvnw spring-cloud spring-cloud-aws master
clone_and_update_mvnw spring-cloud spring-cloud-aws 1.0.x
clone_and_update_mvnw spring-cloud spring-cloud-aws 1.2.x
clone_and_update_mvnw spring-cloud spring-cloud-bus master
clone_and_update_mvnw spring-cloud spring-cloud-cli 1.0.x
clone_and_update_mvnw spring-cloud spring-cloud-cli 1.1.x
clone_and_update_mvnw spring-cloud spring-cloud-cli master
clone_and_update_mvnw spring-cloud spring-cloud-cloudfoundry master
clone_and_update_mvnw spring-cloud spring-cloud-cluster master
clone_and_update_mvnw spring-cloud spring-cloud-commons master
clone_and_update_mvnw spring-cloud spring-cloud-config master
clone_and_update_mvnw spring-cloud spring-cloud-config 1.1.x
clone_and_update_mvnw spring-cloud spring-cloud-consul 1.0.x
clone_and_update_mvnw spring-cloud spring-cloud-consul master
clone_and_update_mvnw spring-cloud spring-cloud-contract master
clone_and_update_mvnw spring-cloud spring-cloud-netflix 1.0.x
clone_and_update_mvnw spring-cloud spring-cloud-netflix 1.1.x
clone_and_update_mvnw spring-cloud spring-cloud-netflix master
clone_and_update_mvnw spring-cloud spring-cloud-security master
clone_and_update_mvnw spring-cloud spring-cloud-sleuth 1.0.x
clone_and_update_mvnw spring-cloud spring-cloud-sleuth master
clone_and_update_mvnw spring-cloud spring-cloud-starters Brixton
clone_and_update_mvnw spring-cloud spring-cloud-starters master
clone_and_update_mvnw spring-cloud-incubator spring-cloud-vault-config master
clone_and_update_mvnw spring-cloud spring-cloud-zookeeper master
