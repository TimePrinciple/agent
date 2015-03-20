#!/bin/bash
set -e

if [[ "$GITHUB_RELEASE_ACCESS_TOKEN" == "" ]]; then
  echo "Error: Missing \$GITHUB_RELEASE_ACCESS_TOKEN"
  exit 1
fi

echo '--- Getting agent version from build meta data'

export FULL_AGENT_VERSION=$(buildkite-agent meta-data get "agent-version")
export AGENT_VERSION=$(echo $FULL_AGENT_VERSION | sed 's/buildkite-agent version //')

echo "Full agent version: $FULL_AGENT_VERSION"
echo "Agent version: $AGENT_VERSION"

echo '--- Downloading binaries'

rm -rf pkg
mkdir -p pkg
buildkite-agent artifact download "pkg/*" .

function build() {
  echo "--- Building release for: $1"

  ./scripts/utils/build-github-release.sh $1 $AGENT_VERSION
}

# Export the function so we can use it in xargs
export -f build

# Make sure the releases directory is empty
rm -rf releases

# Loop over all the binaries and build them
ls pkg/* | xargs -I {} bash -c "build {}"

echo "Version is $FULL_AGENT_VERSION"

export GITHUB_RELEASE_REPOSITORY="buildkite/agent"

if [[ "$AGENT_VERSION" == *"beta"* || "$AGENT_VERSION" == *"alpha"* ]]; then
  # Beta versions of the agent will have the build number at the end of them
  # like this:
  #
  #    buildkite-agent version 1.0-beta.7.227
  #
  # We don't want the build numbers for GitHub releases, so this command will
  # drop them.
  GITHUB_AGENT_VERSION=$(echo $AGENT_VERSION | sed -E 's/\.[0-9]+$//')

  echo "--- 🚀 $GITHUB_AGENT_VERSION (prerelease)"

  buildkite-agent meta-data set github_release_type "prerelease"
  buildkite-agent meta-data set github_release_version $GITHUB_AGENT_VERSION

  github-release "v$GITHUB_AGENT_VERSION" releases/* --prerelease
else
  echo "--- 🚀 $AGENT_VERSION"

  buildkite-agent meta-data set github_release_type "stable"
  buildkite-agent meta-data set github_release_version $AGENT_VERSION

  github-release "v$AGENT_VERSION" releases/*
fi
