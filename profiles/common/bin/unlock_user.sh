#!/bin/sh

if [ -z $1 ]; then
	echo "Must provide username...."
	exit 1
fi

echo "Unlocking user $1"
sudo faillock --user $1 --reset
