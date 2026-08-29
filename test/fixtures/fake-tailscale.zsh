#!/bin/zsh

if [[ ${1:-} == "status" ]]; then
  print -r -- '{"Self":{"Online":true},"CurrentTailnet":{"Name":"example.net"},"Peer":{"node-1":{"ID":"node-1","HostName":"studio","DNSName":"studio.example.net.","TailscaleIPs":["100.64.0.2"],"Online":true}}}'
fi
