#!/bin/bash
cp -r * ~/.openclaw/workspace/
rm -f ~/.openclaw/workspace/install.sh
openclaw gateway restart
