#!/bin/sh

main_get_git_subdirs() {
  OUT="out"
  SERVER="gitlab.gnome.org"
  get_projects |
  while read PROJECT; do
    local EPROJECT="`echo "$PROJECT" | url_escape`"
    get_subdirectories |
    while read SUBDIR; do
      git_get_subtrees "$SERVER" "$EPROJECT" "`echo "$SUBDIR" | url_escape`" |
      jq -r '.[] | "\(.id) \(.name)"' |
      while read ID FILENAME; do
        local LOCALFILE="$OUT/$SERVER/$PROJECT/$SUBDIR/$FILENAME"
        create_dir -p "`dirname "$LOCALFILE"`"
        echo "$SERVER $PROJECT $SUBDIR $FILENAME" >&2
        git_get_blob_raw "$SERVER" "$EPROJECT" "$ID" |
        write_file "$LOCALFILE"
      done
    done
  done
}

get_projects() {
cat << EOF
GNOME/gedit
EOF
}

get_subdirectories() {
  cat << EOF
help/C
help/hu
EOF
}

url_escape() {
  sed "
    s~/~%2F~g
  "
}
