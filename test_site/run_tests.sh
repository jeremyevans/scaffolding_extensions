#!/bin/sh
WAITTIME=5
frameworks="rails ramaze camping sinatra merb"
fw=""
orm=""
if [ $# != 0 ]; then
  case $1 in rails|ramaze|camping|sinatra|merb) frameworks=$1; fw=$1;;
  esac
  case $1 in active_record|sequel) orm=$1;;
  esac
  case $2 in active_record|sequel) orm=$2;;
  esac
fi
./clear_logs
for framework in $frameworks; do
	style -c config/style.$framework.yaml start
	sleep $WAITTIME
done
ruby test.rb $fw $orm
for framework in $frameworks; do
	style -c config/style.$framework.yaml stop
done
