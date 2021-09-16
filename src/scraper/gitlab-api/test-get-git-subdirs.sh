#!/bin/sh

. `dirname "$0"`/get-git-subdirs.inc.sh

git_get_subtrees() {
  echo git_get_subtrees "$@" >&2
  cat <<EOF
[{"id": "6b0bd052fede796f43abed5fc4fd1d60d1934b9b", "name": "gedit-plugins-doc-stats.page", "type": "blob",    "path": "gedit-plugins-doc-stats.page", "mode": "100644"}]
EOF
}

git_get_blob_raw() {
  echo git_get_blob_raw "$@" >&2
  cat << EOF
hello "$@"
EOF
}

write_file() {
  echo "write_file $1 content: `cat`" >&2
}

create_dir() {
  echo mkdir "$@" >&2
}

main_get_git_subdirs "$@"
