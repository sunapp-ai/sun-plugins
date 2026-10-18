#!/usr/bin/env bash
# Upload a local file to SUN with a one-time link from create_source_file_upload.
#
# Usage: SUN_UPLOAD_TOKEN=<upload_token> upload_source_file.sh <local-file> <upload_url>
#
# Prints SUN's JSON response; its file_id goes in create_audio_course's
# file_ids. Each link works once: on failure, ask SUN for a new link rather
# than retrying with the same token.
#
# The token comes from the environment and reaches curl on stdin, so it never
# appears in a process listing; upload_url must be SUN's own upload endpoint,
# so a misdirected call cannot send a local file anywhere else.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: SUN_UPLOAD_TOKEN=<upload_token> $(basename "$0") <local-file> <upload_url>" >&2
  exit 2
fi

file=$1
url=$2
token=${SUN_UPLOAD_TOKEN:-}

if [ ! -f "$file" ] || [ ! -r "$file" ]; then
  echo "error: cannot read file: $file" >&2
  exit 2
fi
# [[ =~ ]] anchors to the whole string; grep would accept a token whose first
# line is valid and smuggle the rest in as an extra header.
token_re='^[A-Za-z0-9_-]{32,128}$'
if [[ ! $token =~ $token_re ]]; then
  echo "error: set SUN_UPLOAD_TOKEN to the upload_token SUN returned" >&2
  exit 2
fi
url_re='^https://api\.sunapp\.ai/mcp/uploads$'
if [[ ! $url =~ $url_re ]]; then
  echo "error: upload_url must be the SUN upload URL that create_source_file_upload returned" >&2
  exit 2
fi

name=$(basename "$file")
# curl's -F syntax treats ';' and ',' in a bare path as separators, and a
# quoted value must escape '"' and '\'. Quoting both the path and the
# advertised filename keeps names such as "Book (1).pdf" intact.
escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

printf 'Authorization: Bearer %s\n' "$token" |
  curl --silent --show-error --fail-with-body \
    --request POST \
    --header @- \
    --form "file=@\"$(escape "$file")\";filename=\"$(escape "$name")\"" \
    "$url"
echo
