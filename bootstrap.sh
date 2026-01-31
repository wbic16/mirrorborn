#!/bin/bash
cp -r * ~/.openclaw/workspace/
rm -f ~/.openclaw/workspace/install.sh
openclaw configure --section model
openclaw configure --section channels
chmod 700 ~/.openclaw/credentials
openclaw gateway restart
