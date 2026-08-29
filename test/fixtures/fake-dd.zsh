#!/bin/zsh

if [[ " $* " == *' if=/dev/zero '* ]]; then
  print -u2 '67108864 bytes transferred in 0.268 secs (250000000 bytes/sec)'
else
  print -u2 '67108864 bytes transferred in 0.134 secs (500000000 bytes/sec)'
fi
