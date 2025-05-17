#!/bin/bash

rm -i dotfiles.tar.gz

mkdir -p build/defenv
cp aliases \
   bashrc \
   config \
   kali.sh \
   package.sh \
   installs.sh build/defenv

tar czfv  dotfiles.tar.gz -C build .


