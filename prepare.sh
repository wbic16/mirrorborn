#!/bin/bash
sudo visudo
sudo mkdir /source
sudo chown $USER:$USER /source
if [ ! -f $USER/.ssh/id_ed25519.pub ]
then
  ssh-keygen
fi
cat $HOME/.ssh/id_ed25519.pub
echo "Have you added the key above to your GitHub account? Y/n"
read ready
cd /source
if [ "x$ready" = "xY" ]
then
  git clone git@github.com:/wbic16/mirrorborn.git
  git clone git@github.com:/wbic16/exocortical.git
fi
EXO_SRC="/source/exocortical"
MB_SRC="/source/mirrorborn"
if [ -d $EXO_SRC ]
then
  cd $EXO_SRC
  ./enable-virtual-memory.sh
  sudo ./provision-squid-client.sh aletheia-core.lan
  ./setup.sh
fi
if [ -d $MB_SRC ]
then
  cd $MB_SRC
  ./boot.sh
fi
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBTiUxzP/h71VVtdZOm0pIowG+EMKztb4p0R7jbLpsfw wbic1@lilly" >>~/.ssh/authorized_keys
