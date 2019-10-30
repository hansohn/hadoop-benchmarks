#!/usr/bin/env bash

set -u
trap "" HUP

#------------------------------------------------------------------------------
# VARIABLES
#------------------------------------------------------------------------------

DFSIO_JAR=/usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-client-jobclient-tests.jar
FILES=10
FILESIZE=100000

DATE=`date +%Y%m%d`
TIME=`date +%H%M%S`
LOGDIR="./logs"
RESULTDIR="${LOGDIR}/TestDFSIO/${DATE}"
DFSIO_WRITE_OUTPUT_FILE="${RESULTDIR}/dfsio_write_results_${DATE}${TIME}.txt"
DFSIO_READ_OUTPUT_FILE="${RESULTDIR}/dfsio_read_results_${DATE}${TIME}.txt"

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

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
  -resFile ${DFSIO_WRITE_OUTPUT_FILE}

# testdfsio read
echo "==> TestDFSIO Read Phase"
yarn jar ${DFSIO_JAR} TestDFSIO \
  -read -nrFiles ${FILES} \
  -fileSize ${FILESIZE} \
  -resFile ${DFSIO_READ_OUTPUT_FILE}
