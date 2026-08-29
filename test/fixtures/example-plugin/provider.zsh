#!/bin/zsh

jq -nc --arg action "${1:-status}" '{schemaVersion:1,title:"Example Status",summary:$action,items:[]}'
