const fs = require("fs");
const hre = require("hardhat");
const web3 = hre.web3;
require("dotenv").config();
const BN = web3.utils.BN;

// Get network to use from arguments
const repTokenAddress = {
  mainnet: "0x7a927a93f221976aae26d5d077477307170f0b7c",
  xdai: "0xED77eaA9590cfCE0a126Bab3D8A6ada9A393d4f6",
};

const mainnetRepMapping = "0x458c390a29c6bed4aec37499b525b95eb0de217d";

const fromBlock = process.env.REP_FROM_BLOCK;
const toBlock = process.env.REP_TO_BLOCK;

const DxReputation = artifacts.require("DxReputation");

console.log(
  "Getting rep holders from",
  repTokenAddress[hre.network.name],
  hre.network.name,
  fromBlock,
  toBlock
);

async function main() {
  const DXRep = await DxReputation.at(repTokenAddress[hre.network.name]);
  const allEvents = await DXRep.getPastEvents("allEvents", {
    fromBlock,
    toBlock,
  });
  let addresses = {};

  // Get all REP form mints and burns
  for (var i = 0; i < allEvents.length; i++) {
    if (allEvents[i].event === "Mint") {
      const mintedRep = new BN(allEvents[i].returnValues._amount.toString());
      const toAddress = web3.utils.toChecksumAddress(
        allEvents[i].returnValues._to
      );
      if (addresses[toAddress]) {
        addresses[toAddress] = addresses[toAddress].add(mintedRep);
      } else {
        addresses[toAddress] = mintedRep;
      }
    }
  }
  for (i = 0; i < allEvents.length; i++) {
    if (allEvents[i].event === "Burn") {
      const burnedRep = new BN(allEvents[i].returnValues._amount.toString());
      const fromAddress = web3.utils.toChecksumAddress(
        allEvents[i].returnValues._from
      );
      addresses[fromAddress] = addresses[fromAddress].sub(burnedRep);
    }
  }

  // Get REP from mapping if script runs on mainnet
  if (hre.network.name === "mainnet") {
    const mappingLogs = await web3.eth.getPastLogs({
      fromBlock: 10911798,
      address: mainnetRepMapping,
    });
    for (i = 0; i < mappingLogs.length; i++) {
      if (
        mappingLogs[i].topics[2] ===
        "0xac3e2276e49f2e2937cb1feecb361dd733fd0de8711789aadbd4013a2e0dac14"
      ) {
        const fromAddress = web3.eth.abi.decodeParameter(
          "address",
          mappingLogs[i].topics[1]
        );
        const toAddress = web3.eth.abi.decodeLog(
          [
            {
              type: "string",
              name: "value",
              indexed: false,
            },
          ],
          mappingLogs[i].data
        ).value;
        if (
          web3.utils.isAddress(toAddress) &&
          addresses[fromAddress] &&
          addresses[fromAddress] > 0 &&
          fromAddress !== toAddress
        ) {
          console.log(
            "REP mapping from",
            addresses[fromAddress].toString(),
            fromAddress,
            "to",
            toAddress
          );
          if (addresses[toAddress])
            addresses[toAddress] = addresses[toAddress].add(
              addresses[fromAddress]
            );
          else addresses[toAddress] = addresses[fromAddress];
          delete addresses[fromAddress];
        }
      }
    }
  }

  let repHolders = {
    fromBlock: fromBlock,
    toBlock: toBlock,
    totalRep: new BN(0),
    network: hre.network.name,
    repToken: repTokenAddress[hre.network.name],
    validAddresses: [],
    invalidAddresses: [],
  };
  for (var address in addresses) {
    if ((await web3.eth.getCode(address)) === "0x") {
      repHolders.totalRep = repHolders.totalRep.add(addresses[address]);
      repHolders.validAddresses.push({
        address,
        amount: addresses[address].toString(),
      });
    } else {
      repHolders.invalidAddresses.push({
        address,
        amount: addresses[address].toString(),
      });
    }
  }

  repHolders.validAddresses = repHolders.validAddresses.sort(
    (a, b) => b.amount - a.amount
  );
  console.log("REP Holders: (address, amount)");
  repHolders.validAddresses.map(a => console.log(a.address, a.amount));
  repHolders.totalRep = repHolders.totalRep.toString();
  console.log("REP Holders .json file:", repHolders);
  fs.writeFileSync(".repHolders.json", JSON.stringify(repHolders, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
