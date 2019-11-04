#!/usr/bin/env bash

set -u
trap "" HUP

#------------------------------------------------------------------------------
# FUNCTIONS
#------------------------------------------------------------------------------

# function: usage
function usage () {
  cat << EOF

  Usage: $0 <1G|10G|50G|500G|1T|10T|100T>

    --help    shows this help menu

  By default this script will generate a 1 TB sample dataset, sort the dataset,
  and then validate the sort. You can modify the sample size to an alternate 
  supported size by passing the size value as a arguement to the script. 

  The current supported sizes are:

    - 1G
    - 10G
    - 100G
    - 500G
    - 1T
    - 10T
    - 100T

EOF
}

# function: mrkill
function mrkill () {
  mapred job -list 2>/dev/null | grep job_ | awk ' { system("mapred job -kill " $1) } '
}

#------------------------------------------------------------------------------
# ARGUEMENTS
#------------------------------------------------------------------------------

# handle arguements
while getopts ":h-:" FLAG; do
  case $FLAG in
    -)
      case ${OPTARG} in
        h|help)
          usage;
          exit 0;
          ;;
      esac
      ;;
    h|help)
      usage;
      exit 0;
      ;;
  esac
done
shift $((OPTIND-1))

#------------------------------------------------------------------------------
# VALIDATION
#------------------------------------------------------------------------------

# validate parameters
declare -a SIZES
if [[ -z ${1+x} ]]; then
  SIZES+=("1T")
else
  for i in $@; do
    if [[ $i =~ ^(1G|10G|100G|500G|1T|10T|100T)$ ]]; then
      SIZES+=("${i}")
    else
      echo "==> ERROR: Unsupported sample size '${i}' was requested"
      usage;
      exit 1;
    fi
  done
fi

#------------------------------------------------------------------------------
# VARIABLES
#------------------------------------------------------------------------------

MR_EXAMPLES_JAR=/usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar

declare -A ROWS
ROWS+=(
  ["1G"]=10000000
  ["10G"]=100000000
  ["100G"]=1000000000
  ["500G"]=5000000000
  ["1T"]=10000000000
  ["10T"]=100000000000
  ["100T"]=1000000000000
)

DATE=`date +%Y%m%d`
TIME=`date +%H%M%S`
LOGDIR="./logs"
RESULTDIR="${LOGDIR}/TeraSort/${DATE}/${TIME}"
TERASORT_PREFIX="/benchmarks/TeraSort/${DATE}/${TIME}"

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

# create log dir
if [ ! -d "${RESULTDIR}" ]; then
  mkdir -p ${RESULTDIR}
fi
# create terasort_prefix dir
if ! hdfs dfs -ls "${TERASORT_PREFIX}" > /dev/null 2>&1; then
  hdfs dfs -mkdir -p ${TERASORT_PREFIX}
fi

