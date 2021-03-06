#!/bin/bash

if [ -z "$DB_DIR" ]; then
    echo "Need to set DB_DIR"
    exit 1
fi
if [ ! -d "$DB_DIR" ]; then
    echo "Need to create directory DB_DIR"
    exit 1
fi

#export threadCountList="0016 0032 0064 0128"
#export threadCountList="0001 0002 0004 0008 0016 0032 0064 0128 0256 0512 1024 2048"

if [ -z "$MYSQL_NAME" ]; then
    export MYSQL_NAME=mysql
fi
if [ -z "$MYSQL_VERSION" ]; then
    export MYSQL_VERSION=5.5.30
fi
if [ -z "$MYSQL_STORAGE_ENGINE" ]; then
    export MYSQL_STORAGE_ENGINE=tokudb
fi
if [ -z "$TARBALL" ]; then
    export TARBALL=blank-toku701-mysql-5.5.30
fi
if [ -z "$TOKUDB_COMPRESSION" ]; then
    export TOKUDB_COMPRESSION=lzma
fi
if [ -z "$BENCH_ID" ]; then
    export BENCH_ID=701.${TOKUDB_COMPRESSION}
fi
if [ -z "$NUM_ROWS" ]; then
    export NUM_ROWS=50000000
fi
if [ -z "$NUM_TABLES" ]; then
    export NUM_TABLES=16
fi
if [ -z "$NUM_DATABASES" ]; then
    export NUM_DATABASES=1
fi
if [ -z "$RUN_TIME_SECONDS" ]; then
    export RUN_TIME_SECONDS=900
fi
if [ -z "$RAND_TYPE" ]; then
    export RAND_TYPE=uniform
fi
if [ -z "$TOKUDB_READ_BLOCK_SIZE" ]; then
    export TOKUDB_READ_BLOCK_SIZE=64K
fi
if [ -z "$SKIP_DB_CREATE" ]; then
    export SKIP_DB_CREATE=N
fi
if [ -z "$BENCHMARK_NUMBER" ]; then
    export BENCHMARK_NUMBER=004
fi
if [ -z "$DIRECTIO" ]; then
    export DIRECTIO=Y
fi
if [ -z "$READONLY" ]; then
    export READONLY=off
fi

export BENCHMARK_LOGGING=Y
export LOADER_LOGGING=Y

export MYSQL_DATABASE=test
export MYSQL_USER=root

export TOKUDB_ROW_FORMAT=tokudb_${TOKUDB_COMPRESSION}

if [ ${MYSQL_STORAGE_ENGINE} == "innodb" ]; then
  if [ -z "$INNODB_CACHE" ]; then
    echo "Need to set INNODB_CACHE"
    exit 1
  fi
  if [ ${DIRECTIO} == "N" ]; then
    MYSQL_OPTS="--innodb_flush_method=${INNODB_FLUSH_METHOD}"
  fi
  MYSQL_OPTS="$MYSQL_OPTS --innodb_buffer_pool_size=${INNODB_CACHE}"
elif [ ${MYSQL_STORAGE_ENGINE} == "rocksdb" ]; then
  if [ -z "$ROCKSDB_CACHE" ]; then
    echo "Need to set ROCKSDB_CACHE"
    exit 1
  fi
  MYSQL_OPTS="--rocksdb-block-cache-size=${ROCKSDB_CACHE} --plugin-load-add=rocksdb=ha_rocksdb.so --init-file=${SCRIPT_DIR}/MyRocks.sql --default-storage-engine=ROCKSDB"
elif [ ${MYSQL_STORAGE_ENGINE} == "myisam" ]; then
  MYSQL_OPTS="key_buffer_size=8G"
#    echo "table_open_cache=2048" >> my.cnf
else
  MYSQL_OPTS="--tokudb_read_block_size=${TOKUDB_READ_BLOCK_SIZE} --tokudb_row_format=${TOKUDB_ROW_FORMAT} --tokudb_cache_size=${TOKUDB_DIRECTIO_CACHE} --plugin-load=tokudb=ha_tokudb.so --tokudb_loader_memory_size=1G"
  if [ ${DIRECTIO} == "Y" ]; then
    MYSQL_OPTS="$MYSQL_OPTS --tokudb_directio=1"
  fi
fi

