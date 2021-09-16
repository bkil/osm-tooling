#!/bin/sh

main_get_git_subdirs() {
  OUT="out"
  SERVER="gitlab.gnome.org"
  get_projects |
  while read PROJECT BRANCH; do
    local EPROJECT="`echo "$PROJECT" | url_escape`"
    get_subdirectories |
    while read SUBDIR; do
      git_get_subtrees "$SERVER" "$EPROJECT" "`echo "$BRANCH" | url_escape`" "`echo "$SUBDIR" | url_escape`" |
      jq -r '.[] | "\(.id) \(.type) \(.path)"' |
      while read ID TYPE FILENAME; do
        [ "$TYPE" = "blob" ] || continue
        local LOCALFILE="$OUT/$SERVER/$PROJECT/$FILENAME"
        [ -e "$LOCALFILE" ] && continue
        create_dir -p "`dirname "$LOCALFILE"`"
        echo "$SERVER $PROJECT $FILENAME" >&2
        git_get_blob_raw "$SERVER" "$EPROJECT" "$ID" |
        write_file "$LOCALFILE"
      done
    done
  done
}

get_projects() {
cat << EOF
GNOME/gedit gnome-40
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
