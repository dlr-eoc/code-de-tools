# Notes on CODE-DE search and download interfaces

The following automation interfaces are described next:
* Product searches
* Download products
* Download a whole directory
* Incremental download

## Product searches

The simplest way of finding data products in CODE-DE is using OpenSearch queries. 
The following example demonstrates an OpenSearch URL with a time specification of one day and an 
area of interest (AOI) over Germany, OpenSearch URL example:

  https://catalog.code-de.org/opensearch/request/?httpAccept=application/atom%2Bxml&parentIdentifier=EOP:CODE-DE:S2_MSI_L1C&startDate=2017-01-04T00:00:00.000Z&endDate=2017-01-04T23:59:59.999Z&bbox=5.9,47.2,15.2,55

Paging can be achieved by adding the parameters ```&startPage=1``` or ```&startRecord=1``` to the URL 
and you can specify the page size with ```&maximumRecords=100``` :warning: the default is 50 and the maximum is 500). 
The full OpenSearch description document with the search templates and parameters can be retrieved with 
the URL 

  https://catalog.code-de.org/opensearch/description.xml?parentIdentifier=EOP:CODE-DE:S2_MSI_L1C]

for example to locate the ```&cloudCover=[0,20]``` parameter.

:warning: Note: the CODE-DE OpenSeach Service does not require authentication.

:bulb: Note: you can extract an prepared OpenSearch query from the CODE-DE Catalog Client by setting-up 
the desired filter parameters and taking the executed query from the Browser debug window (visible after 
pressing F12 key and in the network tab right-click on the openasearch URL, then copy address)


## Download products

The most effective way of downloading CODE-DE data products is using the HTTP Download Service. 
The download URLs can be extracted from the above OpenSearch query result. A utility script is included in this 
[package](https://github.com/dlr-eoc/code-de-tools/blob/master/bin/code-de-query-download.sh).
The follwing bash script snippet demonstrates the process:
```
#!/usr/bin/bash
baseUrl=https://catalog.code-de.org/opensearch/request/?httpAccept=application/atom%2Bxml
parentIdentifier=EOP:CODE-DE:S2_MSI_L1C
startDate=2017-01-04T00:00:00.000Z
endDate=2017-01-04T23:59:59.999
AOI=5.9,47.2,15.2,55
batchSize=100
downloadParallel=4

# execute query and extract the dwnload URL list

urls=$(curl "${baseUrl}&parentIdentifier=${parentIdentifier}&startDate=${startDate}&endDate=${endDate}&bbox=${AOI}&maximumRecords=${batchSize}" | xmllint --xpath '//*[local-name()="link" and @title="Download"]/@href' - |sed -e 's/ *href="//g' | tr '"' '\n' )
 
# download them all to the local directory
echo $urls | xargs -n1 -P4 curl -O
```

:bulb: the above command can be assembled to run as a bash one-liner.

:warning: Note: the current CODE-DE Download Service does not use authentication. In the near future, 
the curl download will need the access account information passed with the ```-u <user>:<password>``` parameter.


## Download a whole directory

Another example to download a whole directory from the download server:

_Download directories_
```
wget -O- -nv https://code-de.org/Sentinel2/2016/06/14 2> /dev/null | grep 'a href=".*.zip' | cut -d'"' -f2 ; done | head -10 | xargs -n1 -P10 -I{} wget http://code-de.org/download/{}
```
This command can be enhanced to filter for specific Sentinel-2 tiles, based on the new compact file naming convention, 
inserting another ```| grep _T32UPU_``` filter (example tile over munich).


## Incremetal Downloads

The script [dataHubTransfer.sh](https://github.com/dlr-eoc/code-de-tools/blob/master/bin/dataHubTransfer.sh) 
provides the means to incrementally download new products from a DHuS (ESA Data Hub Software). CODE-DE operates a DHuS 
mirror providing access to Sentinel prodcuts. The script is intended to be run in a cron job. 
Instructions are included in the README.md and in the script header itself.

:warning: Note: To use this interface you need to separately sign-up for an account: https://code-de.org/dhus/#/self-registration
