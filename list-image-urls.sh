#!/bin/bash
#
#

# lists image image urls in preston archive 
function list_images {
IMAGE_ELEMENT_NAME="$1"

preston ls\
 | preston dwc-stream\
 | grep URI\
 | jq --raw-output "[.[\"http://www.w3.org/ns/prov#wasDerivedFrom\"], .[\"${IMAGE_ELEMENT_NAME}\"]] | @tsv"\
 | grep -v null\
 | sed "s+$+\t${IMAGE_ELEMENT_NAME}+g"
}

list_images "http://rs.tdwg.org/ac/terms/accessURI"
list_images "http://rs.tdwg.org/ac/terms/thumbnailAccessURI"
list_images "http://rs.tdwg.org/ac/terms/goodQualityAccessURI"
