#! /bin/bash

# Clean all files in .temp folder
rm .temp/*
contractPath=$1

IFS='/'
read -ra contractPathSplitted <<< "$contractPath"
contractFile=${contractPathSplitted[-1]} 

IFS='.'
read -ra contractFileSplitted <<< "$contractFile"
contractName=${contractFileSplitted[0]} 

IFS=''

# Flatten the smart contract and replace the license for AGPL-3.0
npx hardhat flatten $contractPath > .temp/$contractFile
sed -i '/SPDX-License-Identifier/d' .temp/$contractFile
sed -i '5s/.*/\/\/ SPDX-License-Identifier: AGPL-3.0/' .temp/$contractFile

# Compile and save the metadata file
solc --optimize --metadata --metadata-literal .temp/$contractFile > .temp/metadatas

# Extract the portion of the file that has the metadata of the contract we are interested
startMetadataContract=${contractFile}:${contractName}
echo $startMetadataContract
awk "/$startMetadataContract/, EOF" .temp/metadatas > .temp/metadata.json
sed -i "3,3!d" .temp/metadata.json 