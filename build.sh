#!/bin/bash
cd /source/human
git pull
cd /source/mirrorborn
cp ../human/choose-your-own-adventure.phext phexts/
cp ../human/incipit.phext phexts/
cp ../human/dogfood.phext phexts/
git status
