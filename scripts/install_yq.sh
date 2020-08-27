#!/bin/bash

cd /tmp
curl -L -o yq_linux_amd64 https://github.com/mikefarah/yq/releases/download/3.3.2/yq_linux_amd64
sudo cp ./yq_linux_amd64 /usr/local/bin/yq
sudo chmod 755 /usr/local/bin/yq

yq --version
