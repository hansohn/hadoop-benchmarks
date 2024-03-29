#!/usr/bin/env bash

set -u
trap "" HUP

#------------------------------------------------------------------------------
# FUNCTIONS
#------------------------------------------------------------------------------

# function: upsearch
function upsearch () {
    test / == "$PWD" && return || test -e "$1" && echo "$PWD/$1" && return || cd .. && upsearch "$1"
}

#------------------------------------------------------------------------------
# VARIABLES
#------------------------------------------------------------------------------

DFSIO_JAR=/usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient-tests.jar
FILES=10
FILESIZE=100000

DATE=`date +%Y%m%d`
TIME=`date +%H%M%S`
LOGDIR=$(upsearch "logs")
RESULTDIR="${LOGDIR}/TestDFSIO/${DATE}/${TIME}"
DFSIO_WRITE="${RESULTDIR}/dfsio_write.txt"
DFSIO_READ="${RESULTDIR}/dfsio_read.txt"

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

# check for dfsio jar
if [ ! -f ${DFSIO_JAR} ]; then
  echo "==> ERROR: File not found '${DFSIO_JAR}'"
  exit 1
fi

# create log dir
if [ ! -d "${RESULTDIR}" ]; then
    mkdir -p ${RESULTDIR}
fi

# testdfsio clean
echo "==> TestDFSIO Clean Phase"
yarn jar ${DFSIO_JAR} TestDFSIO -clean

# testdfsio write
echo "==> TestDFSIO Write Phase"
yarn jar ${DFSIO_JAR} TestDFSIO \
  -write -nrFiles ${FILES} \
  -fileSize ${FILESIZE} \
  -resFile ${DFSIO_WRITE}

# testdfsio read
echo "==> TestDFSIO Read Phase"
yarn jar ${DFSIO_JAR} TestDFSIO \
  -read -nrFiles ${FILES} \
  -fileSize ${FILESIZE} \
  -resFile ${DFSIO_READ}
