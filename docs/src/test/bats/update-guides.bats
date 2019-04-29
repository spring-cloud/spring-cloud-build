#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
	export COPIED_SOURCES="${TEMP_DIR}/sc-build"
	export PROJECT_VERSION="1.0.0.RELEASE"

	cp -a "${SOURCE_DIR}" "${COPIED_SOURCES}"

	cp -a "${FIXTURES_DIR}/gs-contract-rest" "${TEMP_DIR}/"
	cp -a "${FIXTURES_DIR}/guides" "${TEMP_DIR}/"
	mv "${TEMP_DIR}/gs-contract-rest/git" "${TEMP_DIR}/gs-contract-rest/.git"
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
		echo "git://foo.bar/baz.git"
	else 
		git $*
	fi
}

function printing_git {
	echo "git $*"
}

function printing_git_with_remotes {
	if [[ "$*" == *"config remote.origin.url"* ]]; then
		echo "git://foo.bar/baz.git"
	else 
		printing_git $*
	fi
}

function stubbed_git {
 	if [[ "$*" == *"config remote.origin.url"* ]]; then
 		echo "git://foo.bar/baz.git"
 	elif [[ "$*" == *"commit"* ]]; then
 		printing_git $*
 	elif [[ "$*" == *"push"* ]]; then
 		printing_git $*
 	else
 		git $*
 	fi
 }

export -f printing_git
export -f printing_git_with_remotes
export -f stubbed_git

@test "should do nothing when project version is not release" {
	cd "${TEMP_DIR}"
	mkdir .git
	export GIT_BIN="stubbed_git"
	export SPRING_GUIDES_REPO_ROOT="$( pwd )"
	export PROJECT_VERSION="1.0.0.BUILD-SNAPSHOT"

	run "${COPIED_SOURCES}"/update-guides.sh

	assert_success
	refute_output --partial "git"
}

@test "should fail if we're not in the root of the project" {
	cd "${TEMP_DIR}/sc-build"
	export GIT_BIN="printing_git_with_remotes"

	run "${COPIED_SOURCES}"/update-guides.sh

	assert_failure
}

@test "should do nothing when no guides folder is present" {
	cd "${TEMP_DIR}/sc-build"
	mkdir .git
	export GIT_BIN="printing_git_with_remotes"

	run "${COPIED_SOURCES}"/update-guides.sh

	assert_success
	refute_output --partial "git"
}

@test "should commit and push latest guides" {
	cd "${TEMP_DIR}"
	mkdir .git
	export GIT_BIN="stubbed_git"
	export SPRING_GUIDES_REPO_ROOT="$( pwd )"
	export RELEASER_GIT_OAUTH_TOKEN="mytoken"

	run "${COPIED_SOURCES}"/update-guides.sh

	assert_success
	# change remote
	assert_output --partial "git remote set-url --push origin https://mytoken@foo.bar/baz.git"
	# commit and push
	assert_output --partial "git commit -m Updating guides"
	assert_output --partial "git push origin master"
	tree ${TEMP_DIR}
	# check the contents, old ones deleted, new ones present
	assert [ -f "${TEMP_DIR}/target/gs-contract-rest/ONE.adoc" ]
	assert [ -f "${TEMP_DIR}/target/gs-contract-rest/complete/COMPLETE.adoc" ]
	assert [ -f "${TEMP_DIR}/target/gs-contract-rest/initial/INITIAL.adoc" ]
	assert [ -f "${TEMP_DIR}/target/gs-contract-rest/test/TEST.adoc" ]
	assert [ ! -f "${TEMP_DIR}/target/gs-contract-rest/README.adoc" ]
}