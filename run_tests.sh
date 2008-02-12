#!/bin/sh
WAITTIME=3
for adapter in rails ramaze; do
  echo testing $adapter
  style -D -a $adapter &
  STYLE_PID=$!
  sleep $WAITTIME
  ruby test.rb
  kill -9 $STYLE_PID
  sleep $WAITTIME
done
