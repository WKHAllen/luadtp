#!/bin/bash

test()
{
  local lua
  lua="$1"
  
  if [[ -z "$lua" ]]; then
    lua='lua'
  fi

  local tmpserverretcode
  local tmpserverstdout
  local tmpserverstderr
  local tmpclientretcode
  local tmpclientstdout
  local tmpclientstderr
  tmpserverretcode="$( mktemp tmp.testserverlua.retcode.XXXXXXXXXX )"
  tmpserverstdout="$( mktemp tmp.testserverlua.stdout.XXXXXXXXXX )"
  tmpserverstderr="$( mktemp tmp.testserverlua.stderr.XXXXXXXXXX )"
  tmpclientretcode="$( mktemp tmp.testclientlua.retcode.XXXXXXXXXX )"
  tmpclientstdout="$( mktemp tmp.testclientlua.stdout.XXXXXXXXXX )"
  tmpclientstderr="$( mktemp tmp.testclientlua.stderr.XXXXXXXXXX )"

  {
    "$lua" test/testserver.lua 1>"$tmpserverstdout" 2>"$tmpserverstderr";
    echo $? >"$tmpserverretcode"
  } &

  sleep 1

  {
    "$lua" test/testclient.lua 1>"$tmpclientstdout" 2>"$tmpclientstderr";
    echo $? >"$tmpclientretcode"
  }

  sleep 1

  local retcode
  local serverretcode
  local clientretcode
  retcode=0
  serverretcode="$( cat $tmpserverretcode )"
  clientretcode="$( cat $tmpclientretcode )"

  if [[ $serverretcode -ne 0 ]]; then
    echo
    echo "-------------------------------------------------------------------------------"
    echo "Server tests failed with return status $serverretcode"
    echo "Server tests stdout:"
    cat "$tmpserverstdout"
    echo "Server tests stderr:"
    cat "$tmpserverstderr"
    echo "-------------------------------------------------------------------------------"
    echo
    retcode=$serverretcode
  else
    echo
    echo "-------------------------------------------------------------------------------"
    echo "Server tests stdout:"
    cat "$tmpserverstdout"
    echo "-------------------------------------------------------------------------------"
    echo
  fi

  if [[ $clientretcode -ne 0 ]]; then
    echo
    echo "-------------------------------------------------------------------------------"
    echo "Client tests failed with return status $clientretcode"
    echo "Client tests stdout:"
    cat "$tmpclientstdout"
    echo "Client tests stderr:"
    cat "$tmpclientstderr"
    echo "-------------------------------------------------------------------------------"
    echo
    retcode=$clientretcode
  else
    echo
    echo "-------------------------------------------------------------------------------"
    echo "Client tests stdout:"
    cat "$tmpclientstdout"
    echo "-------------------------------------------------------------------------------"
    echo
  fi

  rm "$tmpserverretcode"
  rm "$tmpserverstdout"
  rm "$tmpserverstderr"
  rm "$tmpclientretcode"
  rm "$tmpclientstdout"
  rm "$tmpclientstderr"

  return $retcode
}

test "$@"; exit
