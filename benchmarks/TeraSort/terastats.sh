#!/usr/bin/env bash

#------------------------------------------------------------------------------
# FUNCTIONS
#------------------------------------------------------------------------------

# function: usage
function usage () {
  cat << EOF

  Usage: $0 </path/to/teragen|terasort|teravalidate/results_file>

    --help    shows this help menu

  This script computes the total run time of a teragen, terasort, or 
  teravalidate mapreduce job. In order to compute, pass the path to the 
  mapreduce resutls_file as an argument to the script.

EOF
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

# validate file
if [[ -z ${1+x} ]]; then
  usage;
  exit 0;
else
  for i in $@; do
    if [ ! -f $i ]; then
      echo "==> ERROR: '$i' file not found"
      usage;
      exit 1;
    fi
  done
fi

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

echo "==> TERASORT STATISTICS"
for i in $@; do
  # get start time
  firstline=$(grep -P "[0-9]{2,4}/[0-1]{1}[0-9]{1}/[0-3]{1}[0-9]{1}" $i | head -n 1)
  starttime=$(awk '{print $1, " ", $2}' <<< "${firstline}")

  # get stop time
  lastline=$(grep -P "[0-9]{2,4}/[0-1]{1}[0-9]{1}/[0-3]{1}[0-9]{1}" $i | tail -n 1)
  stoptime=$(awk '{print $1, " ", $2}' <<< "${lastline}")

  # convert to date format
  startdate=$(date -u -d "${starttime//\//}" +"%s")
  stopdate=$(date -u -d "${stoptime//\//}" +"%s")

  # get delta
  totaltime=$(date -u -d "0 $stopdate sec - $startdate sec" +"%H:%M:%S")

  # return results
  echo "==> '$i' took ${totaltime} to complete"
done
