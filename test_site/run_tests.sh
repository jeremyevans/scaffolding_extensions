#!/bin/sh
WAITTIME=15
frameworks="rails ramaze camping sinatra"
fw=""
orm=""
if [ $# != 0 ]; then
  case $1 in rails|ramaze|camping|sinatra) frameworks=$1; fw=$1;;
  esac
  case $1 in active_record|data_mapper|sequel) orm=$1;;
  esac
  case $2 in active_record|data_mapper|sequel) orm=$2;;
  esac
fi
for framework in $frameworks; do
	style -c config/style.$framework.yaml start
done
	sleep $WAITTIME
  ruby test.rb $fw $orm
for framework in $frameworks; do
	style -c config/style.$framework.yaml stop
done
