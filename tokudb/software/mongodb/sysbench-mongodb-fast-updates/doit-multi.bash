#!/bin/bash

export TOKUMX_BUFFERED_IO=N

export MONGO_COMPRESSION=zlib
export MONGO_BASEMENT=65536

# > RAM test - remember we have a 4k string in the document
export NUM_COLLECTIONS=16
export NUM_DOCUMENTS_PER_COLLECTION=250000

export NUM_DOCUMENTS_PER_INSERT=1000
export NUM_LOADER_THREADS=8
export threadCountList="0064"
export RUN_TIME_SECONDS=1200
export ENABLE_FAST_UPDATES_SECONDS=600
export DB_NAME=sbtest
export BENCHMARK_NUMBER=999
export NUM_SECONDS_PER_FEEDBACK=10


#export MAX_TPS=30000
#export TOKUMX_CHECKPOINT_PERIOD=1

# FSYNC_SAFE, NONE, NORMAL, REPLICAS_SAFE, SAFE
export WRITE_CONCERN=SAFE

# 4G TokuMX Cache
export TOKUMON_CACHE_SIZE=4G

export MONGO_REPLICATION=Y

# --writeLeafOnFlush (set to true if we should write out leaf nodes on flush instead of keeping them dirty in the cache)
# --compressBuffersBeforeEviction (set to false if we should not bother compressing internal nodes on partial eviction, but instead destroy buffers, like we do with basement nodes)
# --cleanerPeriod 0 (turn off cleaner threads)
#export MONGOD_EXTRA="--cleanerPeriod 0"
#export MONGOD_EXTRA="--setParameter writeLeafOnFlush=true --setParameter compressBuffersBeforeEviction=false"
#unset MONGOD_EXTRA

export MONGO_TYPE=tokumx
export BENCHMARK_SUFFIX=".${TOKUMON_CACHE_SIZE}"

export PAUSE_BETWEEN_RUNS=5

export BENCH_TYPE=PRIMARY
#export BENCH_TYPE=SECONDARY


# TokuMX
export TARBALL=tokumx-e-2.0.0-linux-x86_64-main
export BENCH_ID=${TARBALL}.${BENCH_TYPE}-${MONGO_COMPRESSION}-${WRITE_CONCERN}-${MONGO_REPLICATION}
./doit.bash
mongo-clean



unset MONGOD_EXTRA
