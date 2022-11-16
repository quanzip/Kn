#!/usr/bin/env bash

set -euo pipefail

ulimit -c unlimited

export JAVA_OPTS="-Xmx4g -XX:+UseG1GC"

nohup java -Dcom.sun.management.jmxremote \
	-Djava.net.preferIPv4Stack=true \
	-Dcom.sun.management.jmxremote.local.only=false \
	-Dcom.sun.management.jmxremote.port=9010 \
	-Dcom.sun.management.jmxremote.rmi.port=9010 \
	-Dcom.sun.management.jmxremote.authenticate=false \
	-Dcom.sun.management.jmxremote.ssl=false \
	-Dfile.encoding=UTF-8 \
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
	-jar dttc-0.0.1-SNAPSHOT.war &
