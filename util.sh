#!/bin/bash

LTS_VERSION="2.7.4"

function show_usage() {
  cat <<EOF

usage: ./util.sh <ACTION> [VERSION]

<ACTION>:
  build    - build image
  push     - push image to docker hub
  docker   - run jenkins-server in docker
  hyper    - run jenkins-server in Hyper_

[VERSION]:
  lts             - jenkins             -> hyperhq/hyperkins:<LTS_VERSION>, latest
  latest          - jenkinsci/jenkins   -> hyperhq/hyperkins:dev-<ver>, dev-latest
  <specified_ver> - jenkinsci/jenkins   -> hyprehq/hyperkins:dev-<ver>

EOF
  exit 1
}

function fn_build() {
  docker build --pull \
    --tag hyperhq/hyperkins:${TAG} .
}

function fn_push() {

  echo "--------------------------------------------------"
  echo "starting push [hyperhq/hyperkins:${TAG}]"
  docker push hyperhq/hyperkins:${TAG}

  if [ "${LATEST_TAG}" != "" ];then
    echo "--------------------------------------------------"
    echo "starting push [hyperhq/hyperkins:latest]"
    docker tag hyperhq/hyperkins:${TAG} hyperhq/hyperkins:${LATEST_TAG}
    docker push hyperhq/hyperkins:${LATEST_TAG}
  fi
}

function fn_run_in_docker() {
  echo ">delete old container"
  docker rm -v -f jenkins-server-dev >/dev/null 2>&1
  echo ">start new container in docker"
  docker run --name jenkins-server-dev \
    -d -P \
    hyperhq/hyperkins
}

function fn_run_in_hyper() {
  echo ">delete old container"
  hyper rm -v -f jenkins-server-dev >/dev/null 2>&1
  echo ">pull image hyperhq/hyperkins"
  hyper pull hyperhq/hyperkins
  echo ">start new container in hyper"
  hyper run --name jenkins-server-dev \
    -d -P \
    hyperhq/hyperkins
  cat <<EOF

---------------------------------------
#add fip to hyper container
\$ FIP=\$(hyper fip allocate 1)
\$ hyper fip attach \$FIP jenkins-server
---------------------------------------
EOF
}



###########################################################
# main
###########################################################
#set -e
set +x

ACTION=$1
VERSION=$2

if [ $# -eq 0 ];then
  show_usage
fi

case "${VERSION}" in
  "lts"|"")
   JENKINS_VERSION=${LTS_VERSION}
   TAG="${JENKINS_VERSION}"
   LATEST_TAG="latest"
   JENKINS_REPO="jenkins"
  ;;
 "latest")
  JENKINS_VERSION=`curl -sq https://api.github.com/repos/jenkinsci/jenkins/tags | grep '"name":' | grep -o '[0-9]\.[0-9]*'  | uniq | sort --version-sort | tail -1`
  TAG="dev-${JENKINS_VERSION}"
  LATEST_TAG="dev-latest"
  JENKINS_REPO="jenkinsci/jenkins"
 ;;
 *)
  JENKINS_VERSION=${VERSION}
  TAG="dev-${JENKINS_VERSION}"
  LATEST_TAG=""
  JENKINS_REPO="jenkinsci/jenkins"
 ;;
esac

sed "s/%JENKINS_REPO%/${JENKINS_REPO}/g" Dockerfile.template > Dockerfile
sed -i "s/%JENKINS_VERSION%/${JENKINS_VERSION}/g" Dockerfile

cat <<EOF

VERSION          : ${VERSION}
JENKINS_VERSION  : ${JENKINS_VERSION}
TAG              : ${TAG}
LATEST_TAG       : ${LATEST_TAG}
JENKINS_REPO     : ${JENKINS_REPO}

EOF

case "${ACTION}" in
 "build")
    fn_build
 ;;
 "push")
    fn_build
    fn_push
  ;;
  "docker")
    fn_run_in_docker
  ;;
  "hyper")
    fn_run_in_hyper
  ;;
  *)
  show_usage
  ;;
esac
