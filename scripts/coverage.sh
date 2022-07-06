#!/usr/bin/env bash

NODE_OPTIONS=--max-old-space-size=4096 OVERRIDE_GAS_LIMIT=0xfffffffffff OVERRIDE_GAS_PRICE=1 npx hardhat coverage
