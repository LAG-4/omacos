#!/bin/zsh

case ${1:-} in
  -listallhardwareports) print -r -- $'Hardware Port: Wi-Fi\nDevice: en0\nEthernet Address: aa:bb:cc:dd:ee:ff' ;;
  -getairportnetwork) print 'Current Wi-Fi Network: OMacOS Test WiFi' ;;
  *) exit 1 ;;
esac