if [ ${SKIP_DB_CREATE} == "N" ]; then
    timeout --signal=9 20s ${DB_DIR}/bin/mysqladmin -uroot --socket=${MYSQL_SOCKET} shutdown > /dev/null 2>&1
    rm -Rf  ${DB_DIR}/data ; mkdir ${DB_DIR}/data  
    mkdir -p  ${DB_DIR}/tmp
    BIN=`find ${DB_DIR} -maxdepth 2 -name mysqld -type f -o -name mysqld-debug -type f | head -1`;if [ -z $BIN ]; then echo "Assert! mysqld binary '$BIN' could not be read";exit 1;fi
    PS_VERSION=`$BIN --version | grep -oe '5\.[1567]' | sed 's/\.//' | head -n1`
    if [ "`$BIN --version | grep -oe '5\.[1567]' | head -n1`" == "5.7" ]; then
      RUN_DATA_DIR="run_dir_57_${BENCH_SIZE}_${MYSQL_STORAGE_ENGINE}"
    else
      RUN_DATA_DIR="run_dir_${BENCH_SIZE}_${MYSQL_STORAGE_ENGINE}"
    fi
    if [ ! -d  ${DB_DIR}/data ];then
      mkdir -p ${DB_DIR}/data
    fi
    if [ -d ${BIG_DIR}/$RUN_DATA_DIR/data ]; then
      cp -r ${BIG_DIR}/$RUN_DATA_DIR/data/*  ${DB_DIR}/data/
      if [ ${MYSQL_STORAGE_ENGINE} == "rocksdb" ]; then 
        cp -r ${BIG_DIR}/$RUN_DATA_DIR/data/.rocksdb  ${DB_DIR}/data/
      fi
    else
      ${SCRIPT_DIR}/sysbench_create_db_template.sh ${BIG_DIR} $PS_VERSION ${MYSQL_STORAGE_ENGINE}
      cp -r ${BIG_DIR}/$RUN_DATA_DIR/data/*  ${DB_DIR}/data/
      if [ ${MYSQL_STORAGE_ENGINE} == "rocksdb" ]; then 
        cp -r ${BIG_DIR}/$RUN_DATA_DIR/data/.rocksdb  ${DB_DIR}/data/
      fi
    fi
    mkdir -p  ${DB_DIR}/data/test
    ## Clearing OS cache
    ECHO=$(which echo)
    sudo sync;sudo sh -c "$ECHO 3 > /proc/sys/vm/drop_caches"

    ## Starting mysqld
    if [ "${JEMALLOC}" != "" -a -r "${JEMALLOC}" ]; then export LD_PRELOAD=${JEMALLOC}
    elif [ -r /usr/lib64/libjemalloc.so.1 ]; then export LD_PRELOAD=/usr/lib64/libjemalloc.so.1
    elif [ -r /usr/lib/x86_64-linux-gnu/libjemalloc.so.1 ]; then export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.1
    elif [ -r ${DB_DIR}/lib/mysql/libjemalloc.so.1 ]; then export LD_PRELOAD=${DB_DIR}/lib/mysql/libjemalloc.so.1
    else echo 'Warning: jemalloc was not loaded as it was not found (this is fine for MS, but do check ./1430715139_DB_DIR to set correct jemalloc location for PS)'; fi
    $BIN ${MYEXTRA}  --user=$STARTUP_USER --basedir=${DB_DIR} --datadir=${DB_DIR}/data ${MYSQL_OPTS} --port=${MYSQL_PORT} --pid-file=${DB_DIR}/data/pid.pid --core-file --socket=${MYSQL_SOCKET} --log-error=${DB_DIR}/data/error.log.out >  ${DB_DIR}/data/mysqld.out 2>&1 &
    MPID="$!"
    for X in $(seq 0 60); do
      sleep 1
      if ${DB_DIR}/bin/mysqladmin -uroot -S${MYSQL_SOCKET} ping > /dev/null 2>&1; then
        break
      fi
    done

else
    timeout --signal=9 20s ${DB_DIR}/bin/mysqladmin -uroot --socket=${MYSQL_SOCKET} shutdown > /dev/null 2>&1
    ## Starting mysqld
    BIN=`find ${DB_DIR} -maxdepth 2 -name mysqld -type f -o -name mysqld-debug -type f | head -1`;if [ -z $BIN ]; then echo "Assert! mysqld binary '$BIN' could not be read";exit 1;fi
    if [ "${JEMALLOC}" != "" -a -r "${JEMALLOC}" ]; then export LD_PRELOAD=${JEMALLOC}
    elif [ -r /usr/lib64/libjemalloc.so.1 ]; then export LD_PRELOAD=/usr/lib64/libjemalloc.so.1
    elif [ -r /usr/lib/x86_64-linux-gnu/libjemalloc.so.1 ]; then export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.1
    elif [ -r ${DB_DIR}/lib/mysql/libjemalloc.so.1 ]; then export LD_PRELOAD=${DB_DIR}/lib/mysql/libjemalloc.so.1
    else echo 'Warning: jemalloc was not loaded as it was not found (this is fine for MS, but do check ./1430715139_DB_DIR to set correct jemalloc location for PS)'; fi
    $BIN ${MYEXTRA} --user=$STARTUP_USER --basedir=${DB_DIR} --datadir=${DB_DIR}/data ${MYSQL_OPTS} --port=${MYSQL_PORT} --pid-file=${DB_DIR}/data/pid.pid --core-file --socket=${MYSQL_SOCKET} --log-error=${DB_DIR}/data/error.log.out >  ${DB_DIR}/data/mysqld.out 2>&1 &
    MPID="$!"
    for X in $(seq 0 60); do
      sleep 1
      if ${DB_DIR}/bin/mysqladmin -uroot -S${MYSQL_SOCKET} ping > /dev/null 2>&1; then
        break
      fi
    done
fi

if [ ${MYSQL_STORAGE_ENGINE} == "rocksdb" ]; then
  ECHO=$(which echo)
  sudo service cgconfig restart
  sudo cgcreate -g memory:DBLimitedGroup
  sudo sh -c "$ECHO $CGROUP_MEM > /cgroup/memory/DBLimitedGroup/memory.limit_in_bytes"
  sudo sync;sudo sh -c "$ECHO 3 > /proc/sys/vm/drop_caches"
  sudo cgclassify -g memory:DBLimitedGroup `pidof mysqld`
fi
  
echo "Running benchmark"
bash -x ./ps.run.benchmark-v1.sh
cp ${DB_DIR}/data/error.log.out ${BIG_DIR}/${BUILD_NUMBER}/${BENCH_ID}_error.log.out
echo "Stopping database"
timeout --signal=9 20s ${DB_DIR}/bin/mysqladmin -uroot --socket=${MYSQL_SOCKET} shutdown > /dev/null 2>&1
(sleep 0.2; kill -9 ${MPID} >/dev/null 2>&1; wait ${MPID} >/dev/null 2>&1) &  # Terminate mysqld
wait ${MPID} >/dev/null 2>&1
kill -9 ${MPID} >/dev/null 2>&1;
sleep 2
