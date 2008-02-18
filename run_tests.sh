#!/bin/sh
WAITTIME=3
frameworks="rails ramaze"
for framework in $frameworks; do
	echo -n '' > log/style-$framework.log
	style -c config/style.$framework.yaml start
done
sleep $WAITTIME
ruby test.rb
for framework in $frameworks; do
	style -c config/style.$framework.yaml stop
done
