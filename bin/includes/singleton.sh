# bash include file implementing singleton pattern (script runs only once in parallel)
PIDFILE=$WD/pid
LOCK=$WD/lock

# check for existing lock (directory) 
mkdir ${LOCK} >> /dev/null 2>&1
if [ $? != 0 ]; then 
  pid=$(cat $PIDFILE)
  scriptname="${0##*/}"
  if [ -r /proc/$pid ] && [ $(grep -c "$scriptname" /proc/$pid/cmdline) == 1 ]; then
    echo -e "$(date +%Y-%m-%dT%H:%M:%SZ) WARNING: an istance of \"$scriptname\" is running with PID=$pid (if it isn't running: delete the lockdir ${LOCK})"
    exit 
  fi
fi

echo $$ > $PIDFILE

# ensure lock is removed when exiting
trap "rm -fr ${LOCK} ${PIDFILE}" EXIT
