#!/bin/sh
WAITTIME=5
frameworks="rails ramaze camping sinatra"
if [ $# != 0 ]; then
  case $1 in rails|ramaze|camping|sinatra) frameworks=$1;;
  esac
fi
for framework in $frameworks; do
	echo testing $framework
	style -c config/style.$framework.yaml start
	sleep $WAITTIME
	ruby test.rb $framework
	style -c config/style.$framework.yaml stop
done
