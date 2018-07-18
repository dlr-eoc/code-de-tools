#!/bin/bash
# Filename: code-de-transfer.sh
#
# Description:
#   This script will search and incrementally download new products from CODE-DE.
#
# The script is intended to be run in a cron job, e.g.:
# 10 * * * * /path-to-cronjob/code-de-transfer.sh /path/to/workdir &>> /path/to/workdir/log/code-de-transfer_$(date +\%Y\%m\%d).log
#
# Parameters:
#   Path to a writable working directory
# that has a file:
#   code-de-transfer.properties
# containing the properties:
#   WGETRC=/path/to/.wgetrc (file with user=xxx and password=yyy of the CODE-DE download account)
#   basefilter="parentIdentifier=EOP:CODE-DE:S2_MSI_L1C&geometry=POLYGON((5.9 47.2,15.2 47.2,15.2 55.1,5.9 55.1,5.9 47.2))"
#   lastIngestionDate=2018-01-01T00:00:00.000
#   outputPath=/tmp
#   batchSize=100
#   #queryUrl="https://catalog.code-de.org/opensearch/request"
#   #MAXCACHESIZE=$((9 * 1000000)) ## in kbytes
#   #transferAction=/path/to/some/command/to/run/after/file/transfer
#
# Depends:
#   includes/singleton.sh
#   includes/error-handler.sh
SCRIPT_DIR=$(dirname $0)
. $SCRIPT_DIR/includes/log-handler.sh

# defaults
queryUrl='https://catalog.code-de.org/opensearch/request/request'

# check working directory and load properties 
WD=${1-}
if [ "$WD" == "" ]; then
  logerr "no working directory specified"
  exit 1
elif [ ! -d $WD ]; then
  logerr "no working directory $WD"
  exit 1
elif [ ! -r $WD/code-de-transfer.properties ]; then
  logerr "missing $WD/code-de-transfer.properties"
  exit 1
fi
log "Using working directory $WD"
 
# load the properties
. $WD/code-de-transfer.properties
 
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
log "starting with $queryUrl"
 
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
condition="$basefilter&creationDate=[$lastIngestionDate"

log "Searching for new files with $condition"
 
# ------------------------------------------------------------------
# query for new data
export WGETRC
response=$(/usr/bin/wget --auth-no-challenge --no-check-certificate -q -O - "$queryUrl?httpAccept=application/sru%2Bxml&recordSchema=om&startRecord=1&maximumRecords=$batchSize&$condition&sortBy=creationDate&sortDir=ASC" 2>&1 | cat) 
if [ "$?" -ne 0 ] || [ "${response:0:1}" != "<" ] ; then
  logerr "query failed: $response"
  exit 1
fi
# the following xmllint, sed and awk combination ensures proper parsing and order of attributes in output
files=$(echo $response \
  | xmllint --xpath "//*[local-name()='timePosition' or local-name()='ProductInformation' or local-name()='Size' or local-name()='identifier']" - \
  | tr '<' '\n' | egrep -v '^/' | egrep 'timePosition|href|size|identifier' | sed -e 's/uom=".*"//' | tr '=' '>' | tr -d '"' | cut -d'>' -f2 | paste -d';' - - - -
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
 
  ingestionDate=$(echo $f | cut -d';' -f1)
  downloadUrl=$(echo $f | cut -d';' -f2)
  size=$(echo $f | cut -d';' -f3)
  id=$(echo $f | cut -d';' -f4)
  id=${id##*:}
  file="$outputPath/${id##*/}.SAFE.zip"
 
  # check if already retrieved
  if [[ -r "$file" && ( $size == $(stat -L --format='%s' "${file}") ) ]]; then
    log "[$index/$count] Skipping $f"
    keepLastFileDate $ingestionDate
    continue
  elif [ -r $TRANSFERHISTORY ] && [ $(grep -c $id $TRANSFERHISTORY) -gt 0 ]; then
    log "[$index/$count] already transferred $id"
    keepLastFileDate $ingestionDate
    continue
  elif [ -r $DEFECTSHISTORY ] && [ $(grep -c $id $DEFECTSHISTORY) -gt 2 ]; then
    log WARNING "[$index/$count] Skipping previously defect $f"
    keepLastFileDate $ingestionDate
    continue
  else
    # retreive file
    log "[$index/$count] Reading $downloadUrl $ingestionDate $size"
    wget -q --auth-no-challenge --no-check-certificate -O "${file}_tmp" "$downloadUrl"
  fi

  # check size
  if [[ $size != $(stat -L --format='%s' "${file}_tmp") ]]; then
    logDefect "$file" "size mismatch $file $size <> $(stat -L --format='%s' '${file}_tmp')"
    exit
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
 
  echo "$id" >> $TRANSFERHISTORY
 
  # --------------------------------------------------------------
  # execute transfer actions
  if [ "$transferAction" != "" ] && [ -x $transferAction ]; then
    $transferAction "$file"
  fi
 
done
 
log "Done."
