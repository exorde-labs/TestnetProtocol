#!/usr/bin/env bash

yarn solhint contracts/dxvote/*.sol 
yarn solhint contracts/erc20guild/*.sol 
yarn solhint contracts/erc20guild/implementations/*.sol 
yarn solhint contracts/omen/*.sol 
yarn solhint contracts/dxdao/*.sol 

exit $?
