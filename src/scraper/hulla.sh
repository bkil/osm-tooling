#!/bin/sh
get_postcodes() {
  local CF="cache/hulla/postcodes.csv"
  if ! [ -s "$CF" ]; then
    curl_hulla |
    form2csv > "$CF"
  fi
  sort -u "$CF"
}

# updates state for october_session cookie
get_streets() {
  local CF="cache/hulla/streets.$1.csv"
  if ! [ -s "$CF" ]; then
    local CFJ="cache/hulla/streets.$1.json"
    if ! [ -s "$CFJ" ]; then
      curl_hulla_ajax \
        --data-raw "district=$1" \
        -H 'X-OCTOBER-REQUEST-PARTIALS: ajax/publicPlaces' \
        -H 'X-OCTOBER-REQUEST-HANDLER: onSelectDistricts' \
        --cookie-jar "cache/hulla/october_session.txt" > "$CFJ"
    fi

    cat "$CFJ" |
    jq -r '."ajax/publicPlaces"' |
    form2csv > "$CF"
    [ -s "$CF" ] && rm "$CFJ"
  fi
  cat "$CF"
}

# URL-encoded place, reads october_session cookie
get_housenumbers() {
  local CF="cache/hulla/housenumbers.$2.$1.csv"
  if ! [ -s "$CF" ]; then
    local CFJ="cache/hulla/housenumbers.$2.$1.json"
    if ! [ -s "$CFJ" ]; then
      curl_hulla_ajax \
        --data-raw "publicPlace=$1" \
        -H 'X-OCTOBER-REQUEST-PARTIALS: ajax/houseNumbers' \
        -H 'X-OCTOBER-REQUEST-HANDLER: onSavePublicPlace' \
        --cookie "cache/hulla/october_session.txt" > "$CFJ"
    fi

    cat "$CFJ" |
    jq -r '."ajax/houseNumbers"' |
    form2csv |
    cut -d " " -f 1 > "$CF"
    [ -s "$CF" ] && rm "$CFJ"
  fi
  cat "$CF"
}

curl_hulla() {
  curl "$@" \
    "https://www.$DOMAIN.hu/hulladeknaptar" \
    -H 'User-Agent: User-Agent' \
    --compressed
  sleep 1
}

curl_hulla_ajax() {
  curl_hulla "$@" \
    -H 'X-Requested-With: XMLHttpRequest'
}

form2csv() {
  sed -nr 's~^.*<option value="([^"]+)">([^<]*)<.*~\1;\2~ ; T e; p; :e' |
  grep -v "^false;" |
  sed -r ":l; s~^([^;]*) ~\1%20~; t l" |
  sed -r "s~;~ ~"
}

main() {
  if [ -z "$DOMAIN" ]; then
    echo "error: DOMAIN unset"
    exit 1
  fi
  local PC PN SC SN OUT NONUM TMP
  TMP="cache/hulla/tmp.csv"
  NONUM="cache/hulla/all-hulla-streets.csv"
  OUT="cache/hulla/all-hulla-housenumbers.csv"
  mkdir -p "cache/hulla"
  rm "$NONUM" 2>/dev/null

  get_postcodes |
  while read PC PN; do
    echo "$PC" >&2
    get_streets "$PC" |
    while read SC SN; do
      get_housenumbers "$SC" "$PC" |
      sed "s~^~$PC;$PN;$SN;~" > "$TMP"

      if [ -s "$TMP" ]; then
        cat "$TMP"
      else
        echo "$PC;$PN;$SN" >> "$NONUM"
      fi
    done
  done > "$OUT"

  rm "$TMP"
  wc -l "$OUT" >&2
  wc -l "$NONUM" >&2
}

main "$@"
