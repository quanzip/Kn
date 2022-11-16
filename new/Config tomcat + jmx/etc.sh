#!/usr/bin/env bash

set -euo pipefail

ulimit -c unlimited

export JAVA_OPTS="-Xmx4g -XX:+UseG1GC"

nohup java -Dfile.encoding=UTF-8 \
	-server \
	-Xms1024m \
	-Xmx8192m \
	-Xss1024m \
	-Dsun.zip.disableMemoryMapping=true \
	-XX:+UseG1GC \
	-XX:MaxGCPauseMillis=200 \
	-XX:ParallelGCThreads=8 \
	-XX:ConcGCThreads=2 \
	-XX:InitiatingHeapOccupancyPercent=70 \
	-XX:+UseStringDeduplication \
	-XX:+DisableExplicitGC \
	-Djava.net.preferIPv4Stack=true \
	-jar serviceEtc-0.0.1-SNAPSHOT.jar &
