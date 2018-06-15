# code-de-tools

Copernicus Data-access and Expoitation platform for Germany (CODE-DE) - user tools

## Description

This tools package publishes several scripts, examples and utilities to automate queries and data retrieval from the CODE-DE offerings.

The CODE-DE Platform provides standardized interfaces for dataset discovery, Earth-Observation product filtered searches and download.

## Contents

The scripts are located in the `bin/` subdirectory. The script header contains instructions on how to use. For convenience the usage help is listed below.

### code-de-query-download.sh 

Performs an OpenSearch query and downloads the found products.
```
USAGE:

./code-de-query-download.sh -c|--condition=... [-b|--baseurl=https://catalog.code-de.org] [-o|--curlOpts=curl-options] [-l|--limit=50] [-p|--parallel=1] [-n|--noTransfer]
  --condition is the full OpenSearch query, for example:
    -c 'parentIdentifier=EOP:CODE-DE:S2_MSI_L1C&startDate=2018-06-04T00:00:00.000Z&endDate=2018-06-04T23:59:59.999&bbox=5.9,47.2,15.2,55'
  --user in the form username:password (alternatively use --curlOpts='--netrc-file...myNetRc...file'
  --baseurl of the CODE-DE services (default is https://catalog.code-de.org)
  --curlOpts allos specifying special curl options like -o='--progress-bar --netrc-file=...myNetRc...file'
  --limit the amount of products to be retrieved (default=50, max=500)
  --parallel count of retrievals, WARNING: do not overload your system and network (the server might limit you to 2 or 4 parallel downloads)
  --noTransfer to test the query
```
Output products are placed in the current directory.

#### Change History
2018-06-15 Enhanced with options --user, --curlOptions and --noTransfer

Note: when using a .netrc file with ```--curlOptions```, make sure you include ```--cookie-jar``` and ```--location-trusted``` options.

### dataHubTransfer.sh 

This script will search and incrementally download new products from a DHuS.

The script is intended to be run in a cron job, e.g.:
```
  10 * * * * /path-to-cronjob/dataHubTransfer.sh /path/to/workdir &>> /path/to/workdir/log/dataHubTransfer_$(date +\%Y\%m\%d).log
```

The path to a writable working directory must contain a file:
```
  dataHubTransfer.properties
```

containing the properties:
```
  dhusUrl="https://code-de.org/dhus"
  WGETRC=/path/to/.wgetrc (file with user=xxx and password=yyy)
  basefilter="platformname:Sentinel-2 AND footprint:\"Intersects(POLYGON((5.9 47.2,15.2 47.2,15.2 55.1,5.9 55.1,5.9 47.2)))\""
  outputPath=/tmp
  lastIngestionDate=NOW-1DAY
  batchSize=100
  #MAXCACHESIZE=$((9 * 1000000)) ## in kbytes
  #transferAction=/path/to/some/command/to/run/after/file/transfer
```
Note: properties above prefixed with `#` are optional.

## Installation

Place the script package `bin/` contents somewhere on your PATH. The scripts require bash, 
wget, curl and a few common shell utilities.


## License

See the LICENSE.txt file.
