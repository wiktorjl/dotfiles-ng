#!/bin/bash

docker build . -t dotfiles-ng
docker run --hostname dotfiles-tester -it --rm dotfiles-ng