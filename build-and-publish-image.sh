#!/usr/bin/env bash

VERSION=0.1.0

docker build -t ghcr.io/gimlet-io/gimlet-cli:$VERSION .

docker push ghcr.io/gimlet-io/gimlet-cli:$VERSION
