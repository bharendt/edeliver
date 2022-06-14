#!/usr/bin/env bash
# Test building a tar release using the echo server from
# https://github.com/xduludulu/erlang.eco
set -e -o pipefail

GIT_URL="${GIT_URL:-"https://github.com/xduludulu/erlang.eco"}"
GIT_REF="16da11b"
RELEASE_VERSION="0.1.0"
APP="eco"
BASE_DIR="$( cd "${0%/*}/../.." && pwd -P )"
TESTS_DIR="$( cd "${0%/*}" && pwd -P )"
DEFAULT_PROJECT_DIR="${BASE_DIR}/.test/echo-server-mix"
BRANCH_NAME="mix-release"
EDELIVER="${BASE_DIR}/bin/edeliver"
PROJECT_DIR="${PROJECT_DIR:-"$DEFAULT_PROJECT_DIR"}"
  
_info() {
  echo $@
}

_error() {
  echo "" >&2
  echo $@ >&2
  echo "" >&2
  exit 1
}

if [ ! -x "$EDELIVER" ]; then
  _error "edeliver executable not found at '$EDELIVER'!"
fi

if [ ! -d "$PROJECT_DIR" ]; then
  _info "Creating project dir '$PROJECT_DIR'"
  mkdir -p "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"
_info "Cloning $GIT_URL"
git clone "$GIT_URL" .
_info "Checking out $GIT_REF"
git checkout "$GIT_REF"

_info "Applying distillery config…"
# copy mix.exs and remove rebar.config
cp "${TESTS_DIR}/../configs/mix-elixir.exs" "${PROJECT_DIR}/mix.exs"
git rm "${PROJECT_DIR}/rebar.config"

# commit new configs
git add "${PROJECT_DIR}/mix.exs"
git config user.email "edeliver-test@github.com"
git config user.name "Edeliver Test"
git commit -m "Add distillery mix file"
git branch -d "$BRANCH_NAME" 2>/dev/null || :
git checkout -b "$BRANCH_NAME"

GIT_REF="$(git rev-parse --short HEAD)"

_info "Building release…"
BUILD_HOST="docker" \
APP="$APP" \
BUILD_AT="/echo-server" \
BUILD_USER="root" \
MIX_ENV="prod" \
USING_DISTILLERY="false" \
DOCKER_BUILD_IMAGE="elixir:1.11.4" \
"$EDELIVER" build release --verbose --branch="$BRANCH_NAME"

_info ""
_info "Checking whether TAR was built successfully…"
ls -al "${PROJECT_DIR}/.deliver/releases/${APP}_${RELEASE_VERSION}.release.tar.gz"
if [ -f "${PROJECT_DIR}/.deliver/releases/${APP}_${RELEASE_VERSION}.release.tar.gz" ]; then
  _info "TAR was built successfully"
  echo "release_version=${RELEASE_VERSION}-${GIT_REF}" >> $GITHUB_ENV
else
  _error "Building TAR failed!"
fi