for size in "${SIZES[@]}"; do
  # define datasets
  SAMPLE_DATASET="${TERASORT_PREFIX}/${size}_teragen_sample"
  SORTED_DATASET="${TERASORT_PREFIX}/${size}_terasort_sorted"
  VALIDATED_DATASET="${TERASORT_PREFIX}/${size}_teravalidate_report"

  # kill running mapreduce jobs
  mrkill

  # run teragen
  echo "==> TeraGen Phase ${size}"
  time hadoop jar ${MR_EXAMPLES_JAR} teragen \
    -Dmapreduce.map.log.level=INFO \
    -Dmapreduce.reduce.log.level=INFO \
    -Dyarn.app.mapreduce.am.log.level=INFO \
    -Dio.file.buffer.size=131072 \
    -Dmapreduce.map.cpu.vcores=1 \
    -Dmapreduce.map.java.opts=-Xmx1536m \
    -Dmapreduce.map.maxattempts=1 \
    -Dmapreduce.map.memory.mb=2048 \
    -Dmapreduce.map.output.compress=true \
    -Dmapreduce.map.output.compress.codec=org.apache.hadoop.io.compress.Lz4Codec \
    -Dmapreduce.reduce.cpu.vcores=1 \
    -Dmapreduce.reduce.java.opts=-Xmx1536m \
    -Dmapreduce.reduce.maxattempts=1 \
    -Dmapreduce.reduce.memory.mb=2048 \
    -Dmapreduce.task.io.sort.factor=100 \
    -Dmapreduce.task.io.sort.mb=384 \
    -Dyarn.app.mapreduce.am.command.opts=-Xmx768m \
    -Dyarn.app.mapreduce.am.resource.mb=1024 \
    -Dmapred.map.tasks=92 \
    ${ROWS[${size}]} ${SAMPLE_DATASET} >> "${RESULTDIR}/${size}_teragen.txt" 2>&1

  # verify teragen dataset exists
  if ! hdfs dfs -ls ${SAMPLE_DATASET} > /dev/null 2>&1; then
    echo "==> ERROR: TeraGen dataset directory '${SAMPLE_DATASET}' not found"
    exit 1;
  fi

  # kill running mapreduce jobs
  mrkill

  # run terasort
  echo "==> TeraSort Phase ${size}"
  time hadoop jar ${MR_EXAMPLES_JAR} terasort \
    -Dmapreduce.map.log.level=INFO \
    -Dmapreduce.reduce.log.level=INFO \
    -Dyarn.app.mapreduce.am.log.level=INFO \
    -Dio.file.buffer.size=131072 \
    -Dmapreduce.map.cpu.vcores=1 \
    -Dmapreduce.map.java.opts=-Xmx1536m \
    -Dmapreduce.map.maxattempts=1 \
    -Dmapreduce.map.memory.mb=2048 \
    -Dmapreduce.map.output.compress=true \
    -Dmapreduce.map.output.compress.codec=org.apache.hadoop.io.compress.Lz4Codec \
    -Dmapreduce.reduce.cpu.vcores=1 \
    -Dmapreduce.reduce.java.opts=-Xmx1536m \
    -Dmapreduce.reduce.maxattempts=1 \
    -Dmapreduce.reduce.memory.mb=2048 \
    -Dmapreduce.task.io.sort.factor=300 \
    -Dmapreduce.task.io.sort.mb=384 \
    -Dyarn.app.mapreduce.am.command.opts=-Xmx768m \
    -Dyarn.app.mapreduce.am.resource.mb=1024 \
    -Dmapred.reduce.tasks=92 \
    -Dmapreduce.terasort.output.replication=1 \
    ${SAMPLE_DATASET} ${SORTED_DATASET} >> "${RESULTDIR}/${size}_terasort.txt" 2>&1

  # verify terasort output exists
  if ! hdfs dfs -ls ${SORTED_DATASET} > /dev/null 2>&1; then
    echo "==> ERROR: TeraSort output directory '${SORTED_DATASET}' not found"
    exit 1;
  fi

  # kill running mapreduce jobs
  mrkill

  # run teravalidate
  echo "==> TeraValidate Phase ${size}"
  time hadoop jar ${MR_EXAMPLES_JAR} teravalidate \
    -Ddfs.blocksize=256M \
    -Dio.file.buffer.size=131072 \
    -Dmapreduce.map.memory.mb=2048 \
    -Dmapreduce.map.java.opts=-Xmx1536m \
    -Dmapreduce.reduce.memory.mb=2048 \
    -Dmapreduce.reduce.java.opts=-Xmx1536m \
    -Dyarn.app.mapreduce.am.resource.mb=1024 \
    -Dyarn.app.mapreduce.am.command-opts=-Xmx768m \
    -Dmapreduce.task.io.sort.mb=1 \
    -Dmapred.map.tasks=185 \
    -Dmapred.reduce.tasks=185 \
    ${SORTED_DATASET} ${VALIDATED_DATASET} >> "${RESULTDIR}/${size}_teravalidate.txt" 2>&1
done
