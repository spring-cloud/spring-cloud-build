#!/bin/bash
#!/usr/local/bin/bash

# If you have exceptions while using associative arrays from Bash 4.0 in OSX.
# instead of #!/bin/bash you have to have #!/usr/local/bin/bash

set -e

declare -A PROJECTS

ROOT_FOLDER=$(pwd)
CURRENT_DIR_NAME=$( basename ${ROOT_FOLDER} )
PROJECT_SHORTENED_NAME=${CURRENT_DIR_NAME#*spring-cloud-}
SPRING_CLOUD_RELEASE_REPO=${SPRING_CLOUD_RELEASE_REPO:-git@github.com:spring-cloud/spring-cloud-release.git}
MAVEN_PATH=${MAVEN_PATH:-}
RELEASE_TRAIN_PROJECTS=${RELEASE_TRAIN_PROJECTS:-aws bus cloudfoundry commons config contract netflix security consul sleuth stream task zookeeper vault}
CLOUD_PREFIX="${CLOUD_PREFIX:-spring-cloud}"
PARENT_NAME="${PARENT_NAME:-spring-cloud-build}"

if [ -e "${ROOT_FOLDER}/mvnw" ]; then
    MAVEN_EXEC="$ROOT_FOLDER/mvnw"
else
    MAVEN_EXEC="${MAVEN_PATH}mvn"
fi

# Retrieves from spring-cloud-dependencies module the version of a
function retrieve_version_from_spring_cloud_dependencies() {
  local PROP_NAME="spring-cloud-${1}.version"
  RETRIEVED_VERSION=$( grep "<${PROP_NAME}>" spring-cloud-dependencies/pom.xml | sed -e 's/.*'"<${PROP_NAME}>"'//' -e 's!'"</${PROP_NAME}>"'.*$!!' )
    echo "Extracted version for project [$1] from Maven build is [${RETRIEVED_VERSION}]"
}

function retrieve_parent_version() {
  SC_BUILD_VERSION=$( sed '/<parent/,/<\/parent/!d' pom.xml | grep '<version' | head -1 | sed -e 's/.*<version>//' -e 's!</version>.*$!!' )
}

function update_properties() {
  for pom_file in $( find ${ROOT_FOLDER} -name pom.xml ); do
    sed -i '' "s#\(<spring-cloud-${1}.version>\).*\(</spring-cloud-${1}.version>\)#\1${2}\2#g" "${pom_file}"
  done
}

# Prints the usage
function print_usage() {
cat <<EOF
TODO

USAGE:
You can use the following options:
-i|--interactive        - running the script in an interactive mode
-v|--version            - release train version
-p|--projects           - comma separated list of projects in project:version notation. E.g. ( -p sleuth:1.0.6.RELEASE,cli:1.1.5.RELEASE )
-a|--auto               - no user prompting will take place. Normally after all the parsing is done, before docs building you can check if versions are correct
-r|--retrieveversions   - will clone spring-cloud-release and take properties from there
EOF
}

cat << \EOF
_   _ ___________  _____ _____ _____ _   _
| | | |  ___| ___ \/  ___|_   _|  _  | \ | |
| | | | |__ | |_/ /\ `--.  | | | | | |  \| |
| | | |  __||    /  `--. \ | | | | | | . ` |
\ \_/ / |___| |\ \ /\__/ /_| |_\ \_/ / |\  |
\___/\____/\_| \_|\____/ \___/ \___/\_| \_/


_   _____________  ___ _____ ___________
| | | | ___ \  _  \/ _ \_   _|  ___| ___ \
| | | | |_/ / | | / /_\ \| | | |__ | |_/ /
| | | |  __/| | | |  _  || | |  __||    /
| |_| | |   | |/ /| | | || | | |___| |\ \
\___/\_|   |___/ \_| |_/\_/ \____/\_| \_|

EOF


while [[ $# > 0 ]]
do
key="$1"
case ${key} in
    -i|--interactive)
    INTERACTIVE="yes"
    ;;
    -a|--auto)
    AUTO="yes"
    ;;
    -v|--version)
    RELEASE_TRAIN_VERSION="$2"
    shift # past argumen
    ;;
    -p|--projects)
    INPUT_PROJECTS="$2"
    shift # past argumen
    ;;
    -g|--ghpages)
    GH_PAGES="yes"
    ;;
    -r|--retrieveversions)
    RETRIEVE_VERSIONS="yes"
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

if [[ "${RELEASE_TRAIN_VERSION}" != "" && -z "${INPUT_PROJECTS}" && -z "${RETRIEVE_VERSIONS}" ]] ; then echo -e "WARNING: Version was passed but no projects were passed... setting retrieval option\n\n" && RETRIEVE_VERSIONS="yes";fi
if [[ -z "${RELEASE_TRAIN_VERSION}" && "${INPUT_PROJECTS}" != "" ]] ; then echo -e "WARNING: Projects were passed but version wasn't... quitting\n\n" && print_usage && exit 1;fi
if [[ "${RETRIEVE_VERSIONS}" != "" && "${INPUT_PROJECTS}" != "" ]] ; then echo -e "WARNING: Can't have both projects and retreived projects passed... quitting\n\n" && print_usage && exit 1;fi
if [[ -z "${RELEASE_TRAIN_VERSION}" ]] ; then echo "No version passed - starting in interactive mode..." && INTERACTIVE="yes";fi


if [[ "${INTERACTIVE}" == "yes" ]] ; then
  echo "Welcome to the release train docs generation. You will be asked to provide"
  echo "the names of folders with projects taking part in the release. You will also"
  echo -e "have to provide the library versions\n"
  echo -e "\nEnter the name of the release train"
  read RELEASE_TRAIN
  while :
  do
      echo -e "\nEnter the project name (pass the name as the project's folder is called). Pass sleuth instead of spring-cloud-sleuth"
      read projectName
      echo "Enter the project version"
      read projectVersion
      PROJECTS[${projectName}]=${projectVersion}
      echo "Press any key to provide another project version or 'q' to continue"
      read key
      if [[ ${key} = "q" ]]
      then
          break
      fi
  done
elif [[ "${RELEASE_TRAIN_VERSION}" != "" && -z "${RETRIEVE_VERSIONS}" ]] ; then
  RELEASE_TRAIN=${RELEASE_TRAIN_VERSION}
  echo "Parsing projects"
  IFS=',' read -ra TEMP <<< "$INPUT_PROJECTS"
  for i in "${TEMP[@]}"; do
    IFS=':' read -ra TEMP_2 <<< "$i"
    PROJECTS[${TEMP_2[0]}]=${TEMP_2[1]}
  done
else
  RELEASE_TRAIN=${RELEASE_TRAIN_VERSION}
  echo "Will attempt to retrieve versions from [git@github.com:spring-cloud/spring-cloud-release.git]"
  mkdir -p ${ROOT_FOLDER}/target
  clonedStatic=${ROOT_FOLDER}/target/spring-cloud-release
  if [[ ! -e "${clonedStatic}/.git" ]]; then
      echo "Cloning Spring Cloud Release to target"
      git clone ${SPRING_CLOUD_RELEASE_REPO} ${clonedStatic}
  else
      echo "Spring Cloud Release already cloned - will pull changes"
      cd ${clonedStatic} && git reset --hard && git fetch
  fi
  cd ${clonedStatic}
  git checkout v"${RELEASE_TRAIN_VERSION}" || echo "Failed to checkout [v${RELEASE_TRAIN_VERSION}], will try [${RELEASE_TRAIN_VERSION}]" && git checkout "${RELEASE_TRAIN_VERSION}"
  git status
  ARTIFACTS=( ${RELEASE_TRAIN_PROJECTS} )
  echo -e "\n\nRetrieving versions from Maven for projects [${RELEASE_TRAIN_PROJECTS}]\n\n"
  retrieve_parent_version
  echo "Extracted version for project [build] from Maven build is [${SC_BUILD_VERSION}]"
  for i in ${ARTIFACTS[@]}; do
      retrieve_version_from_spring_cloud_dependencies ${i}
      PROJECTS[${i}]=${RETRIEVED_VERSION}
  done
  echo "Continuing with the script"
fi
VERSION=${PROJECTS[${PROJECT_SHORTENED_NAME}]}
echo -e "\n\n==========================================="
echo "You're project will be updated to version:"
echo ${VERSION}
echo -e "\nVersions where taken from release train:"
echo ${RELEASE_TRAIN_VERSION}
echo -e "\nDependant projects versions:"
echo -e "build -> ${SC_BUILD_VERSION}"
for K in "${!PROJECTS[@]}"; do echo -e "${K} -> ${PROJECTS[$K]}"; done
echo -e "==========================================="
if [[ "${AUTO}" != "yes" ]] ; then
  echo -e "\nPress any key to continue or 'q' to quit"
  read key
  if [[ ${key} = "q" ]]
  then
      exit 1
  fi
else
  echo -e "\nAuto switch was turned on - continuing with modules updating"
fi
cd ${ROOT_FOLDER}
echo "Setting version to ${VERSION}"
if [[ ${PROJECTS[build]} != "" ]]; then
  SC_BUILD_VERSION=${PROJECTS[build]}
else
  PROJECTS[build]=${SC_BUILD_VERSION}
fi
echo -e "\nSetting version of parent [spring-cloud-build] to [${SC_BUILD_VERSION}]"
${MAVEN_EXEC} versions:update-parent -DparentVersion="[${SC_BUILD_VERSION}]" -DgenerateBackupPoms=false -DallowSnapshots=true
echo -e "\nSetting version of project to [${VERSION}]"
${MAVEN_EXEC} versions:set -DnewVersion=${VERSION} -DgenerateBackupPoms=false -DallowSnapshots=true
for K in "${!PROJECTS[@]}"
do
  RETRIEVED_VERSION=${PROJECTS[$K]}
  PROJECT_NAME="${CLOUD_PREFIX}-${K}"
  PROPERTY_NAME="${PROJECT_NAME}.version"
  echo "Updating [${PROJECT_NAME}] property version to [${RETRIEVED_VERSION}]"
  update_properties ${K} ${RETRIEVED_VERSION}
done
