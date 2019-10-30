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

  By default this script will target a 1 TB teragen processed terasort output 
  for validation. You can modify the target terasort processed output to an 
  alternate supported teragen size by passing the size value as a arguement to 
  the script.

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
  mapred job -list | grep job_ | awk ' { system("mapred job -kill " $1) } '
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

# validate sample size
if [[ -z $1 ]]; then
  SIZE="1T"
elif [[ $1 =~ ^(1G|10G|100G|500G|1T|10T|100T)$ ]]; then
  SIZE=$1
else
  echo "==> ERROR: An unsupported sample size was requested"
  usage;
  exit 1;
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
LOGDIR="logs"
RESULTDIR="./${LOGDIR}/TeraSort/${DATE}"
SAMPLE_DATASET="/benchmarks/TeraSort/teragen_sample_${SIZE}"
SORTED_DATASET="/benchmarks/TeraSort/terasort_sorted_${SIZE}"
VALIDATED_DATASET="/benchmarks/TeraSort/teravalidate_report_${SIZE}"

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

# create log dir
if [ ! -d "${LOGDIR}" ]; then
    mkdir -p ./${LOGDIR}
fi

# verify terasort output exists
if ! hdfs dfs -ls ${SORTED_DATASET} > /dev/null 2>&1; then
  echo "==> ERROR: TeraSort output directory '${SORTED_DATASET}' not found"
  exit 1;
fi

# remove teravalidate report dir
if hdfs dfs -ls ${VALIDATED_DATASET} > /dev/null 2>&1; then
  hdfs dfs -rm -r -f ${VALIDATED_DATASET}
fi

# kill running mapreduce jobs
mrkill

# run teravalidate
echo "==> TeraValidate Phase"
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
  ${SORTED_DATASET} ${VALIDATED_DATASET} >> "${RESULTDIR}/teravalidate_results_${DATE}${TIME}.txt" 2>&1
