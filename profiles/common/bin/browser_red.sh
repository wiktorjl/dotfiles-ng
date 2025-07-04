#!/bin/sh

#xpra start ssh:seed@redbrowser --start-child=firefox --exit-with-children --dpi=96 --resize-display=yes --border=no
ssh -Y redbrowser firefox
