#!/bin/sh
. `dirname "$(readlink -f "$0")"`/check-node-move.inc.sh

net_fetch_state() {
  wget -U- -O- --timeout=15 \
    "https://download.openstreetmap.fr/replication/europe/minute/state.txt"
#    "http://download.geofabrik.de/europe/hungary-updates/state.txt"
}

net_fetch_part() {
  wget -U- -O- --timeout=30 \
    "https://download.openstreetmap.fr/replication/europe/minute/$1/$2/$3.osc.gz"
#    "http://download.geofabrik.de/europe/hungary-updates/$1/$2/$3.osc.gz"
}

net_fetch_ids() {
  wget \
    -U- \
    -O - \
    --timeout=60 \
    --post-data 'data=%5Bout%3Acsv(%0A\
%3A%3A%22id%22%2C+\
%3A%3Alat%2C+\
%3A%3Alon%2C+\
place%2C+\
name%3B%0A\
false%3B+%22%3B%22)%5D%5Btimeout%3A25%5D%3B%0A\
area(id%3A3600021335)-%3E.searchArea%3B%0A\
node%5B%7E%22^place$%22%7E%22^(\
country|\
county|\
city|\
borough|\
town|\
village|\
hamlet\
)%22%5D(area.searchArea)%3B%0A\
out%3B' \
    'https://overpass-api.de/api/interpreter'
}

main() {
  local DATADIR
  readonly DATADIR="data"
  main_node_move || return 1
}

main "$@"
