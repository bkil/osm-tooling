#!/bin/sh

cat_coverage() {
  local JSON="$1"
  echo "<div id=css-coverage>"
  jq \
    --raw-output \
    '.progress | @html "Coverage is \(.percentage)% as of \(.date). House numbers in reference: \(.reference), house numbers in OSM: \(.osm)."' "$JSON"
  echo "</div>"
}

cat_charts_css() {
  cat_charts "$1" "csv2html_charts_css"
}

cat_charts() {
  local JSON="$1"
  local CSV2HTML="${2-csv2html}"

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
    $CSV2HTML "$STAT" "$CAPTION" "$X" "$Y"
  done
}

cat_chart_css_fixup() {
  cat << EOF
  .charts-css {
    height: 30em;
    --color: #0f0;
  }
  .charts-css.column.show-labels {
    --labels-size: 4rem;
  }
  .charts-css.area.show-labels tbody tr th {
    align-items: flex-end;
  }
EOF
}

csv2html() {
  local STAT="$1"
  local CAPTION="$2"
  local X="$3"
  local Y="$4"

  cat <<EOF |
<table class=barchart id=css-barchart-$STAT>
  <caption>$STAT - $CAPTION</caption>
  <thead><tr><th>$X</th><th>$Y</th></tr></thead>
EOF
  sed "s~_~ ~g"

  sed -r "s~^([^ ]+) +([^ ]+) +(.*)$~  <tr><td>\3</td><td style=height:\1%>\2</td></tr>~"

  cat << EOF
</table>
EOF
}

csv2html_charts_css() {
  local STAT="$1"
  local CAPTION="$2"
  local X="$3"
  local Y="$4"

  local COMMON="show-heading show-labels show-primary-axis show-4-secondary-axes show-data-axes"
  local COLUMN="charts-css column data-spacing-8 $COMMON"
  local AREA="charts-css area $COMMON"

  if
    echo "$STAT" | grep -qE "dailytotal|monthlytotal"
  then
    local KIND="$AREA"
  else
    local KIND="$COLUMN"
  fi

  cat <<EOF |
<table class="$KIND" id=css-charts-css-$STAT>
  <caption>$STAT - $CAPTION</caption>
  <thead><tr><th scope=col>$X</th><th scope=col>$Y</th></tr></thead>
EOF
  sed "s~_~ ~g"

  if [ "$KIND" = "$COLUMN" ]; then
    awk '{$1 = $1 / 100; print}' |
    sed -r "s~^([^ ]+) +([^ ]+) +(.*)$~  <tr><th scope=row>\3</th><td style=--size:\1>\2</td></tr>~"
  else
    awk '
      {
        $1 = $1 / 100;
        if (last != "") {
          print last " " $0;
        }
        last = $1;
      }
    ' |
    sed -r "s~^([^ ]+) +([^ ]+) +([^ ]+) +(.*)$~  <tr><th scope=row>\4</th><td style=\"--start:\1;--size:\2\">\3</td></tr>~"
  fi

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
