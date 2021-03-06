#!/bin/bash

export MONGO_COMPRESSION=zlib
export MONGO_BASEMENT=65536
export MAX_ROWS=999999999
export RUN_MINUTES=30
#export NUM_SECONDARY_INDEXES=0
export NUM_DOCUMENTS_PER_INSERT=1000
export MAX_INSERTS_PER_SECOND=999999
export NUM_INSERTS_PER_FEEDBACK=-1
export NUM_SECONDS_PER_FEEDBACK=15
export NUM_LOADER_THREADS=4
export DB_NAME=iibench
export BENCHMARK_NUMBER=999
export MONGO_SERVER=localhost
export MONGO_PORT=27017

export NUM_CHAR_FIELDS=1
export LENGTH_CHAR_FIELDS=1000
export PERCENT_COMPRESSIBLE=90

export MONGO_REPLICATION=Y
if [ ${MONGO_REPLICATION} == "Y" ]; then
    export OPLOG_STRING="OpLogON"
else
    export OPLOG_STRING="OpLogOFF"
fi

# FSYNC_SAFE, NONE, NORMAL, REPLICAS_SAFE, SAFE
export WRITE_CONCERN=SAFE

# set these if you want inserts plus queries
export QUERIES_PER_INTERVAL=0
export QUERY_INTERVAL_SECONDS=15
export QUERY_LIMIT=10
export QUERY_NUM_DOCS_BEGIN=1000000

export TOKUMON_CACHE_SIZE=4G

export LOCK_MEMORY=N


mongo-clean


export TARBALL=tokumx-1b-varcompress-linux-x86_64-main
export MONGO_TYPE=tokumx
export MONGO_COMPRESSION=zlib
export BENCH_ID=${TARBALL}-${MONGO_COMPRESSION}-${WRITE_CONCERN}-${OPLOG_STRING}-${NUM_SECONDARY_INDEXES}-${NUM_CHAR_FIELDS}-${LENGTH_CHAR_FIELDS}-${PERCENT_COMPRESSIBLE}
./doit.bash
mongo-clean

export TARBALL=tokumx-1b-varcompress-linux-x86_64-main
export MONGO_TYPE=tokumx
export MONGO_COMPRESSION=lzma
export BENCH_ID=${TARBALL}-${MONGO_COMPRESSION}-${WRITE_CONCERN}-${OPLOG_STRING}-${NUM_SECONDARY_INDEXES}-${NUM_CHAR_FIELDS}-${LENGTH_CHAR_FIELDS}-${PERCENT_COMPRESSIBLE}
./doit.bash
mongo-clean

export TARBALL=tokumx-2a-varcompress-linux-x86_64-main
export MONGO_TYPE=tokumx
export MONGO_COMPRESSION=zlib
export BENCH_ID=${TARBALL}-${MONGO_COMPRESSION}-${WRITE_CONCERN}-${OPLOG_STRING}-${NUM_SECONDARY_INDEXES}-${NUM_CHAR_FIELDS}-${LENGTH_CHAR_FIELDS}-${PERCENT_COMPRESSIBLE}
./doit.bash
mongo-clean

export TARBALL=tokumx-2a-varcompress-linux-x86_64-main
export MONGO_TYPE=tokumx
export MONGO_COMPRESSION=lzma
export BENCH_ID=${TARBALL}-${MONGO_COMPRESSION}-${WRITE_CONCERN}-${OPLOG_STRING}-${NUM_SECONDARY_INDEXES}-${NUM_CHAR_FIELDS}-${LENGTH_CHAR_FIELDS}-${PERCENT_COMPRESSIBLE}
./doit.bash
mongo-clean
