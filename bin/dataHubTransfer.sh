#!/bin/bash
# Filename: dataHubTransfer.sh
#
# Description:
#   This script will search and incrementally download new products from a DHuS.
#
# The script is intended to be run in a cron job, e.g.:
# 10 * * * * /path-to-cronjob/dataHubTransfer.sh /path/to/workdir &>> /path/to/workdir/log/dataHubTransfer_$(date +\%Y\%m\%d).log
#
# Parameters:
#   Path to a writable working directory
# that has a file:
#   dataHubTransfer.properties
# containing the properties:
#   dhusUrl="https://code-de.org/dhus"
#   WGETRC=/path/to/.wgetrc (file with user=xxx and password=yyy of the account at the DHuS service)
#   basefilter="platformname:Sentinel-2 AND footprint:\"Intersects(POLYGON((5.9 47.2,15.2 47.2,15.2 55.1,5.9 55.1,5.9 47.2)))\""
#   outputPath=/tmp
#   lastIngestionDate=NOW-1DAY
#   batchSize=100
#   #MAXCACHESIZE=$((9 * 1000000)) ## in kbytes
#   #transferAction=/path/to/some/command/to/run/after/file/transfer
#
# Depends:
#   includes/singleton.sh
#   includes/error-handler.sh
SCRIPT_DIR=$(dirname $0)
. $SCRIPT_DIR/includes/log-handler.sh
 
WD=${1-}
if [ "$WD" == "" ]; then
  logerr "no working directory specified"
  exit 1
elif [ ! -d $WD ]; then
  logerr "no working directory $WD"
  exit 1
elif [ ! -r $WD/dataHubTransfer.properties ]; then
  logerr "missing $WD/dataHubTransfer.properties"
  exit 1
fi
log "Using working directory $WD"
 
# load the properties
. $WD/dataHubTransfer.properties
 
# singleton pattern
. $SCRIPT_DIR/includes/singleton.sh
 
# error handler: print location of last error and process it further
. $SCRIPT_DIR/includes/error-handler.sh
 
# ------------------------------------------------------------------
# check storage space
if [ "$MAXCACHESIZE" != "" ]; then
  cachesize=$(du -sk $outputPath |cut -f1)
  if (( $cachesize > $MAXCACHESIZE )); then
    log WARNING "cache full ($cachesize > max $MAXCACHESIZE kbyte), processing stopped"
    exit
  fi
fi
 
# keeps the latest ingestionDate of previous retrieval
lastDateHolder=$WD/lastFileDate
function keepLastFileDate {
  # remember date of this file for next query
  dateISO=$1
  dateNum=$(echo $dateISO | tr -d -- '-: .TZ' |cut -c1-12)
  echo -n $dateISO > $lastDateHolder
  touch -t $dateNum $lastDateHolder
}
 
# ------------------------------------------------------------------
log "starting with $dhusUrl"
 
# ------------------------------------------------------------------
# retransmit handling
TRANSFERHISTORY=$WD/transferHistory.txt
 
# ------------------------------------------------------------------
# error handling
DEFECTSHISTORY=$WD/defectsHistory.txt
function logDefect
{
  logerr "$2"
  echo "$(date '+%Y-%m-%dT%h:%m:%s') ingestion failed $1" >> $DEFECTSHISTORY
}
 
# ------------------------------------------------------------------
# prepare query filter
if [ -r $lastDateHolder ]; then
  log "Using $lastDateHolder"
  lastIngestionDate="$(cat $lastDateHolder)"
fi
# use now with a 30-second offset to ensure DHuS internal DB is up-to-date
condition="$basefilter AND ingestionDate:[$lastIngestionDate TO NOW-30SECONDS]"

log "Searching for new files with $condition"
 
# ------------------------------------------------------------------
# query for new data
export WGETRC
response=$(/usr/bin/wget --auth-no-challenge --no-check-certificate -q -O - "$dhusUrl/search?q=$condition&rows=$batchSize&orderby=ingestiondate asc" 2>&1 | cat) 
if [ "$?" -ne 0 ] || [ "${response:0:1}" != "<" ] ; then
  logerr "query failed: $response"
  exit 1
fi
files=$(echo $response \
  | xmllint --format --nowrap - \
  | egrep '"(identifier|ingestiondate|size|uuid)"' \
  | cut -d'>' -f2 | cut -d'<' -f1 \
  | xargs -n5 echo | tr ' ' ';'
)
 
count=$(echo $files | wc -w | tr -d ' ')
if [ $count == 0 ]; then
  log "Found nothing."
  exit 0;
fi
log "ingesting next $count products..."
 
# ------------------------------------------------------------------
# process the products found
index=0
for f in ${files[@]}
do
  # next index
  index=$((index+1))
 
  uuid=$(echo $f | cut -d';' -f5)
  safe=$(echo $f | cut -d';' -f1)
  ingestionDate=$(echo $f | cut -d';' -f2)
  size=$(echo $f | cut -d';' -f3-4 | tr ';' ' ')
  file="$outputPath/${safe}.SAFE.zip"
 
  # check if already retrieved
  if [[ -r "$file" && ( $size == $(stat -L --format='%s' "${file}") ) ]]; then
    log "[$index/$count] Skipping $f"
    keepLastFileDate $ingestionDate
    continue
  elif [ -r $TRANSFERHISTORY ] && [ $(grep -c $safe $TRANSFERHISTORY) -gt 0 ]; then
    log "[$index/$count] already transferred $safe"
    keepLastFileDate $ingestionDate
    continue
  elif [ -r $DEFECTSHISTORY ] && [ $(grep -c $safe $DEFECTSHISTORY) -gt 2 ]; then
    log WARNING "[$index/$count] Skipping previously defect $f"
    keepLastFileDate $ingestionDate
    continue
  else
    # retreive file
    log "[$index/$count] Reading $uuid $safe $ingestionDate $size"
    wget -q --auth-no-challenge --no-check-certificate -O "${file}_tmp" "$dhusUrl/odata/v1/Products('${uuid}')/\$value"
  fi
 
  # check ZIP integrity
  unzip -tqq "${file}_tmp" > /dev/null 2>&1 | cat
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    logDefect "$file" "transfered file contains errors, will retry in next round"
    exit
  else
    log "[$index/$count] Transferred $file $size bytes"
  fi
  
  # rename validated ZIP file
  mv "${file}_tmp" "${file}"
 
  # remember date of this file for next query
  keepLastFileDate $ingestionDate
 
  echo "$file" >> $TRANSFERHISTORY
 
  # --------------------------------------------------------------
  # execute transfer actions
  if [ "$transferAction" != "" ] && [ -x $transferAction ]; then
    $transferAction "$file"
  fi
 
done
 
log "Done."

