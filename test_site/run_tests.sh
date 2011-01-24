#!/bin/sh
WAITTIME=2
if [ X"$UNICORN" == "X" ]; then
  UNICORN=unicorn
fi
if [ X"$RUBY" == "X" ]; then
  RUBY=ruby
fi
frameworks="rails ramaze camping sinatra rack"
fw=""
orm=""
if [ $# != 0 ]; then
  case $1 in rails|ramaze|camping|sinatra|rack) frameworks=$1; fw=$1;;
  esac
  case $1 in active_record|sequel|datamapper) orm=$1;;
  esac
  case $2 in active_record|sequel|datamapper) orm=$2;;
  esac
fi
./clear_logs
for framework in $frameworks; do
  echo $UNICORN -c unicorn-$framework.conf -D config-$framework.ru
  $UNICORN -c unicorn-$framework.conf -D config-$framework.ru
  sleep $WAITTIME
done
echo $RUBY test.rb $fw $orm
$RUBY test.rb $fw $orm
for framework in $frameworks; do
  kill `cat log/unicorn-$framework.pid`
done
