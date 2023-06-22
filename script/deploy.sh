#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs) 
else
    echo "Please set your .env file"
    exit 1
fi


forge script scripts/Deploy.s.sol:Deploy --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast