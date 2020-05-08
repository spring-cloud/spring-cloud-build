#!/usr/bin/env bats

load 'test_helper'
load '../../../target/test_helper/bats-support/load'
load '../../../target/test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
	
	cp -a "${SOURCE_DIR}" "${TEMP_DIR}/sc-build"

	cp -a "${FIXTURES_DIR}/spring-cloud-stream" "${TEMP_DIR}/"
	mv "${TEMP_DIR}/spring-cloud-stream/git" "${TEMP_DIR}/spring-cloud-stream/.git"
	cp -a "${FIXTURES_DIR}/spring-cloud-static" "${TEMP_DIR}/"
	mv "${TEMP_DIR}/spring-cloud-static/git" "${TEMP_DIR}/spring-cloud-static/.git"

	export SOURCE_FUNCTIONS="true"
	export GITHUB_REPO_USERNAME_ENV="MY_REPO_USERNAME"
	export GITHUB_REPO_PASSWORD_ENV="MY_REPO_PASSWORD"
	export SPRING_CLOUD_STATIC_REPO_DESTINATION="${TEMP_DIR}"
}

teardown() {
	rm -rf "${TEMP_DIR}"
}

function fake_git {
	if [[ "$*" == *"push"* ]]; then
		echo "pushing the project"
	elif [[ "$*" == *"pull"* ]]; then
		echo "pulling the project"
	fi
	git $*
}

function git_with_remotes {
	if [[ "$*" == *"set-url"* ]]; then
		echo "git $*"
	elif [[ "$*" == *"config remote.origin.url"* ]]; then
		echo "git://example1.example2/example3.git"
	else 
		git $*
	fi
}

function printing_git {
	echo "git $*"
}

function printing_git_failing_with_diff_index {
	if [[ "$*" == *"diff-index"* ]]; then
		return 1
	else 
		echo "git $*"
	fi
}

function printing_git_with_remotes {
	if [[ "$*" == *"config remote.origin.url"* ]]; then
		echo "git://example1.example2/example3.git"
	else 
		printing_git $*
	fi
}

function stubbed_git {
	if [[ "$*" == *"config remote.origin.url"* ]]; then
		echo "git://example1.example2/example3.git"
	elif [[ "$*" == *"diff-index"* ]]; then
		return 1
	elif [[ "$*" == *"symbolic-ref"* ]]; then
		echo "master"
	elif [[ "$*" == *"remote -v"* ]]; then
		git $*
	else 
		printing_git $*
	fi
}

export -f fake_git
export -f git_with_remotes
export -f printing_git
export -f printing_git_with_remotes
export -f stubbed_git

@test "should upload the built docs to the root of gh-pages for snapshot versions" {
	export BRANCH=master
	export GIT_BIN="stubbed_git"
	export SOURCE_FUNCTIONS=""
	export RELEASER_GIT_OAUTH_TOKEN="mytoken"
	cd "${TEMP_DIR}/spring-cloud-stream/"
	mkdir -p docs/target/generated-docs/
	touch docs/target/generated-docs/example1.html

	run "${SOURCE_DIR}"/ghpages.sh

	assert_success
	assert_output --partial "Spring Cloud Static repo is [${TEMP_DIR}]"
	assert_output --partial "git remote set-url --push origin https://mytoken@example1.example2/example3.git"
	assert_output --partial "git fetch -q"
	assert_output --partial "git checkout master"
	assert_output --partial "git stash"
	assert_output --partial "git checkout gh-pages"
	assert_output --partial "git pull origin gh-pages"
	# Current branch is master - will copy the current docs only to the root folder
	assert_output --partial "git add -A ${TEMP_DIR}/spring-cloud-stream"
   	assert_output --partial "git commit -a -m Sync docs from master to gh-pages"
	assert_output --partial "git remote set-url --push origin https://mytoken@example1.example2/example3.git"
	assert_output --partial "git push origin gh-pages"
	assert_output --partial "git checkout master"
	assert_output --partial "git stash pop"
}

@test "should upload the built docs to spring-cloud-static gh-pages branch for non-snapshot versions" {
	export BRANCH=master
	export GIT_BIN="stubbed_git"
	export SOURCE_FUNCTIONS=""
	export RELEASER_GIT_OAUTH_TOKEN="mytoken"
	export VERSION="1.0.0.RELEASE"
	export DESTINATION="${TEMP_DIR}/spring-cloud-static"

	cd "${TEMP_DIR}/spring-cloud-stream/"
	mkdir -p docs/target/generated-docs/
	touch docs/target/generated-docs/example1.html

	run "${SOURCE_DIR}"/ghpages.sh

	assert_success
	assert_output --partial "Spring Cloud Static repo is [${TEMP_DIR}]"
	assert_output --partial "git remote set-url --push origin https://mytoken@example1.example2/example3.git"
	assert_output --partial "git remote set-branches --add origin gh-pages"
	assert_output --partial "git fetch -q"
	# Previous branch was [master]
	assert_output --partial "git checkout master"
	assert_output --partial "git checkout v1.0.0.RELEASE"
	assert_output --partial "git stash"
	assert_output --partial "git checkout gh-pages"
	assert_output --partial "git pull origin gh-pages"
	# Current branch is master - will copy the current docs only to the root folder
	assert [ -f "${TEMP_DIR}/spring-cloud-static/spring-cloud-stream/${VERSION}/example1.html" ]
	assert_output --partial "git add -A ${TEMP_DIR}/spring-cloud-static/spring-cloud-stream/${VERSION}"
   	assert_output --partial "git commit -a -m Sync docs from v1.0.0.RELEASE to gh-pages"
	assert_output --partial "git remote set-url --push origin https://mytoken@example1.example2/example3.git"
	assert_output --partial "git push origin gh-pages"
	assert_output --partial "git checkout master"
	assert_output --partial "git stash pop"
}

@test "should upload the release train docs to spring-cloud-static under the release train folder" {
	export BRANCH=master
	export GIT_BIN="stubbed_git"
	export SOURCE_FUNCTIONS=""
	export RELEASER_GIT_OAUTH_TOKEN="mytoken"
	export VERSION="Greenwich.SR2"
	export DESTINATION="${TEMP_DIR}/spring-cloud-static"
	export RELEASE_TRAIN="yes"

	cd "${TEMP_DIR}/spring-cloud-stream/"
	mkdir -p docs/target/generated-docs/
	touch docs/target/generated-docs/example1.html

	run "${SOURCE_DIR}"/ghpages.sh

	assert_success
	assert_output --partial "git remote set-url --push origin https://mytoken@example1.example2/example3.git"
	# Previous branch was [master]
	assert_output --partial "git checkout master"
	assert_output --partial "git stash"
	assert_output --partial "git checkout gh-pages"
	assert_output --partial "git pull origin gh-pages"
	# Current branch is master - will copy the current docs only to the root folder
	assert [ -f "${TEMP_DIR}/spring-cloud-static/${VERSION}/example1.html" ]
	assert_output --partial "git add -A ${TEMP_DIR}/spring-cloud-static/${VERSION}"
   	assert_output --partial "git commit -a -m Sync docs from vGreenwich.SR2 to gh-pages"
	assert_output --partial "git remote set-url --push origin https://mytoken@example1.example2/example3.git"
	assert_output --partial "git push origin gh-pages"
	assert_output --partial "git checkout master"
	assert_output --partial "git stash pop"
}

@test "should set all the env vars" {
	export SPRING_CLOUD_STATIC_REPO="${TEMP_DIR}/spring-cloud-static"

	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	set_default_props

	assert_success
	assert [ "${ROOT_FOLDER}" != "" ]
	assert [ "${MAVEN_EXEC}" != "" ]
	assert [ "${REPO_NAME}" != "" ]
	assert [ "${SPRING_CLOUD_STATIC_REPO}" != "" ]
}

@test "should not add auth token to URL if token not present" {
	export GIT_BIN="git_with_remotes"
	export RELEASER_GIT_OAUTH_TOKEN=""
	
	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run add_oauth_token_to_remote_url

	assert_success
	assert_output --partial "git remote set-url --push origin https://example1.example2/example3.git"
}

@test "should add auth token to URL if token is present" {
	export GIT_BIN="git_with_remotes"
	export RELEASER_GIT_OAUTH_TOKEN="mytoken"
	
	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run add_oauth_token_to_remote_url

	assert_success
	assert_output --partial "git remote set-url --push origin https://mytoken@example1.example2/example3.git"
}

@test "should retrieve the name of the current branch" {
	export BRANCH=master
	export GIT_BIN="stubbed_git"
	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run retrieve_current_branch

	assert_success
	assert_output --partial "git checkout master"
}

