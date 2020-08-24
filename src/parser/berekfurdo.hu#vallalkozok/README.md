#Berekfürdő

Save and prune these spreadsheets:
* http://www.berekfurdo.hu/?module=news&action=getfile&fid=214200 `kereskedelem.csv` (via http://www.berekfurdo.hu/?module=news&fname=nyilv )
* http://www.berekfurdo.hu/index.php?module=docs&action=getfile&id=4550 `szallas.csv`
* http://www.berekfurdo.hu/?module=news&action=getfile&fid=250849 `ipar.csv`

Save the output of `./vallalkozok2csv.sh` as `vallalkozas.csv`.

Add a few POI manually to `kozszfera.csv` from the website.

Concatenate all using LibreOffice by adding a new column for the filename.
