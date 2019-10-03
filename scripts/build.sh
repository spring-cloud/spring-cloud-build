#!/bin/bash

./mvnw clean install -B -Pdocs ${@}
#./mvnw clean install -B -DskipTests ${@}
