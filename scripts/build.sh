#!/bin/bash

./mvnw clean install -s .settings.xml -B -Pdocs ${@}
#./mvnw clean install -B -DskipTests ${@}
