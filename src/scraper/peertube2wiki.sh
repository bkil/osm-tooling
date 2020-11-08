#!/bin/sh

# Output used here:
# https://wiki.openstreetmap.org/wiki/Hungary/videok

main() {
  CACHE="cache/"
  mkdir -p "$CACHE" || exit 1

    cat <<EOF
{| class="wikitable sortable" border="1" cellspacing="0" cellpadding="2"
! Készült
! Feltöltve
! Cím
! Kategória
! Címkék
! Licenc
! Másodperc
! Feltöltő
! Leírás
EOF

  list_channels |
  while read CHAN; do
    proc_chan "$CHAN"
  done

  cat <<EOF
|}
EOF
}

wget2() {
  local OUT="$1"
  shift 1
  [ -f "$OUT" ] && return
  sleep 1
  wget \
    --quiet \
    --user-agent="github.com/bkil/osm-tooling $ME $MTIME" \
    --no-clobber \
    --output-document="$OUT" \
    "$@"
}

proc_chan() {
  local CHAN="$1"
  local ME="`basename "$0"`"
  local MTIME="`get_mtime "$ME"`"
  local OUTSEARCH="$CACHE/channel-$CHAN.json"
  local TMP="tmp.1.json"
  local TMP2="tmp.2.json"
  wget2 \
    "$OUTSEARCH" \
    "https://tube.grin.hu/api/v1/video-channels/$CHAN/videos?start=0&count=100&sort=-publishedAt"

# TODO:
# https://tube.grin.hu/api/v1/videos/$ID/captions
# https://tube.grin.hu/api/v1/videos/$ID/description

  json2wiki_table < "$OUTSEARCH" |
  tee "$TMP" > "$TMP2"
  sed -nr "s~^\| TAGS:https://tube.grin.hu/videos/watch/(.*)$~\1~ ; T e; p; :e" "$TMP2" |
  while read ID; do
    local OUTMETA="$CACHE/video-$ID.meta.json"
    wget2 \
      "$OUTMETA" \
      "https://tube.grin.hu/api/v1/videos/$ID"
    local TAGS="`jq --raw-output '.tags | @text' "$OUTMETA" | sed 's~["[]~~g; s~]~~g ; s~,~& ~g'`"
    sed -r --in-place "s~TAGS:https://tube.grin.hu/videos/watch/$ID~$TAGS~" "$TMP"
  done

  cat "$TMP"
  rm "$TMP" "$TMP2"
}

json2wiki_table() {
  jq \
  --raw-output \
'.data[] |'\
'@html '\
'"'\
'|-\n'\
'| \(.originallyPublishedAt // "")\n'\
'| \(.publishedAt)\n'\
'| [https://tube.grin.hu/videos/watch/\(.uuid) \(.name)]\n'\
'| \(.category.label // "")\n'\
'| TAGS:https://tube.grin.hu/videos/watch/\(.uuid)\n'\
'| \(.licence.label // "")\n'\
'| \(.duration)\n'\
'| \(.account.displayName)\n'\
'| \(.description // "")\n'\
'"' |
  sed '
    s~\"~"~g
    '
}

get_mtime() {
  ls -l --full-time "$@" |
  tr -s " " |
  cut -d " " -f 6-7
}

list_channels() {
  cat << EOF
openstreetmap
openstreetmap_hour
ottermage
openstreetmap_hungary
linux
EOF
}

example_search_result_json() {
cat << EOF
{
  "total": 5,
  "data": [
    {
      "id": 9360,
      "uuid": "a827b7ee-2db3-4848-8103-f9ad7b57f4f9",
      "name": "bkil: OSM Mindeközben és az OSM RSS juggler #MagyarOSM",
      "category": {
        "id": 13,
        "label": "Education"
      },
      "licence": {
        "id": 2,
        "label": "Attribution - Share Alike"
      },
      "language": {
        "id": "hu",
        "label": "Hungarian"
      },
      "privacy": {
        "id": 1,
        "label": "Public"
      },
      "nsfw": false,
      "description": "[wiki](https://wiki.openstreetmap.org/wiki/Hungary/Tal%C3%A1lkoz%C3%B3k/2020-09-28-havi-osm) Automatizmusokkal térképjegyzetek, wiki szerkesztések, levlista üzenetek, Mastodon hírek és egyéb magyar vonatkozású aktivitások figyelése az [OSM-hu mind...",
      "isLocal": true,
      "duration": 335,
      "views": 3,
      "likes": 0,
      "dislikes": 0,
      "thumbnailPath": "/static/thumbnails/a827b7ee-2db3-4848-8103-f9ad7b57f4f9.jpg",
      "previewPath": "/lazy-static/previews/a827b7ee-2db3-4848-8103-f9ad7b57f4f9.jpg",
      "embedPath": "/videos/embed/a827b7ee-2db3-4848-8103-f9ad7b57f4f9",
      "createdAt": "2020-10-26T01:19:25.543Z",
      "updatedAt": "2020-11-04T20:29:29.752Z",
      "publishedAt": "2020-10-26T01:19:31.604Z",
      "originallyPublishedAt": "2020-09-28T18:30:00.000Z",
      "account": {
        "id": 139,
        "name": "bkil",
        "displayName": "bkil",
        "url": "https://tube.grin.hu/accounts/bkil",
        "host": "tube.grin.hu",
        "avatar": null
      },
      "channel": {
        "id": 1082,
        "name": "openstreetmap_hungary",
        "displayName": "OpenStreetMap_Hungary",
        "url": "https://tube.grin.hu/video-channels/openstreetmap_hungary",
        "host": "tube.grin.hu",
        "avatar": null
      }
    }
  ]
}
EOF
}

main "$@"
