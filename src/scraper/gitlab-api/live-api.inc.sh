#!/bin/sh

git_get_subtrees() {
  local SERVER="$1"
  local PROJECT="$2"
  local BRANCH="$3"
  local SUBDIR="$4"
  curl \
    "https://$SERVER/api/v4/projects/$PROJECT/repository/tree?path=$SUBDIR&ref=$BRANCH&recursive=true"
}

git_get_blob_raw() {
  local SERVER="$1"
  local PROJECT="$2"
  local ID="$3"
  curl \
    "https://$SERVER/api/v4/projects/$PROJECT/repository/blobs/$ID/raw"
}

write_file() {
  cat > "$1"
}

create_dir() {
  mkdir "$@"
}
