#!/bin/sh

cat_coverage() {
  local JSON="$1"
  echo "<div id=css-coverage>"
  jq \
    --raw-output \
    '.progress | @html "Coverage is \(.percentage)% as of \(.date). House numbers in reference: \(.reference), house numbers in OSM: \(.osm)."' "$JSON"
  echo "</div>"
}

cat_charts() {
  local JSON="$1"
  cat <<EOF |
daily New_house_numbers,_last_2_weeks,_as_of_2021-03-15 During_this_day New_house_numbers
dailytotal All_house_numbers,_last_2_weeks,_as_of_2021-03-15 At_the_start_of_this_day All_house_numbers
monthly New_house_numbers,_last_year,_as_of_2021-03-15 During_this_month New_house_numbers
monthlytotal All_house_numbers,_last_year,_as_of_2021-03-15 Latest_for_this_month All_house_numbers
topusers Top_house_number_editors,_as_of_2021-03-15 User_name Number_of_house_numbers_last_changed_by_this_user
topcities Top_edited_cities,_as_of_2021-03-15 City_name Number_of_house_numbers_added_in_the_past_30_days
usertotal Number_of_house_number_editors,_as_of_2021-03-15 All_editors Number_of_editors,_at_least_one_housenumber_is_last_changed_by_these_users
EOF
  while read STAT CAPTION X Y
  do
    get_csv "$STAT" "$JSON" |
    csv2html "$STAT" "$CAPTION" "$X" "$Y"
  done
}

csv2html() {
  local STAT="$1"
  local CAPTION="$2"
  local X="$3"
  local Y="$4"

  cat <<EOF |
<table class=barchart id=css-$STAT>
  <caption>$STAT - $CAPTION</caption>
  <thead><tr><th>$X</th><th>$Y</th></tr></thead>
EOF
  sed "s~_~ ~g"

  sed -r "s~^([^ ]+) +([^ ]+) +(.*)$~  <tr><td>\3</td><td style=height:\1%>\2</td></tr>~"

  cat << EOF
</table>
EOF
}

get_csv() {
  local STAT="$1"
  local JSON="$2"

  local TMP="out/stat.tmp.txt"

  jq --raw-output "
    .$STAT[] |
    @html \"\(.[1]) \(.[0])\"
    " "$JSON" |
  tee "$TMP" |
  awk '
    {
      if ((u == "") || ($1<u))
        u = $1;
      if ((u == "") || ($1>v))
        v = $1;
    }
    END {
      print u " " v
    }
    ' |
  {
    read U V
    awk -vu="$U" -vv="$V" '{
      percent = 10 + 90*($1-u) / (v - u)
      print percent " " $0
    }' "$TMP"
  }
}
