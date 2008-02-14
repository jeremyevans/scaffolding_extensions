#!/bin/sh
WAITTIME=3
style -c config/style.rails.yaml start
style -c config/style.ramaze.yaml start
sleep $WAITTIME
ruby test.rb
style -c config/style.rails.yaml stop
style -c config/style.ramaze.yaml stop
