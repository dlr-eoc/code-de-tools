# error handler: print location of last error and process it further
function error_handler() {
  LASTLINE="$1" # argument 1: last line of error occurence
  LASTERR="$2"  # argument 2: error code of last command
  echo "$(date +%Y-%m-%dT%H:%M:%SZ) ERROR in ${0} (line ${LASTLINE} exit status: ${LASTERR})"
  exit $LASTERR
}
# abort and log errors
set -e
trap 'error_handler ${LINENO} $?' ERR
