#!/bin/bash
# File: code-de-query-download.sh
#
# Description:
#   Performs an OpenSearch query and downloads the found products
#
# Note:
#   The use of the CODE-DE tools, online serivces and data is subject to the CODE-DE Terms & Conditions
#      https://code-de.org/en/terms/CODE-DE_Terms.pdf
#   Currently CODE-DE does not use authentication/authorization, so a login is not requried.
#
function usage {
  echo "USAGE:"
  echo "$0 -c|--condition=... [-b|--baseurl=https://catalog.code-de.org] [-l|--limit=50] [-p|--parallel=1]"
  echo "  --condition is the full OpenSearch query, for example:"
  echo "    -c 'parentIdentifier=EOP:CODE-DE:S2_MSI_L1C&startDate=2017-01-04T00:00:00.000Z&endDate=2017-01-04T23:59:59.999&bbox=5.9,47.2,15.2,55'"
  echo "  --baseurl of the CODE-DE services (default is https://catalog.code-de.org)"
  echo "  --limit the amount of products to be retrieved (default=50, max=500)"
  echo "  --parallel count of retrievals, WARNING: do not overload your system and network (the server might limit you to 2 or 4 parallel downloads)"
  echo ""
  echo "Output products are placed in the current directory."
  echo ""
  exit 1;
}

#defaults
baseUrl=https://catalog.code-de.org
batchSize=50
parallel=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    -c|--condition) condition="$2"; shift 2;;
    -b|--baseurl)   baseUrl="$2"; shift 2;;
    -l|--limit)     limit="$2"; shift 2;;
    -p|--parallel)  parallel="$2"; shift 2;;

    -c=*|--condition=*) condition="${1#*=}"; shift 1;;
    -b=*|--baseurl=*)   baseUrl="${1#*=}"; shift 1;;
    -l=*|--limit=*)     limit="${1#*=}"; shift 1;;
    -p=*|--parallel=*)  parallel="${1#*=}"; shift 1;;

    *) echo "Unknown option '$1'"; usage; exit;;
  esac
done
 
if [ "$condition" == "" ]; then
  echo "ERROR: no condition defined!"
  echo ""
  usage
  exit 1
fi
echo "Running query with $condition"

# expand the base URL
searchUrl=$baseUrl/opensearch/request/?httpAccept=application/atom%2Bxml

# execute query and extract the dwnload URL list
urls=$(curl -s "${searchUrl}&${condition}&maximumRecords=${batchSize}" | xmllint --xpath '//*[local-name()="link" and @title="Download"]/@href' - |sed -e 's/ *href="//g' | tr '"' '\n' )

count=$(echo $urls | wc -w | tr -d ' ')
if [ $count = 0 ]; then
  echo "No products found."
  exit
else
  echo "Found $count products, downloading..."
fi

# download them all to the local directory
echo $urls | xargs -n1 -P${parallel} curl -O