@test "should retrieve the name of the current branch when previous branch was set" {
	export GIT_BIN="printing_git"
	export BRANCH="gh-pages"
	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run retrieve_current_branch

	assert_success
	assert_output --partial "Current branch is [gh-pages]"
	refute_output --partial "git checkout git symbolic-ref -q HEAD"
	assert_output --partial "git checkout gh-pages"
	assert_output --partial "Previous branch was [gh-pages]"
}

@test "should not switch to tag for release train" {
	export GIT_BIN="printing_git"
	export RELEASE_TRAIN="yes"

	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run switch_to_tag

	assert_success
	refute_output --partial "git checkout"
}

@test "should switch to tag for release train" {
	export GIT_BIN="printing_git"
	export RELEASE_TRAIN="no"
	export VERSION="1.0.0"

	cd "${TEMP_DIR}/spring-cloud-stream/"
	source "${SOURCE_DIR}"/ghpages.sh

	run switch_to_tag

	assert_success
	assert_output --partial "git checkout v1.0.0"
}

@test "should not build docs when build option is disabled" {
	export BUILD="no"

	cd "${TEMP_DIR}/spring-cloud-stream/"
	echo -e '#!/bin/sh\necho $*' > mvnw
	source "${SOURCE_DIR}"/ghpages.sh

	run build_docs_if_applicable

	assert_success
	refute_output --partial "clean install"
}

@test "should build docs when build option is enabled" {
	export BUILD="yes"

	cd "${TEMP_DIR}/spring-cloud-stream/"
	echo -e '#!/bin/sh\necho $*' > mvnw

	source "${SOURCE_DIR}"/ghpages.sh

	run build_docs_if_applicable

	assert_success
	assert_output --partial "clean install"
}

@test "should stash changes if dirty" {
	export GIT_BIN="printing_git_failing_with_diff_index"
	cd "${TEMP_DIR}/spring-cloud-stream/"

	source "${SOURCE_DIR}"/ghpages.sh

	run stash_changes

	assert_success
	assert_output --partial "git stash"
}

@test "should not stash changes if repo is not dirty" {
	export GIT_BIN="printing_git"
	cd "${TEMP_DIR}/spring-cloud-static/"

	source "${SOURCE_DIR}"/ghpages.sh

	run stash_changes

	assert_success
	refute_output --partial "git stash"
}

@test "should add and commit all non ignored files for master branch" {
	export GIT_BIN="printing_git"
	export CURRENT_BRANCH="master"
	cd "${TEMP_DIR}/spring-cloud-stream/"
	mkdir -p docs/target/generated-docs/
	touch docs/target/generated-docs/example1.html

	source "${SOURCE_DIR}"/ghpages.sh

	copy_docs_for_current_version

	assert_success
	assert [ "${COMMIT_CHANGES}" == "yes" ]
}

@test "should add and commit all non ignored files for a custom branch and convert root file to index.html" {
	export GIT_BIN="printing_git"
	export CURRENT_BRANCH="present"
	export WHITELISTED_BRANCHES_VALUE="present"
	cd "${TEMP_DIR}/spring-cloud-stream/"
	mkdir -p docs/target/generated-docs/
	touch docs/target/generated-docs/my_doc.html
	touch docs/target/generated-docs/example1.html

	source "${SOURCE_DIR}"/ghpages.sh

	copy_docs_for_current_version

	assert_success
	assert [ "${COMMIT_CHANGES}" == "yes" ]

	run copy_docs_for_current_version

	assert_success
	assert_output --partial "add -A ${ROOT_FOLDER}/present/my_doc.html"
	assert_output --partial "add -A ${ROOT_FOLDER}/present/example1.html"
}

@test "should do nothing if current branch is not whitelisted" {
	export CURRENT_BRANCH="custom"
	export WHITELISTED_BRANCHES_VALUE="non_present"
	cd "${TEMP_DIR}/spring-cloud-stream/"

	source "${SOURCE_DIR}"/ghpages.sh

	copy_docs_for_current_version

	assert_success
	assert [ "${COMMIT_CHANGES}" != "yes" ]
}

@test "should not do anything if commit flag not set" {
	export GIT_BIN="printing_git_with_remotes"
	export COMMIT_CHANGES="no"

	source "${SOURCE_DIR}"/ghpages.sh

	run commit_changes_if_applicable

	assert_success
	refute_output --partial "git"
}

