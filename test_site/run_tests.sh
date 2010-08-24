#!/bin/sh
WAITTIME=2
frameworks="rails ramaze camping sinatra merb rack"
fw=""
orm=""
if [ $# != 0 ]; then
  case $1 in rails|ramaze|camping|sinatra|merb|rack) frameworks=$1; fw=$1;;
  esac
  case $1 in active_record|sequel|datamapper) orm=$1;;
  esac
  case $2 in active_record|sequel|datamapper) orm=$2;;
  esac
fi
./clear_logs
for framework in $frameworks; do
  unicorn -c unicorn-$framework.conf -D config-$framework.ru
  sleep $WAITTIME
done
ruby test.rb $fw $orm
for framework in $frameworks; do
  kill `cat log/unicorn-$framework.pid`
done
