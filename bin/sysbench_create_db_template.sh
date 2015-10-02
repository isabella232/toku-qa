#!/bin/bash
SCRIPT_DIR=$(cd `dirname $0` && pwd)

if [ -z ${NUM_ROWS} -a  -z ${NUM_TABLES} ]; then
  NUM_ROWS=10
  NUM_TABLES=1000000
fi

if [ -z $3 ]; then
  echo "No valid parameters were passed. Need relative workdir (1st option), relative PS version (2nd option) settings and storage engine (3rd option). Retry."
  echo "Usage example:"
  echo "$./sysbench_create_db_template.sh /sda/datadir 56 innodb"
  echo "Supported storage engines : innodb/myisam/tokudb"
  exit 1
else
  WORK_DIR=$1
  PS_VERSION=$2
  SE=$3
fi

if [ -r /usr/lib64/libjemalloc.so.1 ]; then export LD_PRELOAD=/usr/lib64/libjemalloc.so.1
elif [ -r /usr/lib/x86_64-linux-gnu/libjemalloc.so.1 ]; then export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.1
elif [ -r $WORK_DIR/$BASE/lib/mysql/libjemalloc.so.1 ]; then export LD_PRELOAD=$WORK_DIR/$BASE/lib/mysql/libjemalloc.so.1
else echo 'Error: jemalloc was not loaded as it was not found' ; exit 1; fi

echo "This script will create ${NUM_TABLES} tables with ${NUM_ROWS} rows in each tables"
cd $WORK_DIR
if [ -z ${DB_DIR} ]; then
  $SCRIPT_DIR/get_percona.sh $PS_VERSION 2 > ps_download.log 2>&1
  BASE=`ls -1d ?ercona-?erver* | grep -v ".tar" | head -n1`
  BASE=$WORK_DIR/$BASE
else
  BASE=${DB_DIR}
fi
rm -Rf $WORK_DIR/run_dir_$SE
cd $BASE/mysql-test
perl lib/v1/mysql-test-run.pl \
  --start-and-exit --skip-ndb \
  --vardir=$WORK_DIR/run_dir_$SE \
  --master_port=$RANDOM \
  --mysqld=--core-file \
  --mysqld=--log-output=none \
  --mysqld=--secure-file-priv= \
  --mysqld=--max-connections=900 \
  --mysqld=--plugin-load=tokudb=ha_tokudb.so \
  --mysqld=--init-file=$SCRIPT_DIR/TokuDB.sql \
  --mysqld=--socket=$WORK_DIR/run_dir_$SE/socket.sock \
1st

# Running sysbench
echo "Running sysbench"
/usr/bin/sysbench --test=/usr/share/doc/sysbench/tests/db/parallel_prepare.lua --mysql-table-engine=$SE --num-threads=${NUM_TABLES} --oltp-tables-count=${NUM_TABLES}  --oltp-table-size=${NUM_ROWS} --mysql-db=test --mysql-user=root    --db-driver=mysql --mysql-socket=$WORK_DIR/run_dir_$SE/socket.sock    run > $WORK_DIR/sysbench_prepare.log 2>&1

#Stopping mysqld
echo "Stopping mysqld process"
$BASE/bin/mysqladmin --socket=$WORK_DIR/run_dir_$SE/socket.sock -uroot shutdown

echo "Data directory template is available in $WORK_DIR/run_dir_$SE/master-data"
