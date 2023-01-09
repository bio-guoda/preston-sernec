#!/bin/bash
#
#   attempt to track DwCA found in YAML frontmatter of README.md
#
#   usage:
#     track.sh 
# 
#   example:
#     ./track.sh 
#

#set -x

export REPO_NAME=$1

export PRESTON_VERSION=0.5.1
export PRESTON_JAR="$PWD/preston.jar"

export README=$(mktemp)

export YQ_VERSION=4.25.3

function echo_logo {
  echo "$(cat <<_EOF_
██████  ██     ██  ██████  █████                               
██   ██ ██     ██ ██      ██   ██                              
██   ██ ██  █  ██ ██      ███████                              
██   ██ ██ ███ ██ ██      ██   ██                              
██████   ███ ███   ██████ ██   ██                              
                                                               
                                                               
████████ ██████   █████   ██████ ██   ██ ██ ███    ██  ██████  
   ██    ██   ██ ██   ██ ██      ██  ██  ██ ████   ██ ██       
   ██    ██████  ███████ ██      █████   ██ ██ ██  ██ ██   ███ 
   ██    ██   ██ ██   ██ ██      ██  ██  ██ ██  ██ ██ ██    ██ 
   ██    ██   ██ ██   ██  ██████ ██   ██ ██ ██   ████  ██████  
                                                               
                                                               
██████  ██    ██                                               
██   ██  ██  ██                                                
██████    ████                                                 
██   ██    ██                                                  
██████     ██                                                  
                                                               
                                                               
██████  ██████  ███████ ███████ ████████  ██████  ███    ██    
██   ██ ██   ██ ██      ██         ██    ██    ██ ████   ██    
██████  ██████  █████   ███████    ██    ██    ██ ██ ██  ██    
██      ██   ██ ██           ██    ██    ██    ██ ██  ██ ██    
██      ██   ██ ███████ ███████    ██     ██████  ██   ████    
                                                               
                                                               
⚠️ Disclaimer: The data packages resulted from tracking configured content
should be considered friendly, yet naive, attempt by an unsophisticated robot
to preserve openly accessible natural history collection records 
and associated content. 
Please carefully review the results listed below and share issues/ideas
by opening an issue at https://github.com/bio-guoda/preston/issues .


_EOF_
)"
}

function echo_reproduce {
  echo -e "\n\nIf you'd like, you can generate your own name alignment by:"
  echo "  - installing GloBI's Nomer via https://github.com/globalbioticinteractions/nomer"
  echo "  - inspecting the align-names.sh script at https://github.com/globalbioticinteractions/globinizer/blob/master/align-names.sh"
  echo "  - write your own script for name alignment"
  echo -e "\nPlease email info@globalbioticinteractions.org for questions/ comments."
}

function tee_readme {
  tee --append $README
}

function save_readme {
  cat ${README} > README.txt
}

function install_deps {
  if [[ -n ${TRAVIS_REPO_SLUG} || -n ${GITHUB_REPOSITORY} ]]
  then
    sudo apt-get -q update &> /dev/null
    sudo apt-get -q install miller jq -y &> /dev/null
    sudo curl --silent -L https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_386 > /usr/local/bin/yq && sudo chmod +x /usr/local/bin/yq 
  fi

  mlr --version
  java -version
  yq --version
}

function configure_preston {
  if [[ $(which preston) ]]
  then
    echo using local preston found at [$(which preston)]
    export PRESTON_CMD="preston"
  else
    local PRESTON_DOWNLOAD_URL="https://github.com/bio-guoda/preston/releases/download/${PRESTON_VERSION}/preston.jar"
    echo preston not found... installing from [${PRESTON_DOWNLOAD_URL}]
    curl --silent -L "${PRESTON_DOWNLOAD_URL}" > "${PRESTON_JAR}"
    export PRESTON_CMD="java -Xmx4G -jar ${PRESTON_JAR}"
  fi
}

echo_logo | tee_readme 

install_deps

configure_preston

echo -e "\nTracking of [${REPO_NAME}] started at [$(date -Iseconds)]." | tee_readme 

if [ $(cat README.md | yq --front-matter=extract --header-preprocess '.datasets[].url' | wc -l) -gt 0 ]
then
  export DWCA_REMOTE=$(cat README.md | yq --front-matter=extract --header-preprocess '.datasets[] | select(.type == "application/dwca" or .type == "application/rss+xml") | .url' | grep -P "^http[s]{0,1}://") 
else 
  export DWCA_REMOTE=
fi

function preston_track_uri {
  if [ $(echo "$1" | wc -c) -gt 1  ]
  then
    echo -e "$1" | xargs ${PRESTON_CMD} track
  fi
}

function preston_track_local {
  # exclude empty lists
  if [ $(echo "$1" | wc -c) -gt 1  ]
  then
    preston_track_uri $(echo -e "$1" | sed "s+^+file://$PWD/+g")
  fi
}

function preston_head {
  ${PRESTON_CMD} head 
}

if [ $(echo "$DWCA_REMOTE" | wc -c) -gt 1  ]
then
  preston_track_uri "$DWCA_REMOTE"
  ${PRESTON_CMD} cat $(preston_head) | ${PRESTON_CMD} dwc-stream | jq --raw-output 'select(.["http://rs.tdwg.org/dwc/terms/scientificName"]) | [ .["http://www.w3.org/ns/prov#wasDerivedFrom"] , .["http://rs.tdwg.org/dwc/terms/scientificName"] ] | @tsv ' | gzip >> names.tsv.gz
fi

save_readme
