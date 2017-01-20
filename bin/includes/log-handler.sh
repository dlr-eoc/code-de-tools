# log handler functions
function log() {
  echo "$(date +%Y-%m-%dT%H:%M:%SZ) $(if [[ $# -ne 2 ]]; then echo INFO; else echo $1; fi) ${BASH_SOURCE[1]##*/} ${2:-$1}"
}

function logerr() { 
  cat <<< "$(date +%Y-%m-%dT%H:%M:%SZ) ERROR ${BASH_SOURCE[1]##*/} $@" >&2
}
