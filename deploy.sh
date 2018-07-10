#!/bin/bash

sudo docker login --username=${DOCKER_USER} --password=${DOCKER_PASSWORD}
sudo docker push ${DOCKER_SLUG}
