#!/bin/bash
#
# Copyright (c) 2023, Island54.
#
# Licensed under BSD 2-Clause License. See LICENSE file for details.
#

#
# Usage:
#
# Set the executable permission on this script. Run it from the .minecraft instance root within a MultiMC instance.
#
# Pass the modpack zip path and filename as the only parameter.
#
#     e.g. ./install_modpack.sh ~/Downloads/Auto-TerraFirmaCraft+\(TFC+++Create\)-1.8.1.zip
#
# This probably works with other modpacks, but I've only tested it with ATFC.
#

DOWNLOAD=1
OVERRIDE=1

function fatal() {
  echo "error: $*" >&2
  exit 1
}

function require() {
  for requirement in $@; do
    if ! which "${requirement}" > /dev/null; then
      fatal "$requirement is required. Please make sure it is installed and on your path."
    fi
  done
}

require jq xargs wget rsync unzip basename sed printf

# Check if the script is being run from the MultiMC instance root directory
if [ ! -f "../instance.cfg" ]; then
    fatal "Please run this script from the MultiMC instance root directory."
fi

if [ -d "./overrides" ]; then
  fatal "There is an overrides directory in your instance. This suggests a misconfiguration on your part that prevents me from safely continuing."
fi

# Check if a zip file parameter is provided
if [ $# -ne 1 ]; then
    echo "usage: $0 <modpack>" >&2
    exit 1
fi

zip_file="$1"

# Check if the zip file exists
if [ ! -f "$zip_file" ]; then
    fatal "The specified zip file does not exist."
fi

function urldecode() {
  url_encoded="$1"
  printf '%b' "${url_encoded//%/\\x}"
}

function download() {
  MOD=$(basename $(wget --method=HEAD $1 2>&1 | grep '^Location: ' | tail -1 | sed -e 's/^Location: \([^ ]*\) .*/\1/'))
  echo -n "  $(urldecode "${MOD}")... "
  wget -q --content-disposition -P mods $1
  echo
}

set -e
if [[ ${DOWNLOAD} -ne 0 ]]; then
  echo "Fetching dependencies: "
  # Extract the manifest.json from the zip file, parse it, and fetch the mods.
  for url in $(unzip -p "$zip_file" manifest.json \
    | jq -r '.files[] | "https://www.curseforge.com/api/v1/mods/\(.projectID)/files/\(.fileID)/download"');
  do
    download $url
  done
  echo Done.
fi

if [[ ${OVERRIDE} -ne 0 ]]; then
  echo -n "Extracting overrides... "
  # Move the contents of the overrides directory while maintaining subtree structure
  unzip -o "$zip_file" 'overrides/*' -d . 2>&1 >/dev/null
  rsync -a --force --remove-source-files overrides/* .
  find overrides -type d -empty -delete
  [[ -d overrides ]] && fatal "overrides directory could not be fully merged for some reason."
  echo Done.
fi