@test "should commit changes if commit flag set" {
	export GIT_BIN="printing_git_with_remotes"
	export COMMIT_CHANGES="yes"
	export RELEASER_GIT_OAUTH_TOKEN="mytoken"

	source "${SOURCE_DIR}"/ghpages.sh

	run commit_changes_if_applicable

	assert_success
	assert_output --partial "git commit -a -m Sync docs from to gh-pages"
	assert_output --partial "git remote set-url --push origin https://mytoken@example1.example2/example3.git"
	assert_output --partial "git push origin gh-pages"
}

@test "should commit changes with username and password if commit flag set" {
	export GIT_BIN="printing_git_with_remotes"
	export COMMIT_CHANGES="yes"
	export MY_REPO_USERNAME="username"
	export MY_REPO_PASSWORD="password"

	source "${SOURCE_DIR}"/ghpages.sh

	run commit_changes_if_applicable

	assert_success
	assert_output --partial "git commit -a -m Sync docs from to gh-pages"
	assert_output --partial "git remote set-url --push origin https://username:password@example1.example2/example3.git"
	assert_output --partial "git push origin gh-pages"
}

@test "should checkout previous branch and pop changes from stash when dirty" {
	export GIT_BIN="printing_git"
	export PREVIOUS_BRANCH="previous_branch"
	export dirty="1"

	source "${SOURCE_DIR}"/ghpages.sh

	run checkout_previous_branch

	assert_success
	assert_output --partial "git checkout previous_branch"
	assert_output --partial "git stash pop"
}

@test "should checkout previous branch and not pop changes from stash when not dirty" {
	export GIT_BIN="printing_git"
	export PREVIOUS_BRANCH="previous_branch"
	export dirty="0"

	source "${SOURCE_DIR}"/ghpages.sh

	run checkout_previous_branch

	assert_success
	assert_output --partial "git checkout previous_branch"
	refute_output --partial "git stash pop"
}

@test "should fail when version was set but destination / clone was not" {
	export VERSION="1.0.0.RELEASE"
	
	source "${SOURCE_DIR}"/ghpages.sh

	run assert_properties

	assert_failure
}

@test "should pass when version was set and destination was too" {
	export VERSION="1.0.0.RELEASE"
	export DESTINATION="/tmp/foo"
	
	source "${SOURCE_DIR}"/ghpages.sh

	run assert_properties

	assert_success
}

@test "should pass when version was set and clone was too" {
	export VERSION="1.0.0.RELEASE"
	export CLONE="true"
	
	source "${SOURCE_DIR}"/ghpages.sh

	run assert_properties

	assert_success
}

@test "should fail when destination and clone were set but version was not" {
	export DESTINATION="/tmp/foo"
	export CLONE="true"
	
	source "${SOURCE_DIR}"/ghpages.sh

	run assert_properties

	assert_failure
}

@test "should pass when destination and clone and version were set" {
	export DESTINATION="/tmp/foo"
	export CLONE="true"
	export VERSION="1.0.0.RELEASE"
	
	source "${SOURCE_DIR}"/ghpages.sh

	run assert_properties

	assert_success
}

@test "should fail when clone was set to true and destination is defined" {
	export CLONE="true"
	export DESTINATION="/tmp/foo"
	
	source "${SOURCE_DIR}"/ghpages.sh

	run assert_properties

	assert_failure
}

@test "should pass when clone was set to true and destination is not defined" {
	export DESTINATION=""
	export CLONE="true"
	
	source "${SOURCE_DIR}"/ghpages.sh

	run assert_properties

	assert_success
}

@test "should fail when release train was set but no version was passed" {
	export VERSION=""
	export RELEASE_TRAIN="true"
	
	source "${SOURCE_DIR}"/ghpages.sh

	run assert_properties

	assert_failure
}

@test "should pass when release train was set and version and clone was passed" {
	export VERSION="Greenwich.SR1"
	export CLONE="true"
	export RELEASE_TRAIN="true"
	
	source "${SOURCE_DIR}"/ghpages.sh

	run assert_properties

	assert_success
}

@test "should print the usage" {
	source "${SOURCE_DIR}"/ghpages.sh

	run print_usage

	assert_success
	assert_output --partial "The idea of this script"
}