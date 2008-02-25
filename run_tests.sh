#!/bin/sh
WAITTIME=1
frameworks="rails ramaze camping sinatra"
if [ $# != 0 ]; then
  case $1 in rails|ramaze|camping|sinatra) frameworks=$1;;
  esac
fi
for framework in $frameworks; do
  echo testing $framework
	echo -n '' > log/style-$framework.log
	style -c config/style.$framework.yaml start
done
sleep $WAITTIME
ruby test.rb "$@"
for framework in $frameworks; do
	style -c config/style.$framework.yaml stop
done
