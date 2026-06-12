#!/bin/bash
# Generates the showcase library using Librarian.
set -ex

echo "******** Generating Showcase ********"

readonly ROOT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../.."

# Read the pinned version from librarian.yaml
LIBRARIAN_VERSION=$(grep "^version:" "${ROOT_DIR}/librarian.yaml" | cut -d ':' -f 2 | xargs)
if [ -z "${LIBRARIAN_VERSION}" ]; then
  echo "Warning: Could not find version in librarian.yaml, falling back to latest"
  LIBRARIAN_VERSION="latest"
fi

# Helper function to run the pinned version of Librarian
run_librarian() {
  go run "github.com/googleapis/librarian/cmd/librarian@${LIBRARIAN_VERSION}" "$@"
}

# Ensure Librarian's tools (gapic generator, formatters, synthtool) are installed.
# We run this in the repo root where librarian.yaml is located.
pushd "${ROOT_DIR}"
run_librarian install
popd

# Add the installed tools to PATH so Librarian's generate step can find them
export PATH="$HOME/.cache/librarian/bin/java_tools/bin:$PATH"

replace="false"
if [[ "$1" == "--replace" ]]; then
  replace="$2"
fi

if [[ "${replace}" == "true" ]]; then
  pushd "${ROOT_DIR}"
  run_librarian generate showcase
  popd
else
  export generated_files_dir=$(mktemp -d)
  echo "${generated_files_dir}/java-showcase" > "${ROOT_DIR}/generated-showcase-location"
  
  # Prepare temp folder by symlinking most things, but copying pom.xml and gapic-libraries-bom
  pushd "${ROOT_DIR}"
  for file in *; do
    if [[ "${file}" != "java-showcase" && "${file}" != "pom.xml" && "${file}" != "gapic-libraries-bom" ]]; then
      ln -s "${ROOT_DIR}/${file}" "${generated_files_dir}/${file}"
    fi
  done
  # Copy pom.xml, gapic-libraries-bom, and java-showcase (real copies)
  # to prevent librarian from modifying the real POMs, and to allow modifying showcase.
  cp -r "${ROOT_DIR}/pom.xml" "${ROOT_DIR}/gapic-libraries-bom" "${ROOT_DIR}/java-showcase" "${generated_files_dir}/"
  popd
  
  # Run librarian in the temp folder
  pushd "${generated_files_dir}"
  run_librarian generate showcase
  popd
fi

echo "generated showcase library"
