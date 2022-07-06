require("@nomiclabs/hardhat-web3");
const contracts = require("../.contracts.json");

task("create2", "Deploy a smart contract using create2")
  .addParam("contract", "The contract name")
  .addParam("salt", "The salt to be used in the create2 deployment")
  .addOptionalParam("initializer", "The initialization arguments")
  .setAction(async ({ contract, salt, initializer }) => {
    function create2Address(creatorAddress, bytecode, saltHex) {
      const parts = [
        "ff",
        creatorAddress.slice(2),
        saltHex.slice(2),
        web3.utils.sha3(bytecode).slice(2),
      ];
      const partsHash = web3.utils.sha3(`0x${parts.join("")}`);
      return `0x${partsHash.slice(-40)}`.toLowerCase();
    }

    const deployerAccount = (await web3.eth.getAccounts())[0];
    const create2DeployFactory =
      contracts[hre.network.name].utils.create2Deployer;
    const toBeDeployed = await hre.artifacts.require(contract);

    const futureAddress = create2Address(
      create2DeployFactory,
      toBeDeployed.bytecode,
      web3.eth.abi.encodeParameter("uint256", salt)
    );
    const codeInAddress = await web3.eth.getCode(futureAddress);

    if (codeInAddress.length > 2) {
      console.error("Contract already deployed");
    } else {
      const create2Deployer = await hre.artifacts
        .require("Create2Deployer")
        .at(contracts[hre.network.name].utils.create2Deployer);

      const deployTx = await create2Deployer.deploy(
        toBeDeployed.bytecode,
        salt,
        { from: deployerAccount }
      );

      const deployedAddress = deployTx.logs[0].args.addr;

      console.log("Deployed address:", deployedAddress);

      if (initializer) {
        console.log("Initializing contract...");
        const deployedContract = await toBeDeployed.at(deployedAddress);
        await deployedContract.initialize(...initializer.split(","), {
          from: deployerAccount,
        });
      }
    }
  });
