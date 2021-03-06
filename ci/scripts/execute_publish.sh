#!/usr/bin/env bash

#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

BASE_DIR=$(pwd)

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source ${SCRIPTDIR}/shared_utilities.sh


ROOT_DIR=$(pwd)
BUILD_DATE=$(date +%s)
EMAIL_SUBJECT="results/subject"
EMAIL_BODY="results/body"

GEODE_BUILD_VERSION_FILE=${ROOT_DIR}/geode-build-version/number
GEODE_RESULTS_VERSION_FILE=${ROOT_DIR}/results/number
GEODE_BUILD_DIR=/tmp/geode-build
GEODE_PULL_REQUEST_ID_FILE=${ROOT_DIR}/geode/.git/resource/version.json

if [ -e "${GEODE_PULL_REQUEST_ID_FILE}" ]; then
  GEODE_PULL_REQUEST_ID=$(cat ${GEODE_PULL_REQUEST_ID_FILE} | jq --raw-output '.["pr"]')
  FULL_PRODUCT_VERSION="geode-pr-${GEODE_PULL_REQUEST_ID}"
else
  CONCOURSE_VERSION=$(cat ${GEODE_BUILD_VERSION_FILE})
  echo "Concourse VERSION is ${CONCOURSE_VERSION}"
  FULL_PRODUCT_VERSION=${CONCOURSE_VERSION}
  BUILD_ID=$(get-geode-build-id ${CONCOURSE_VERSION})
fi

DEFAULT_GRADLE_TASK_OPTIONS="--parallel --console=plain --no-daemon"

SSHKEY_FILE="instance-data/sshkey"
SSH_OPTIONS="-i ${SSHKEY_FILE} -o ConnectionAttempts=60 -o StrictHostKeyChecking=no"

INSTANCE_IP_ADDRESS="$(cat instance-data/instance-ip-address)"

SET_JAVA_HOME="export JAVA_HOME=/usr/lib/jvm/bellsoft-java${JAVA_BUILD_VERSION}-amd64"

GRADLE_COMMAND="./gradlew \
    ${DEFAULT_GRADLE_TASK_OPTIONS} \
    ${GRADLE_GLOBAL_ARGS} \
    -Pversion=${FULL_PRODUCT_VERSION} \
    -PbuildId=${BUILD_ID} \
    -PmavenRepository=\"${MAVEN_SNAPSHOT_BUCKET}\" \
    publish"

echo "${GRADLE_COMMAND}"
ssh ${SSH_OPTIONS} geode@${INSTANCE_IP_ADDRESS} "mkdir -p tmp \
  && cp geode/ci/scripts/attach_sha_to_branch.sh /tmp/ \
  && /tmp/attach_sha_to_branch.sh geode ${BUILD_BRANCH} \
  && cd geode \
  && ${SET_JAVA_HOME} \
  && ${GRADLE_COMMAND}"
