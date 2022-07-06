/* eslint-disable no-case-declarations */
require("@nomiclabs/hardhat-web3");

const contentHash = require("content-hash");
const IPFS = require("ipfs-core");

const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
const MAX_UINT_256 =
  "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
const ANY_FUNC_SIGNATURE = "0xaaaaaaaa";

const { encodePermission } = require("../test/helpers/permissions");
const moment = require("moment");
const { default: BigNumber } = require("bignumber.js");

task("deploy-dxvote", "Deploy dxvote in localhost network")
  .addParam("deployconfig", "The deploy config json in string format")
  .setAction(async ({ deployconfig }) => {
    function sleep(ms) {
      return new Promise(resolve => setTimeout(resolve, ms));
    }

    let addresses = {};
    

    // Parse string json config to json object
    const deploymentConfig = JSON.parse(deployconfig);

    // Import contracts
    const DxAvatar = await hre.artifacts.require("DxAvatar");
    const DxReputation = await hre.artifacts.require("DxReputation");
    const DxController = await hre.artifacts.require("DxController");
    const ContributionReward = await hre.artifacts.require(
      "ContributionReward"
    );
    const Redeemer = await hre.artifacts.require("Redeemer");
    const WalletScheme = await hre.artifacts.require("WalletScheme");
    const PermissionRegistry = await hre.artifacts.require(
      "PermissionRegistry"
    );
    const RandomAllocator = await hre.artifacts.require("RandomAllocator");
    const AddressManager = await hre.artifacts.require("AddressManager");
    const StakingManager = await hre.artifacts.require("StakingManager");
    const RewardsManager = await hre.artifacts.require("RewardsManager");
    // --------------------------------
    const AttributeStore = artifacts.require('AttributeStore.sol');
    const DLL = artifacts.require('DLL.sol');
    const DataSpotting = await hre.artifacts.require("DataSpotting");
    // ---------------------------------
    const DXDVotingMachine = await hre.artifacts.require("DXDVotingMachine");
    const ERC20Mock = await hre.artifacts.require("ERC20Mock");
    const ERC20SnapshotRep = await hre.artifacts.require("ERC20SnapshotRep");
    const Multicall = await hre.artifacts.require("Multicall");
    const ERC721Factory = await hre.artifacts.require("ERC721Factory");
    const ERC20VestingFactory = await hre.artifacts.require(
      "ERC20VestingFactory"
    );

    async function waitBlocks(blocks) {
      const toBlock = (await web3.eth.getBlock("latest")).number + blocks;
      while ((await web3.eth.getBlock("latest")).number < toBlock) {
        await sleep(10);
      }
      return;
    }

    // Get ETH accounts to be used
    const accounts = await web3.eth.getAccounts();

    let deployer_account = accounts[8];
    console.log("Deployer account = ",deployer_account.toString())

    // Get fromBlock for network contracts
    const fromBlock = (await web3.eth.getBlock("latest")).number;

    // Set networkContracts object that will store the contracts deployed
    let networkContracts = {
      fromBlock: fromBlock,
      avatar: null,
      reputation: null,
      token: null,
      controller: null,
      permissionRegistry: null,
      schemes: {},
      utils: {},
      votingMachines: {},
    };

    // Get initial REP holders
    let founders = ["0x22Ff0428359EAB1644bf905DaD2733e7BF041E54"],
      initialRep = [10000];
    deploymentConfig.reputation.map(initialRepHolder => {
      founders.push(initialRepHolder.address);
      initialRep.push(initialRepHolder.amount.toString());
    });

    // Deploy Multicall
    let multicall;
    console.log("Deploying Multicall...");
    multicall = await Multicall.new();
    console.log("Multicall deployed to:", multicall.address);
    await waitBlocks(1);
    networkContracts.utils.multicall = multicall.address;

    // Deploy Reputation
    let reputation;
    console.log("Deploying DxReputation...");
    reputation = await DxReputation.new();
    console.log("Exorde Reputation deployed to:", reputation.address);
    networkContracts.reputation = reputation.address;
    addresses["Reputation"] = reputation.address;
    await waitBlocks(1);

    // Mint DXvote REP
    console.log(
      "mint initial REP to founders",
    );
    await reputation.mintMultiple(founders, initialRep);

    console.log(
      "waiting 1 blocks...",
    );
    await waitBlocks(1);

    // Deploy Tokens
    
    let tokens = {};

    console.log(
      "Token amount =  ",
    );
    let tokenTotalSupply = ethers.utils.parseUnits("200000000.0", 18).toString()
    console.log(ethers.utils.parseUnits("200000000.0", 18).toString());
    
    for (const tokenToDeploy of deploymentConfig.tokens){
      console.log(
          "Deploying token",
          tokenToDeploy.name,
          tokenToDeploy.symbol
        );
        const totalSupply = tokenToDeploy.distribution.reduce(function (
          prev,
          cur
        ) {
          return new BigNumber(prev).plus(cur.amount.toString());
        },
        0);

      let newToken;
      switch (tokenToDeploy.type) {
        case "ERC20":
          newToken = await ERC20Mock.new(accounts[0], tokenTotalSupply.toString());
          
          await waitBlocks(1);
          for (const tokenHolder of tokenToDeploy.distribution){
              await newToken.transfer(tokenHolder.address, tokenHolder.amount, {
                  from: accounts[0],
                });
          }
          break;
        case "ERC20SnapshotRep":
          newToken = await ERC20SnapshotRep.new();
          
          await waitBlocks(1);
          await newToken.initialize(
            tokenToDeploy.name,
            tokenToDeploy.symbol,
            {
              from: accounts[0],
            }
          );
          for (const tokenHolder of tokenToDeploy.distribution) {
            await newToken.mint(tokenHolder.address, tokenHolder.amount, {
              from: accounts[0],
            });
          }
          break;
      }
      
      tokens[tokenToDeploy.symbol] = newToken;
      addresses[tokenToDeploy.symbol] = newToken.address;
  }
    
    // await Promise.all(
    //   deploymentConfig.tokens.map(async tokenToDeploy => {
    //     console.log(
    //       "Deploying token",
    //       tokenToDeploy.name,
    //       tokenToDeploy.symbol
    //     );
    //     const totalSupply = tokenToDeploy.distribution.reduce(function (
    //       prev,
    //       cur
    //     ) {
    //       return new BigNumber(prev).plus(cur.amount.toString());
    //     },
    //     0);
        
    //     let newToken;
    //     switch (tokenToDeploy.type) {
    //       case "ERC20":
    //         newToken = await ERC20Mock.new(accounts[0], totalSupply.toString());
            
    //         await waitBlocks(1);
    //         await tokenToDeploy.distribution.map(async tokenHolder => {
    //           await newToken.transfer(tokenHolder.address, tokenHolder.amount, {
    //             from: accounts[0],
    //           });
    //         });
    //         break;
    //       case "ERC20SnapshotRep":
    //         newToken = await ERC20SnapshotRep.new();
            
    //         await waitBlocks(1);
    //         await newToken.initialize(
    //           tokenToDeploy.name,
    //           tokenToDeploy.symbol,
    //           {
    //             from: accounts[0],
    //           }
    //         );
    //         for (i in tokenToDeploy.distribution) {
    //           const tokenHolder = tokenToDeploy.distribution[i];
    //           await newToken.mint(tokenHolder.address, tokenHolder.amount, {
    //             from: accounts[0],
    //           });
    //         }
    //         break;
    //     }
    //     tokens[tokenToDeploy.symbol] = newToken;
    //     addresses[tokenToDeploy.symbol] = newToken.address;
    //   })
    // );

    console.log(
      "waiting 1 blocks...",
    );
    await waitBlocks(1);

    // Deploy Avatar
    let avatar;
    console.log(
      "Deploying DxAvatar...",
      tokens.EXDT.address,
      reputation.address
    );
    
    await waitBlocks(1);
    avatar = await DxAvatar.new(
      "ExordeDAO",
      tokens.EXDT.address,
      reputation.address
    );
    console.log("ExordeDAO Avatar deployed to:", avatar.address);
    console.log("ExordeDAO Token deployed to:", tokens.EXDT.address);
    networkContracts.avatar = avatar.address;
    networkContracts.token = addresses["EXDT"];
    addresses["Avatar"] = avatar.address;
    await waitBlocks(1);

    
    // Deploy Controller and transfer avatar to controller
    let controller;
    console.log("Deploying DxController...");
    controller = await DxController.new(avatar.address);
    console.log("ExordeDAO Controller deployed to:", controller.address);
    await avatar.transferOwnership(controller.address);
    await reputation.transferOwnership(controller.address);
    networkContracts.controller = controller.address;
    addresses["Controller"] = controller.address;
    await waitBlocks(1);


    // Deploy Staking & Rewards & Address Manager
    let staking_manager;
    let rewards_manager;
    let address_manager;
    console.log("Deploying Staking Manager...");
    staking_manager = await StakingManager.new(tokens.EXDT.address);
    addresses["StakingManager"] = staking_manager.address;
    console.log("Staking Manager deployed to ", staking_manager.address);
    rewards_manager = await RewardsManager.new(tokens.EXDT.address);
    console.log("Rewards Manager deployed to ", rewards_manager.address);
    addresses["RewardsManager"] = rewards_manager.address;
    console.log("Deploying Address Manager...");
    address_manager = await AddressManager.new();
    console.log("Address Manager deployed to ", address_manager.address);
    addresses["AddressManager"] = address_manager.address;

    console.log("Setting Address Manager in the Rewards Manager");
    await rewards_manager.updateAddressManager(address_manager.address);

    // Deploy WorkSystems
    let spot_worksystem;
    // lib_AttributeStore = await ethers.getContractFactory("lib_AttributeStore");
      
    let libAttributeStore;
    let libDLL;
    // AttributeStore = await ethers.getContractFactory("AttributeStore");
    libAttributeStore = await AttributeStore.new();
    console.log("Library AttributeStore addr",libAttributeStore.address);
    libDLL = await DLL.new();
    console.log("Library DLL addr",libDLL.address);

    console.log("Deploying DataSpotting System...");
    ////////////////////////////////////////      SPOTTING WORK SYSTEM     //////////////////////////////////////////

    const DataSpottingFactory = await ethers.getContractFactory("DataSpotting", {
      libraries: { 
        AttributeStore: libAttributeStore.address,
        DLL: libDLL.address           
      },
    });

    const _DataSpottingFactory = await DataSpottingFactory.deploy(tokens.EXDT.address);

    await _DataSpottingFactory.deployed();


    console.log("DataSpotting deployed to ", _DataSpottingFactory.address);
    spot_worksystem = _DataSpottingFactory;
    addresses["DataSpotting"] = _DataSpottingFactory.address;
    // register the worksystem as allowed to use stakes
    console.log("Add the DataSpotting as allowed to use stakes in StakingManager");
    await staking_manager.addAddress(spot_worksystem.address);    
    console.log("Add the DataSpotting as allowed to use stakes in RewardsManager");
    await rewards_manager.addAddress(spot_worksystem.address);

    


    // Deploy DXDVotingMachine
    let votingMachine;
    console.log("Deploying DXDVotingMachine...");
    votingMachine = await DXDVotingMachine.new(tokens.EXDT.address);
    console.log("DXDVotingMachine deployed to:", votingMachine.address);
    networkContracts.votingMachines[votingMachine.address] = {
      type: "DXDVotingMachine",
      token: tokens.EXDT.address,
    };
    await waitBlocks(1);
    await tokens.EXDT.approve(votingMachine.address, MAX_UINT_256, {
      from: accounts[0],
    });
    await tokens.EXDT.approve(votingMachine.address, MAX_UINT_256, {
      from: accounts[1],
    });
    await tokens.EXDT.approve(votingMachine.address, MAX_UINT_256, {
      from: accounts[2],
    });
    addresses["DXDVotingMachine"] = votingMachine.address;

    // Deploy PermissionRegistry to be used by WalletSchemes
    let permissionRegistry;
    console.log("Deploying PermissionRegistry...");
    permissionRegistry = await PermissionRegistry.new();
    await permissionRegistry.initialize();
    addresses["PermissionRegistry"] = permissionRegistry.address;


    
    // Deploy Multicall
    let randomallocator;
    console.log("Deploying RandomAllocator...");
    randomallocator = await RandomAllocator.new();
    console.log("RandomAllocator deployed to:", randomallocator.address);
    
    addresses["RandomAllocator"] = randomallocator.address;
    await waitBlocks(1);
    networkContracts.utils.randomallocator = randomallocator.address;

    // Only allow the functions mintReputation, burnReputation, genericCall, registerScheme and unregisterScheme to be
    // called to in the controller contract from a scheme that calls the controller.
    // This permissions makes the other functions inaccessible
    const notAllowedControllerFunctions = [
      controller.contract._jsonInterface.find(
        method => method.name === "mintTokens"
      ).signature,
      controller.contract._jsonInterface.find(
        method => method.name === "unregisterSelf"
      ).signature,
      controller.contract._jsonInterface.find(
        method => method.name === "addGlobalConstraint"
      ).signature,
      controller.contract._jsonInterface.find(
        method => method.name === "removeGlobalConstraint"
      ).signature,
      controller.contract._jsonInterface.find(
        method => method.name === "upgradeController"
      ).signature,
      controller.contract._jsonInterface.find(
        method => method.name === "sendEther"
      ).signature,
      controller.contract._jsonInterface.find(
        method => method.name === "externalTokenTransfer"
      ).signature,
      controller.contract._jsonInterface.find(
        method => method.name === "externalTokenTransferFrom"
      ).signature,
      controller.contract._jsonInterface.find(
        method => method.name === "externalTokenApproval"
      ).signature,
      controller.contract._jsonInterface.find(
        method => method.name === "metaData"
      ).signature,
    ];

    for (var i = 0; i < notAllowedControllerFunctions.length; i++) {
      await permissionRegistry.setPermission(
        NULL_ADDRESS,
        avatar.address,
        controller.address,
        notAllowedControllerFunctions[i],
        MAX_UINT_256,
        false
      );
    }

    await permissionRegistry.setPermission(
      NULL_ADDRESS,
      avatar.address,
      controller.address,
      ANY_FUNC_SIGNATURE,
      0,
      true
    );

    console.log("Permission Registry deployed to:", permissionRegistry.address);
    networkContracts.permissionRegistry = permissionRegistry.address;
    addresses["PermissionRegstry"] = permissionRegistry.address;
    await waitBlocks(1);

    // Deploy ContributionReward Scheme
    console.log("Deploying ContributionReward scheme");
    const contributionReward = await ContributionReward.new();
    const redeemer = await Redeemer.new();

    // The ContributionReward scheme was designed by DAOstack to be used as an universal scheme,
    // which means that index the voting params used in the voting machine hash by voting machine
    // So the voting parameters are set in the voting machine, and that voting parameters hash is registered in the ContributionReward
    // And then other voting parameter hash is calculated for that voting machine and contribution reward, and that is the one used in the controller
    const contributionRewardParamsHash = await votingMachine.getParametersHash(
      [
        deploymentConfig.contributionReward.queuedVoteRequiredPercentage.toString(),
        deploymentConfig.contributionReward.queuedVotePeriodLimit.toString(),
        deploymentConfig.contributionReward.boostedVotePeriodLimit.toString(),
        deploymentConfig.contributionReward.preBoostedVotePeriodLimit.toString(),
        deploymentConfig.contributionReward.thresholdConst.toString(),
        deploymentConfig.contributionReward.quietEndingPeriod.toString(),
        deploymentConfig.contributionReward.proposingRepReward.toString(),
        deploymentConfig.contributionReward.votersReputationLossRatio.toString(),
        deploymentConfig.contributionReward.minimumDaoBounty.toString(),
        deploymentConfig.contributionReward.daoBountyConst.toString(),
        0,
      ],
      NULL_ADDRESS,
      { from: accounts[0], gasPrice: 0 }
    );
    await votingMachine.setParameters(
      [
        deploymentConfig.contributionReward.queuedVoteRequiredPercentage.toString(),
        deploymentConfig.contributionReward.queuedVotePeriodLimit.toString(),
        deploymentConfig.contributionReward.boostedVotePeriodLimit.toString(),
        deploymentConfig.contributionReward.preBoostedVotePeriodLimit.toString(),
        deploymentConfig.contributionReward.thresholdConst.toString(),
        deploymentConfig.contributionReward.quietEndingPeriod.toString(),
        deploymentConfig.contributionReward.proposingRepReward.toString(),
        deploymentConfig.contributionReward.votersReputationLossRatio.toString(),
        deploymentConfig.contributionReward.minimumDaoBounty.toString(),
        deploymentConfig.contributionReward.daoBountyConst.toString(),
        0,
      ],
      NULL_ADDRESS
    );
    await contributionReward.setParameters(
      contributionRewardParamsHash,
      votingMachine.address
    );
    const contributionRewardVotingmachineParamsHash =
      await contributionReward.getParametersHash(
        contributionRewardParamsHash,
        votingMachine.address
      );
    await controller.registerScheme(
      contributionReward.address,
      contributionRewardVotingmachineParamsHash,
      encodePermission({
        canGenericCall: true,
        canUpgrade: false,
        canRegisterSchemes: false,
      }),
      avatar.address
    );

    networkContracts.daostack = {
      [contributionReward.address]: {
        contractToCall: controller.address,
        creationLogEncoding: [
          [
            {
              name: "_descriptionHash",
              type: "string",
            },
            {
              name: "_reputationChange",
              type: "int256",
            },
            {
              name: "_rewards",
              type: "uint256[5]",
            },
            {
              name: "_externalToken",
              type: "address",
            },
            {
              name: "_beneficiary",
              type: "address",
            },
          ],
        ],
        name: "ContributionReward",
        newProposalTopics: [
          [
            "0xcbdcbf9aaeb1e9eff0f75d74e1c1e044bc87110164baec7d18d825b0450d97df",
            "0x000000000000000000000000519b70055af55a007110b4ff99b0ea33071c720a",
          ],
        ],
        redeemer: redeemer.address,
        supported: true,
        type: "ContributionReward",
        voteParams: contributionRewardVotingmachineParamsHash,
        votingMachine: votingMachine.address,
      },
    };
    addresses["ContributionReward"] = contributionReward.address;

    // Deploy Wallet Schemes


    let masterWallet;

    console.log(`\nDeploy Wallet Schemes...`);
    for (var s = 0; s < deploymentConfig.walletSchemes.length; s++) {
      const schemeConfiguration = deploymentConfig.walletSchemes[s];

      console.log(`Deploying ${schemeConfiguration.name}...`);
      const newScheme = await WalletScheme.new();
      if (schemeConfiguration.name == "MasterWalletScheme"){
        masterWallet = newScheme;
      }
      console.log(
        `${schemeConfiguration.name} deployed to: ${newScheme.address}`
      );

      // This is simpler than the ContributionReward, just register the params in the VotingMachine and use that ones for the schem registration
      let schemeParamsHash = await votingMachine.getParametersHash(
        [
          schemeConfiguration.queuedVoteRequiredPercentage.toString(),
          schemeConfiguration.queuedVotePeriodLimit.toString(),
          schemeConfiguration.boostedVotePeriodLimit.toString(),
          schemeConfiguration.preBoostedVotePeriodLimit.toString(),
          schemeConfiguration.thresholdConst.toString(),
          schemeConfiguration.quietEndingPeriod.toString(),
          schemeConfiguration.proposingRepReward.toString(),
          schemeConfiguration.votersReputationLossRatio.toString(),
          schemeConfiguration.minimumDaoBounty.toString(),
          schemeConfiguration.daoBountyConst.toString(),
          0,
        ],
        NULL_ADDRESS,
        { from: accounts[0], gasPrice: 0 }
      );

      await votingMachine.setParameters(
        [
          schemeConfiguration.queuedVoteRequiredPercentage.toString(),
          schemeConfiguration.queuedVotePeriodLimit.toString(),
          schemeConfiguration.boostedVotePeriodLimit.toString(),
          schemeConfiguration.preBoostedVotePeriodLimit.toString(),
          schemeConfiguration.thresholdConst.toString(),
          schemeConfiguration.quietEndingPeriod.toString(),
          schemeConfiguration.proposingRepReward.toString(),
          schemeConfiguration.votersReputationLossRatio.toString(),
          schemeConfiguration.minimumDaoBounty.toString(),
          schemeConfiguration.daoBountyConst.toString(),
          0,
        ],
        NULL_ADDRESS
      );

      // The Wallet scheme has to be initialized right after being created
      console.log("Initializing scheme...");
      await newScheme.initialize(
        avatar.address,
        votingMachine.address,
        schemeConfiguration.doAvatarGenericCalls,
        controller.address,
        permissionRegistry.address,
        schemeConfiguration.name,
        schemeConfiguration.maxSecondsForExecution,
        schemeConfiguration.maxRepPercentageChange
      );

      // Set the initial permissions in the WalletScheme
      console.log("Setting scheme permissions...");
      for (var p = 0; p < schemeConfiguration.permissions.length; p++) {
        const permission = schemeConfiguration.permissions[p];
        if (permission.to === "ITSELF") permission.to = newScheme.address;
        else if (addresses[permission.to])
          permission.to = addresses[permission.to];

        await permissionRegistry.setPermission(
          addresses[permission.asset] || permission.asset,
          schemeConfiguration.doAvatarGenericCalls
            ? avatar.address
            : newScheme.address,
          addresses[permission.to] || permission.to,
          permission.functionSignature,
          permission.value.toString(),
          permission.allowed
        );
      }

      // // console.log("Setting WorkSystems scheme permissions..");
      // console.log("\nSetting Staking Manager scheme permissions..");
      // await controller.registerScheme(
      //   spot_worksystem.address,
      //   "mintReputation",
      //   encodePermission({
      //     canGenericCall: false,
      //     canUpgrade: false,
      //     canRegisterSchemes: false,
      //   }),
      //   avatar.address
      // );


      // Set the boostedVoteRequiredPercentage
      if (schemeConfiguration.boostedVoteRequiredPercentage > 0) {
        console.log(
          "Setting boosted vote required percentage in voting machine..."
        );
        await controller.genericCall(
          votingMachine.address,
          web3.eth.abi.encodeFunctionCall(
            {
              name: "setBoostedVoteRequiredPercentage",
              type: "function",
              inputs: [
                {
                  type: "address",
                  name: "_scheme",
                },
                {
                  type: "bytes32",
                  name: "_paramsHash",
                },
                {
                  type: "uint256",
                  name: "_boostedVotePeriodLimit",
                },
              ],
            },
            [
              newScheme.address,
              schemeParamsHash,
              schemeConfiguration.boostedVoteRequiredPercentage,
            ]
          ),
          avatar.address,
          0
        );
      }

      // Finally the scheme is configured and ready to be registered
      console.log("Registering scheme in controller...");
      await controller.registerScheme(
        newScheme.address,
        schemeParamsHash,
        encodePermission(schemeConfiguration.controllerPermissions),
        avatar.address
      );

      networkContracts.schemes[schemeConfiguration.name] = newScheme.address;
      addresses[schemeConfiguration.name] = newScheme.address;
    }

    // --------------------- MASTER WALLET REPUTATION FOR WORKSYSTEMS
    console.log("\n\nAdd the DataSpotting (And other worksystems) as allowed to mint Reputation in MasterWallet");
    await masterWallet.addWorksystemAddress(spot_worksystem.address);

    

    // --------------------- WORKSYSTEMS: LINK Stake, Rewards, Rep & Address to the system
    await spot_worksystem.updateStakeManager(staking_manager.address);    
    await spot_worksystem.updateRewardManager(rewards_manager.address);    
    await spot_worksystem.updateRepManager(masterWallet.address);
    await spot_worksystem.updateAddressManager(masterWallet.address);
    

    // give back all ownerships to the DAO controller
    console.log("Give back all ownerships to the DAO controller... (StakingManager & Worksystems)\n");
    await spot_worksystem.transferOwnership(controller.address);
    await staking_manager.transferOwnership(controller.address);

    // Deploy dxDaoNFT
    let dxDaoNFT;
    console.log("Deploying ERC721Factory...");
    dxDaoNFT = await ERC721Factory.new("DX DAO NFT", "DXDNFT");
    networkContracts.utils.dxDaoNFT = dxDaoNFT.address;
    addresses["ERC721Factory"] = dxDaoNFT.address;

    // Deploy ERC20VestingFactory
    let dxdVestingFactory;
    console.log("Deploying ERC20VestingFactory...");
    dxdVestingFactory = await ERC20VestingFactory.new(
      networkContracts.votingMachines[votingMachine.address].token,
      avatar.address
    );
    networkContracts.utils.dxdVestingFactory = dxdVestingFactory.address;
    addresses["ERC20VestingFactory"] = dxdVestingFactory.address;

    // Transfer all ownership and power to the dao
    console.log("Transfering ownership...");
    // Set the in the permission registry
    console.log("permissionRegistry: transferOwnership...");
    await permissionRegistry.transferOwnership(avatar.address);
    console.log("dxDaoNFT: transferOwnership...");
    await dxDaoNFT.transferOwnership(avatar.address);
    console.log("controller: unregisterScheme...");
    await controller.unregisterScheme(accounts[0], avatar.address);

    console.log("Done...");
    let proposals = {
      dxvote: [],
    };

    const startTime = deploymentConfig.startTimestampForActions;

    // console.log("evm_increaseTime..");
    // // Increase time to start time for actions
    // await hre.network.provider.request({
    //   method: "evm_increaseTime",
    //   params: [startTime - (await web3.eth.getBlock("latest")).timestamp],
    // });
    console.log("\nExecute actions now..");

    const ipfs = await IPFS.create();

    // Execute a set of actions once all contracts are deployed
    for (let i = 0; i < deploymentConfig.actions.length; i++) {
      const action = deploymentConfig.actions[i];

      console.log("i:", i);
      // if (action.time)
      //   await network.provider.send("evm_increaseTime", [action.time]);
      console.log("Executing action:", action);
      
      switch (action.type) {
        case "approve":
          await tokens[action.data.asset].approve(
            addresses[action.data.address] || action.data.address,
            action.data.amount,
            { from: action.from }
          );
          break;

        case "transfer":
          action.data.asset === NULL_ADDRESS
            ? await web3.eth.sendTransaction({
                to: addresses[action.data.address] || action.data.address,
                value: action.data.amount,
                from: action.from,
              })
            : await tokens[action.data.asset].transfer(
                addresses[action.data.address] || action.data.address,
                action.data.amount,
                { from: action.from }
              );
          break;

        case "proposal":
          const proposalDescriptionHash = (
            await ipfs.add(
              JSON.stringify({
                description: action.data.description,
                title: action.data.title,
                tags: action.data.tags,
                url: "",
              })
            )
          ).cid.toString();
          const proposalCreationTx =
            action.data.scheme === "ContributionReward"
              ? await (
                  await ContributionReward.at(contributionReward.address)
                ).proposeContributionReward(
                  avatar.address,
                  contentHash.fromIpfs(proposalDescriptionHash),
                  action.data.reputationChange,
                  action.data.rewards,
                  action.data.externalToken,
                  action.data.beneficiary,
                  { from: action.from }
                )
              : await (
                  await WalletScheme.at(addresses[action.data.scheme])
                ).proposeCalls(
                  action.data.to.map(_to => addresses[_to] || _to),
                  action.data.callData,
                  action.data.value,
                  action.data.title,
                  contentHash.fromIpfs(proposalDescriptionHash),
                  { from: action.from }
                );
          proposals.dxvote.push(
            proposalCreationTx.receipt.logs[0].args._proposalId
          );
          break;
        case "vote":
          await votingMachine.vote(
            proposals.dxvote[action.data.proposal],
            action.data.decision,
            action.data.amount,
            action.from,
            { from: action.from }
          );
          break;
        case "stake":
          await votingMachine.stake(
            proposals.dxvote[action.data.proposal],
            action.data.decision,
            action.data.amount,
            { from: action.from }
          );
          break;
        case "execute":
          try {
            await votingMachine.execute(
              proposals.dxvote[action.data.proposal],
              {
                from: action.from,
                gas: 9000000,
              }
            );
          } catch (error) {
            console.log("Execution of proposal failed", error);
          }
          break;
        case "redeem":
          await votingMachine.redeem(
            proposals.dxvote[action.data.proposal],
            action.from,
            { from: action.from }
          );
          break;        
        default:
          break;
      }
    }

    // // Increase time to local time
    // await hre.network.provider.request({
    //   method: "evm_increaseTime",
    //   params: [moment().unix() - (await web3.eth.getBlock("latest")).timestamp],
    // });

    console.log(JSON.stringify(addresses));

    return { networkContracts, addresses };
  });
