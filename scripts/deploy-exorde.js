/* eslint-disable no-case-declarations */
require("@nomiclabs/hardhat-web3");
require('hardhat-contract-sizer');

console.log("START")
const contentHash = require("content-hash");
const IPFS = require("ipfs-core");

const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
const MAX_UINT_256 =
  "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
const ANY_FUNC_SIGNATURE = "0xaaaaaaaa";

const { encodePermission } = require("../test/helpers/permissions");
const moment = require("moment");
const { default: BigNumber } = require("bignumber.js");
const { format } = require("prettier");


console.log("Selecting Task...")

task("deploy-exorde", "Deploy exorde in localhost network")
  .addParam("deployconfig", "The deploy config json in string format")
  .setAction(async ({ deployconfig }) => {

    function sleep(ms) {
      return new Promise(resolve => setTimeout(resolve, ms));
    }

    let addresses = {};
    
    const latest_block = await web3.eth.getBlock("latest");
    console.log("latest_block = ",latest_block['number'])


    console.log("Parsing Json Config...")
    // Parse string json config to json object
    const deploymentConfig = JSON.parse(deployconfig);

    // Import contracts
    console.log("Importing contracts...")
    const ExordeAvatar = await hre.artifacts.require("ExordeAvatar");
    const ExordeReputation = await hre.artifacts.require("ExordeReputation");
    const ExordeController = await hre.artifacts.require("ExordeController");
    // const ContributionReward = await hre.artifacts.require(
    //   "ContributionReward"
    // );
    // const Redeemer = await hre.artifacts.require("Redeemer");
    const WalletScheme = await hre.artifacts.require("WalletScheme");
    const PermissionRegistry = await hre.artifacts.require(
      "PermissionRegistry"
    );
    const SFuelContracts = await hre.artifacts.require("SFuelContracts");
    const Statistics = await hre.artifacts.require("Statistics");
    const ConfigRegistry = await hre.artifacts.require("ConfigRegistry");
    const RandomAllocator = await hre.artifacts.require("RandomAllocator");
    const AddressManager = await hre.artifacts.require("AddressManager");
    const StakingManager = await hre.artifacts.require("StakingManager");
    const RewardsManager = await hre.artifacts.require("RewardsManager");
    const Parameters = await hre.artifacts.require("Parameters");
    // --------------------------------
    const DLL = artifacts.require('DLL.sol');
    // const DLL2 = artifacts.require('DLL2.sol');
    // const DLL3 = artifacts.require('DLL3.sol');
    // const DLL4 = artifacts.require('DLL4.sol');
    const DataSpotting = await hre.artifacts.require("DataSpotting");
    // const DataCompliance = await hre.artifacts.require("DataCompliance");
    // const DataIndexing = await hre.artifacts.require("DataIndexing");
    // const DataArchive = await hre.artifacts.require("DataArchive");
    // ---------------------------------
    // const exordeVotingMachine = await hre.artifacts.require("exordeVotingMachine");
    const ERC20Mock = await hre.artifacts.require("ExordeToken");
    // const ERC20SnapshotRep = await hre.artifacts.require("ERC20SnapshotRep");
    // const Multicall = await hre.artifacts.require("Multicall");
    // const ERC721Factory = await hre.artifacts.require("ERC721Factory");
    // const ERC20VestingFactory = await hre.artifacts.require(
    //   "ERC20VestingFactory"
    // );

    async function waitBlocks(blocks) {
      const toBlock = (await web3.eth.getBlock("latest")).number + blocks;
      while ((await web3.eth.getBlock("latest")).number < toBlock) {
        await sleep(1);
      }
      return;
    }


    const networkName = hre.network.name;
    let deployer_account;
    console.log("Get Accounts...")
    const accounts = await web3.eth.getAccounts();
    console.log("Current Network = ",networkName)
    if(networkName.startsWith('schain')){
      console.log("Using schain, with specific deployer account")
      deployer_account = accounts[0];
    }
    else{
      console.log("NOT Using schain")
      deployer_account = accounts[8];
    }
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
    let founders = ["0x274469A77a3f47EBD3Df5CA5B4D5f0267f431e6b","0x3997c75659920Bd24eCeBB542D9DaB624Cc0D105"],
      initialRep = [100000,100000];
    deploymentConfig.reputation.map(initialRepHolder => {
      founders.push(initialRepHolder.address);
      initialRep.push(initialRepHolder.amount.toString());
    });

    // --------------------------------- EXISTING CONTRACTS ADDRESS ---------------------------------
    let SFuelContractsAddress;
    let ConfigRegistryAddress;
    let AddressManagerAddress;
    let StatisticsAddress;
    let DataArchiveAddress;
    let EXDTTokenAddress;
    let RewardsManagerAddress;
    let MasterWalletAddress;
    let PermissionRegistryAddress;
    let StakingManagerAddress;
    let ReputationAddress;
    let AvatarAddress;
    let ControllerAddress;  
    let ParametersAddress;

    let _DataSpottingAddress;
    let _DataComplianceAddress;
    let _DataIndexingAddress;
    let _DataArchivingAddress;

  // -------------------------------
    let IMPORT_DEPLOYED_TOKEN = true; //exd token, 
    let IMPORT_DEPLOYED_CORE = true; //controller, staking & rewards manager everything except worksystems
    let IMPORT_DEPLOYED_BASE = true; // config and address
    let IMPORT_DEPLOYED_WS = true; //worksystems

    let enable_debug_only_spotting_ws = true;
  // -------------------------------
  // WORK SYSTEM DEPLOYED ADDRESSES (if not deployed_ws):
  
    let mainnet_selected = false;

    if(networkName.startsWith('schain_mainnet')){
      mainnet_selected = true;
    }
  
    if(IMPORT_DEPLOYED_CORE){        
      console.log("------------------- Deploying with predeployed contracts");
    }
    else{
      console.log("------------------- Deploying from scratch");
    }

    if( mainnet_selected){
      console.log("************* MAINNET *************");

      _DataSpottingAddress = "0xB4707d75545D653146ac40196AB1cc5040481aF2"
      _DataComplianceAddress = "0xB4707d75545D653146ac40196AB1cc5040481aF2"
      _DataIndexingAddress = "0xB4707d75545D653146ac40196AB1cc5040481aF2"
      _DataArchivingAddress = "0xB4707d75545D653146ac40196AB1cc5040481aF2"
  
      if(networkName.startsWith('schain')){
        // EXDT Token
        EXDTTokenAddress = "0xA4C6a304b1A234146Db465f2b7D198876706DF8E";
        // DAO
        ReputationAddress = "0xc3F740f78694B2aD81c9647f433401FB53D90b3F";
        AvatarAddress = "0x274469A77a3f47EBD3Df5CA5B4D5f0267f431e6b";
        ControllerAddress = "0x274469A77a3f47EBD3Df5CA5B4D5f0267f431e6b";
        // DAO CORE PERMISSIONING
        MasterWalletAddress = "0xED33CC400cDe9d8827D5a83419cb50dA9499bC53";
        PermissionRegistryAddress = "0x2aAEBe1435cb881Fa2113a3c34Cee8E8ED51EC4b";            
        // WORKSYSTEMS PARAMETERS
        ParametersAddress = "0x3eB66895e77555C4f99d0973Ee65D99D1c455F60";
        // CONFIG REGISTRY
        ConfigRegistryAddress = "0x6a495533190a5930781a363B6c7E8db6abC63068";
        // Address Manager
        AddressManagerAddress = "0x06a4fC078b6497f01F1914DEAC4577100779a0eC";
        // End of pipeline: Archiving
        DataArchiveAddress = "0x89b90093078cEc1aD2B4d9Dd25968b9e64b53f61";
        // STake & Rewards
        StakingManagerAddress = "0x95582d90a29F218b7F3D54947Bd77E4d08CEE04e";
        RewardsManagerAddress = "0x1BbB3d85F1e943CE240e2B7a2cF7b2bb5dce940d";
      }
  
      // sFuel Auto top up system
      SFuelContractsAddress = "0x190c7D16c3EC7FC71c37b9c7D30AA8638361D2B1";      
      StatisticsAddress = "0x68A0113C052481BE6Ca14555F97B436831Bb07f4";
    }
    else{
      console.log("************* TESTNET *************");

      _DataSpottingAddress = "0xaA5F977C9240aaF062EC346fc65dbc186B012980"
      _DataComplianceAddress = "0xaA5F977C9240aaF062EC346fc65dbc186B012980"
      _DataIndexingAddress = "0xaA5F977C9240aaF062EC346fc65dbc186B012980"
      _DataArchivingAddress = "0xaA5F977C9240aaF062EC346fc65dbc186B012980"

    // roasted network
      if(networkName.startsWith('schain')){
        // EXDT Token
        EXDTTokenAddress = "0xa9D04aaAd526A93eaEB2B205fd814A6183e22499";
        // DAO
        ReputationAddress = "0xFDd22dd6aA36CA4ff73Bcf1E5AB795c13E383398";
        AvatarAddress = "0x5Ef775aDa67e7A83DAdc1b2cbEBA44a9a7EAdb44";
        ControllerAddress = "0xe556f64611036e9aE4Bb269ecc84DEE340a6318b";
        // DAO CORE PERMISSIONING
        MasterWalletAddress = "0xACF14686ACa50f6567b1daf3d79FB5d44Dac1A78";
        PermissionRegistryAddress = "0x7B17c6D9eC0a717FAFd02d5145eA977034187316";            
        // WORKSYSTEMS PARAMETERS
        ParametersAddress = "0x22dc391799651243F134bf359650DDbB446f99aC";
        // CONFIG REGISTRY
        ConfigRegistryAddress = "0xeF626E65466d08dCc19034fB9b18834a506Ba1Fa";
        // Address Manager
        AddressManagerAddress = "0xA82C2c724B02231Fb547eEDaBB93ccB58584fC89";
        // End of pipeline: Archiving
        DataArchiveAddress = "0x89b90093078cEc1aD2B4d9Dd25968b9e64b53f61";
        // STake & Rewards
        StakingManagerAddress = "0x2A3f3838703002277dab370eEeEC2a3353150951";
        RewardsManagerAddress = "0x7A0F17639137fb4A9247C7cBbEdbd149625e853D";
      }

      // sFuel Auto top up system
      SFuelContractsAddress = "0x786efCF6Eea9F025b863cdecF2f9aD049215ABe0";      
      StatisticsAddress = "0xe34a68e692A50643458383737A0067725d6CE5d2";
    }



    // // Deploy Multicall
    // let multicall;
    // console.log("Deploying Multicall...");
    // multicall = await Multicall.new();
    // console.log("Multicall deployed to:", multicall.address);
    // await waitBlocks(1);
    // networkContracts.utils.multicall = multicall.address;

    // Deploy Reputation
    let reputation;

    
    if(IMPORT_DEPLOYED_CORE){
      console.log("IMPORTING EXISTING Reputation at ", ReputationAddress);
      reputation = await hre.ethers.getContractAt("ExordeReputation", ReputationAddress);
      addresses["Reputation"] = reputation.address;
      console.log("Exorde Reputation deployed to:", reputation.address);
      networkContracts.reputation = reputation.address;
    }
    else{
      console.log("Deploying ExordeReputation...");
      reputation = await ExordeReputation.new({ gas: 200000000 });
      addresses["Reputation"] = reputation.address;
      // Mint exorde REP
      console.log(
        "mint initial REP to founders",
      );
      await reputation.mintMultiple(founders, initialRep);
    }  


    await waitBlocks(1);


    // Deploy Tokens
    
    let tokens = {};

    console.log(
      "Token amount =  ",
    );
    let tokenTotalSupply = ethers.utils.parseUnits("200000000.0", 18).toString()
    console.log(ethers.utils.parseUnits("200000000.0", 18).toString());
    

    for (const tokenToDeploy of deploymentConfig.tokens){
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
          if(IMPORT_DEPLOYED_TOKEN){
            newToken = await hre.ethers.getContractAt("DAOToken", EXDTTokenAddress);
            console.log("IMPORTING EXISTING ERC20 TOKEN at ",newToken.address)
          }
          else{
            newToken = await ERC20Mock.new();
            await waitBlocks(1);
            for (const tokenHolder of tokenToDeploy.distribution){
                await newToken.transfer(tokenHolder.address, tokenHolder.amount, {
                    from: accounts[0],
                  });
            }
            break;
          } 
      }
      tokens[tokenToDeploy.symbol] = newToken;
      addresses[tokenToDeploy.symbol] = newToken.address;
  }
    

    console.log(
      "waiting 1 blocks...",
    );
    await waitBlocks(1);

    // Deploy Avatar
    let avatar;
    
    if(IMPORT_DEPLOYED_CORE){
      console.log("IMPORTING EXISTING Avatar at ", AvatarAddress);
      avatar = await hre.ethers.getContractAt("ExordeAvatar", AvatarAddress);
      addresses["Avatar"] = avatar.address;      
      console.log("Exorde Avatar deployed to:", avatar.address);
    }
    else{
      console.log(
        "Deploying ExordeAvatar...",
        tokens.EXDT.address,
        reputation.address
      );
      avatar = await ExordeAvatar.new(
        "Exorde Test DAO",
        tokens.EXDT.address,
        reputation.address
      );
      console.log("Exorde Avatar deployed to:", avatar.address);
    } 

    console.log("Exorde Token deployed to:", tokens.EXDT.address);

    networkContracts.avatar = avatar.address;
    networkContracts.token = addresses["EXDT"];
    addresses["Avatar"] = avatar.address;
    await waitBlocks(1);

    // Deploy Controller and transfer avatar to controller
    let controller;
    
    if(IMPORT_DEPLOYED_CORE){
      console.log("IMPORTING EXISTING Controller at ", ControllerAddress);
      controller = await hre.ethers.getContractAt("ExordeController", ControllerAddress);
      addresses["Controller"] = controller.address;
      console.log("Exorde Controller deployed to:", controller.address);
    }
    else{
      console.log("Deploying ExordeController...");
      controller = await ExordeController.new(avatar.address);
      console.log("ExordeDAO Controller deployed to:", controller.address); 
      await avatar.transferOwnership(controller.address);
      await reputation.transferOwnership(controller.address);
    }

    networkContracts.controller = controller.address;
    addresses["Controller"] = controller.address;
    await waitBlocks(1);

    let config_registry;
        
    if(IMPORT_DEPLOYED_BASE){
      console.log("IMPORTING EXISTING Config Registry at ", ConfigRegistryAddress);
      config_registry = await hre.ethers.getContractAt("ConfigRegistry", ConfigRegistryAddress);
      addresses["ConfigRegistry"] = config_registry.address;
      console.log("Config Registry deployed to ", config_registry.address);
    }
    else{
      console.log("Deploying Config Registry...");
      config_registry = await ConfigRegistry.new();
      addresses["ConfigRegistry"] = config_registry.address;
      console.log("Config Registry deployed to ", config_registry.address);
    } 

    let permissionRegistry;
    if(IMPORT_DEPLOYED_CORE){
      console.log("IMPORTING EXISTING permissionRegistry at ", PermissionRegistryAddress);
      permissionRegistry = await hre.ethers.getContractAt("PermissionRegistry", PermissionRegistryAddress);
      addresses["PermissionRegistry"] = permissionRegistry.address;
      console.log("PermissionRegistry deployed to:", permissionRegistry.address);
    }
    else{
      console.log("Deploying PermissionRegistry...");
      permissionRegistry = await PermissionRegistry.new();
      await permissionRegistry.initialize();
      addresses["PermissionRegistry"] = permissionRegistry.address;
      console.log("PermissionRegistry deployed to ",    addresses["PermissionRegistry"]);
    }

      
    // Deploy Staking & Rewards & Address Manager
    let staking_manager;
    let rewards_manager;
    let address_manager;
    let parameters_manager;
    let data_archive;

    
    if(IMPORT_DEPLOYED_CORE){       //  && false
      console.log("IMPORTING EXISTING Staking Manager at ", StakingManagerAddress);
      staking_manager = await hre.ethers.getContractAt("StakingManager", StakingManagerAddress);
      addresses["StakingManager"] = staking_manager.address;
      console.log("Staking Manager deployed to ", staking_manager.address);
    }
    else{        
      console.log("Deploying Staking Manager...");
      staking_manager = await StakingManager.new(tokens.EXDT.address);
      addresses["StakingManager"] = staking_manager.address;
      console.log("Staking Manager deployed to ", staking_manager.address);
    }  
    

    if(IMPORT_DEPLOYED_CORE){   
      console.log("IMPORTING EXISTING Rewards Manager at ", RewardsManagerAddress);
      rewards_manager = await hre.ethers.getContractAt("RewardsManager", RewardsManagerAddress);
      addresses["RewardsManager"] = rewards_manager.address;
      console.log("Rewards Manager deployed to ", rewards_manager.address); 
    }
    else{   
      rewards_manager = await RewardsManager.new(tokens.EXDT.address);
      addresses["RewardsManager"] = rewards_manager.address;     
      console.log("Rewards Manager deployed to ", rewards_manager.address); 
    }  
    
    if(IMPORT_DEPLOYED_CORE){   
      console.log("IMPORTING EXISTING Parameters Manager at ", ParametersAddress);
      parameters_manager = await hre.ethers.getContractAt("Parameters", ParametersAddress);
      addresses["Parameters"] = parameters_manager.address;
      console.log("Parameters Manager deployed to ", parameters_manager.address); 
    }
    else{   
      parameters_manager = await Parameters.new();
      addresses["Parameters"] = parameters_manager.address;     
      console.log("Parameters Manager deployed to ", parameters_manager.address); 
    }  
    

    if(IMPORT_DEPLOYED_BASE){
      console.log("IMPORTING EXISTING Address Manager at ", AddressManagerAddress);
      address_manager = await hre.ethers.getContractAt("AddressManager", AddressManagerAddress);
      console.log("Address Manager deployed to ", address_manager.address);
      addresses["AddressManager"] = address_manager.address;
    }
    else{
      console.log("Deploying AddressManager...");
      address_manager = await AddressManager.new();
      addresses["AddressManager"] = address_manager.address;
      console.log("Address Manager deployed to ", address_manager.address);
    } 
    // console.log("IMPORTING EXISTING Address Manager at ", AddressManagerAddress);
    // address_manager = await hre.ethers.getContractAt("AddressManager", AddressManagerAddress);
    // console.log("Address Manager deployed to ", address_manager.address);
    // addresses["AddressManager"] = address_manager.address;

    let statisticsContract;
    console.log("IMPORTING EXISTING STATISTICS CONTRACT at ", StatisticsAddress);
    statisticsContract = await hre.ethers.getContractAt("Statistics", StatisticsAddress);
    addresses["Statistics"] = statisticsContract.address;



    // -------------------------------------------------------------------------------------------------------
    // -------------------------------------------------------------------------------------------------------
    // ------------------------            WORK SYSTEMS DEPENDENCY GRAPH          ----------------------------
    // -------------------------------------------------------------------------------------------------------
    // ----------------------- DataSpotting        -> Data Compliance -->   DataIndexing       ---------------
    // -----------------------------------------------------------   '-->   DataArchiving      ---------------
    // -------------------------------------------------------------------------------------------------------

    ////////////////////////////////////////      SPOTTING WORK SYSTEM     //////////////////////////////////////////
    // Deploy WorkSystems
    let spot_worksystem;
    let libDLL;


    if(IMPORT_DEPLOYED_WS){   
      console.log("IMPORTING EXISTING DataSpotting at ", _DataSpottingAddress);
      spot_worksystem = await hre.ethers.getContractAt("DataSpotting", _DataSpottingAddress);
      addresses["DataSpotting"] = spot_worksystem.address;
      console.log("Exorde DataSpotting deployed to:", spot_worksystem.address);
    }
    else{
        
      libDLL = await DLL.new();
      console.log("Library DLL addr",libDLL.address);

      console.log("Deploying DataSpotting System...");
      const DataSpottingFactory = await ethers.getContractFactory("DataSpotting", {
        libraries: { 
          DLL: libDLL.address           
        },
      });


      const _DataSpottingFactory = await DataSpottingFactory.deploy(tokens.EXDT.address);
      await _DataSpottingFactory.deployed();
      console.log("DataSpotting deployed to ", _DataSpottingFactory.address);
      spot_worksystem = _DataSpottingFactory;
      addresses["DataSpotting"] = _DataSpottingFactory.address;
    }

    // register the worksystem as allowed to use stakes
    console.log("Add the DataSpotting as allowed to use stakes in StakingManager");
    await staking_manager.addWhitelistedAddress(spot_worksystem.address);    
    console.log("Add the DataSpotting as allowed to use stakes in RewardsManager");
    await rewards_manager.addAddress(spot_worksystem.address);

    
    // // -------------------------------------------------------------------------------------------------------
    // ////////////////////////////////////////      COMPLIANCE WORK SYSTEM     //////////////////////////////////////////

    // let compliance_worksystem;
    // let libDLL2;


    
    // if(IMPORT_DEPLOYED_WS ||  enable_debug_only_spotting_ws){   
    //   console.log("IMPORTING EXISTING DataCompliance at ", _DataComplianceAddress);
    //   compliance_worksystem = await hre.ethers.getContractAt("DataCompliance", _DataComplianceAddress);
    //   addresses["DataCompliance"] = compliance_worksystem.address;
    //   console.log("Exorde DataCompliance deployed to:", compliance_worksystem.address);
    // }
    // else{        
    //   libDLL2 = await DLL2.new();
    //   console.log("Library DLL2 addr",libDLL2.address);
  
    //   console.log("Deploying DataCompliance System...");
    //   const DataComplianceFactory = await ethers.getContractFactory("DataCompliance", {
    //     libraries: { 
    //       DLL2: libDLL2.address           
    //     },
    //   });

    //   const _DataComplianceFactory = await DataComplianceFactory.deploy(tokens.EXDT.address);
    //   await _DataComplianceFactory.deployed();


    //   console.log("DataCompliance deployed to ", _DataComplianceFactory.address);
    //   compliance_worksystem = _DataComplianceFactory;
    //   addresses["DataCompliance"] = _DataComplianceFactory.address;

    // }

    // // register the worksystem as allowed to use stakes
    // console.log("Add the DataCompliance as allowed to use stakes in StakingManager");
    // await staking_manager.addWhitelistedAddress(compliance_worksystem.address);    
    // console.log("Add the DataCompliance as allowed to use stakes in RewardsManager");
    // await rewards_manager.addAddress(compliance_worksystem.address);

    
    // // -------------------------------------------------------------------------------------------------------
    // ////////////////////////////////////////      INDEXING WORK SYSTEM     //////////////////////////////////////////

    // let indexing_worksystem;
    // let libDLL3;


    
    // if(IMPORT_DEPLOYED_WS || enable_debug_only_spotting_ws){  
    //   console.log("IMPORTING EXISTING DataIndexing at ", _DataIndexingAddress);
    //   indexing_worksystem = await hre.ethers.getContractAt("DataIndexing", _DataIndexingAddress);
    //   addresses["DataIndexing"] = indexing_worksystem.address;
    //   console.log("Exorde DataIndexing deployed to:", indexing_worksystem.address);
    // }
    // else{       
    //   libDLL3 = await DLL3.new();
    //   console.log("Library DLL3 addr",libDLL3.address);
  
    //   console.log("Deploying DataIndexing System..."); 
    //   const DataIndexingFactory = await ethers.getContractFactory("DataIndexing", {
    //     libraries: { 
    //       DLL3: libDLL3.address           
    //     },
    //   });

    //   const _DataIndexingFactory = await DataIndexingFactory.deploy(tokens.EXDT.address);
    //   await _DataIndexingFactory.deployed();


    //   console.log("DataIndexing deployed to ", _DataIndexingFactory.address);
    //   indexing_worksystem = _DataIndexingFactory;
    //   addresses["DataIndexing"] = _DataIndexingFactory.address;
    // }


    // // register the worksystem as allowed to use stakes
    // console.log("Add the DataIndexing as allowed to use stakes in StakingManager");
    // await staking_manager.addWhitelistedAddress(indexing_worksystem.address);    
    // console.log("Add the DataIndexing as allowed to use stakes in RewardsManager");
    // await rewards_manager.addAddress(indexing_worksystem.address);


    // // -------------------------------------------------------------------------------------------------------
    // ////////////////////////////////////////      ARCHIVING WORK SYSTEM     //////////////////////////////////////////
    // let archiving_worksystem;
    // let libDLL4;

    
    // if(IMPORT_DEPLOYED_WS || enable_debug_only_spotting_ws){  
    //   console.log("IMPORTING EXISTING DataArchiving at ", _DataArchivingAddress);
    //   archiving_worksystem = await hre.ethers.getContractAt("DataArchiving", _DataArchivingAddress);
    //   addresses["DataArchiving"] = archiving_worksystem.address;
    //   console.log("Exorde DataArchiving deployed to:", archiving_worksystem.address);
    // }
    // else{        
    //   libDLL4 = await DLL4.new();
    //   console.log("Library DLL4 addr",libDLL4.address);
  
    //   console.log("Deploying DataArchiving System...");
  
    //   const DataArchivingFactory = await ethers.getContractFactory("DataArchiving", {
    //     libraries: { 
    //       DLL4: libDLL4.address           
    //     },
    //   });

    //   const _DataArchivingFactory = await DataArchivingFactory.deploy(tokens.EXDT.address);
    //   await _DataArchivingFactory.deployed();


    //   console.log("DataArchiving deployed to ", _DataArchivingFactory.address);
    //   archiving_worksystem = _DataArchivingFactory;
    //   addresses["DataArchiving"] = _DataArchivingFactory.address;
    // }


    // // register the worksystem as allowed to use stakes
    // console.log("Add the DataArchiving as allowed to use stakes in StakingManager");
    // await staking_manager.addWhitelistedAddress(archiving_worksystem.address);    
    // console.log("Add the DataArchiving as allowed to use stakes in RewardsManager");
    // await rewards_manager.addAddress(archiving_worksystem.address);

    // -------------------------------------------------------------------------------------------------------
    await waitBlocks(1);  
    // -------------------------------------------------------------------------------------------------------

    // // Deploy exordeVotingMachine
    // let votingMachine;
    // console.log("Deploying exordeVotingMachine...");
    // votingMachine = await exordeVotingMachine.new(tokens.EXDT.address);
    // console.log("exordeVotingMachine deployed to:", votingMachine.address);
    // networkContracts.votingMachines[votingMachine.address] = {
    //   type: "exordeVotingMachine",
    //   token: tokens.EXDT.address,
    // };
    // await waitBlocks(1);

    // Deploy Wallet Schemes



    let masterWallet;

    if(!IMPORT_DEPLOYED_CORE){       

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
        let schemeParamsHash = await controller.getParametersHash(
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

        // await votingMachine.setParameters(
        //   [
        //     schemeConfiguration.queuedVoteRequiredPercentage.toString(),
        //     schemeConfiguration.queuedVotePeriodLimit.toString(),
        //     schemeConfiguration.boostedVotePeriodLimit.toString(),
        //     schemeConfiguration.preBoostedVotePeriodLimit.toString(),
        //     schemeConfiguration.thresholdConst.toString(),
        //     schemeConfiguration.quietEndingPeriod.toString(),
        //     schemeConfiguration.proposingRepReward.toString(),
        //     schemeConfiguration.votersReputationLossRatio.toString(),
        //     schemeConfiguration.minimumDaoBounty.toString(),
        //     schemeConfiguration.daoBountyConst.toString(),
        //     0,
        //   ],
        //   NULL_ADDRESS
        // );

        // The Wallet scheme has to be initialized right after being created
        console.log("Initializing scheme...");
        await newScheme.initialize(
          avatar.address,
          // votingMachine.address, //  REMOVED FROM WALLET SCHEME, DAO NEEDS TO BE RE ENGINEERING, too complex
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
    }
    else{       
      console.log("IMPORTING EXISTING masterWallet at ", MasterWalletAddress);
      masterWallet = await hre.ethers.getContractAt("WalletScheme", MasterWalletAddress);
      addresses["MasterWalletScheme"] = masterWallet.address;
      console.log("MasterWalletScheme deployed to:", masterWallet.address);
    }

    let sfuelcontract;
    console.log("IMPORTING EXISTING SFUEL TOP-UP CONTRACT at ", SFuelContractsAddress);
    sfuelcontract = await hre.ethers.getContractAt("SFuelContracts", SFuelContractsAddress);
    console.log("Allow worksystems to topup sFuel [ONLY DATASPOTTING FOR NOW!!!]");
    await sfuelcontract.addAddress(addresses["DataSpotting"])
    // await sfuelcontract.addAddress(addresses["DataCompliance"])
    // await sfuelcontract.addAddress(addresses["DataIndexing"])
    // await sfuelcontract.addAddress(addresses["DataArchiving"])

    console.log("ADD PARAMETERS TO PARAMETERS MANAGER:");

    // console.log("Following list of addresses: ",staking_manager.address,masterWallet.address,  reputation.address, rewards_manager.address, address_manager.address,
    // addresses["DataSpotting"], addresses["DataCompliance"], addresses["DataIndexing"], addresses["DataArchiving"], sfuelcontract.address, tokens.EXDT.address);

    console.log("updateContractsAddresses in Parameters");
    console.log("WARNING: DATA SPOTTING FOR ALL WORKSYSTEMS FOR NOW (DEV)");
    await parameters_manager.updateContractsAddresses(staking_manager.address,masterWallet.address,  reputation.address, rewards_manager.address, address_manager.address,
      addresses["DataSpotting"], addresses["DataSpotting"], addresses["DataSpotting"], addresses["DataSpotting"], sfuelcontract.address, tokens.EXDT.address)
    

    // --------------------- MASTER WALLET REPUTATION FOR WORKSYSTEMS
    console.log("\n\nAdd the DataSpotting as allowed to mint Reputation in MasterWallet");
    await masterWallet.addWorksystemAddress(spot_worksystem.address);
    // console.log("Add the DataCompliance as allowed to mint Reputation in MasterWallet\n");
    // await masterWallet.addWorksystemAddress(compliance_worksystem.address);

    await waitBlocks(1);
    console.log("\n\nAdd the AddressManager as allowed to mint Reputation in MasterWallet");
    await masterWallet.addWorksystemAddress(address_manager.address);
    console.log("Add the AddressManager as allowed to use Rewards in RewardsManager");
    await rewards_manager.addAddress(address_manager.address);
    

    await waitBlocks(1);
    // --------------------- WORKSYSTEMS: LINK Stake, Rewards, Rep & Address to the system
    console.log("Update Parameters Manager in all systems\n");    
    await spot_worksystem.updateParametersManager(parameters_manager.address);
    // await compliance_worksystem.updateParametersManager(parameters_manager.address);
    // await indexing_worksystem.updateParametersManager(parameters_manager.address);
    // await archiving_worksystem.updateParametersManager(parameters_manager.address);
    // await rewards_manager.updateParametersManager(parameters_manager.address);
    await address_manager.updateParametersManager(parameters_manager.address);
    


    // -------------------------------------------------------------------------------------------------------

    // // Deploy exordeVotingMachine
    // let votingMachine;
    // console.log("Deploying exordeVotingMachine...");
    // votingMachine = await exordeVotingMachine.new(tokens.EXDT.address);
    // console.log("exordeVotingMachine deployed to:", votingMachine.address);
    // networkContracts.votingMachines[votingMachine.address] = {
    //   type: "exordeVotingMachine",
    //   token: tokens.EXDT.address,
    // };
    // await waitBlocks(1);
    // await tokens.EXDT.approve(votingMachine.address, MAX_UINT_256, {
    //   from: accounts[0],
    // });
    // await tokens.EXDT.approve(votingMachine.address, MAX_UINT_256, {
    //   from: accounts[1],
    // });
    // await tokens.EXDT.approve(votingMachine.address, MAX_UINT_256, {
    //   from: accounts[2],
    // });
    // addresses["exordeVotingMachine"] = votingMachine.address;

    // Deploy PermissionRegistry to be used by WalletSchemes
    


    // Only allow the functions mintReputation, burnReputation, genericCall, registerScheme and unregisterScheme to be
    // called to in the controller contract from a scheme that calls the controller.
    // This permissions makes the other functions inaccessible
    const notAllowedControllerFunctions = [
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


    // // Deploy ContributionReward Scheme
    // console.log("Deploying ContributionReward scheme");
    // const contributionReward = await ContributionReward.new();
    // const redeemer = await Redeemer.new();

    // // The ContributionReward scheme was designed by DAOstack to be used as an universal scheme,
    // // which means that index the voting params used in the voting machine hash by voting machine
    // // So the voting parameters are set in the voting machine, and that voting parameters hash is registered in the ContributionReward
    // // And then other voting parameter hash is calculated for that voting machine and contribution reward, and that is the one used in the controller
    // const contributionRewardParamsHash = await votingMachine.getParametersHash(
    //   [
    //     deploymentConfig.contributionReward.queuedVoteRequiredPercentage.toString(),
    //     deploymentConfig.contributionReward.queuedVotePeriodLimit.toString(),
    //     deploymentConfig.contributionReward.boostedVotePeriodLimit.toString(),
    //     deploymentConfig.contributionReward.preBoostedVotePeriodLimit.toString(),
    //     deploymentConfig.contributionReward.thresholdConst.toString(),
    //     deploymentConfig.contributionReward.quietEndingPeriod.toString(),
    //     deploymentConfig.contributionReward.proposingRepReward.toString(),
    //     deploymentConfig.contributionReward.votersReputationLossRatio.toString(),
    //     deploymentConfig.contributionReward.minimumDaoBounty.toString(),
    //     deploymentConfig.contributionReward.daoBountyConst.toString(),
    //     0,
    //   ],
    //   NULL_ADDRESS,
    //   { from: accounts[0], gasPrice: 0 }
    // );
    // await votingMachine.setParameters(
    //   [
    //     deploymentConfig.contributionReward.queuedVoteRequiredPercentage.toString(),
    //     deploymentConfig.contributionReward.queuedVotePeriodLimit.toString(),
    //     deploymentConfig.contributionReward.boostedVotePeriodLimit.toString(),
    //     deploymentConfig.contributionReward.preBoostedVotePeriodLimit.toString(),
    //     deploymentConfig.contributionReward.thresholdConst.toString(),
    //     deploymentConfig.contributionReward.quietEndingPeriod.toString(),
    //     deploymentConfig.contributionReward.proposingRepReward.toString(),
    //     deploymentConfig.contributionReward.votersReputationLossRatio.toString(),
    //     deploymentConfig.contributionReward.minimumDaoBounty.toString(),
    //     deploymentConfig.contributionReward.daoBountyConst.toString(),
    //     0,
    //   ],
    //   NULL_ADDRESS
    // );
    // await contributionReward.setParameters(
    //   contributionRewardParamsHash,
    //   votingMachine.address
    // );
    // const contributionRewardVotingmachineParamsHash =
    //   await contributionReward.getParametersHash(
    //     contributionRewardParamsHash,
    //     votingMachine.address
    //   );
    // await controller.registerScheme(
    //   contributionReward.address,
    //   contributionRewardVotingmachineParamsHash,
    //   encodePermission({
    //     canGenericCall: true,
    //     canUpgrade: false,
    //     canRegisterSchemes: false,
    //   }),
    //   avatar.address
    // );

    // networkContracts.daostack = {
    //   [contributionReward.address]: {
    //     contractToCall: controller.address,
    //     creationLogEncoding: [
    //       [
    //         {
    //           name: "_descriptionHash",
    //           type: "string",
    //         },
    //         {
    //           name: "_reputationChange",
    //           type: "int256",
    //         },
    //         {
    //           name: "_rewards",
    //           type: "uint256[5]",
    //         },
    //         {
    //           name: "_externalToken",
    //           type: "address",
    //         },
    //         {
    //           name: "_beneficiary",
    //           type: "address",
    //         },
    //       ],
    //     ],
    //     name: "ContributionReward",
    //     newProposalTopics: [
    //       [
    //         "0xcbdcbf9aaeb1e9eff0f75d74e1c1e044bc87110164baec7d18d825b0450d97df",
    //         "0x000000000000000000000000519b70055af55a007110b4ff99b0ea33071c720a",
    //       ],
    //     ],
    //     redeemer: redeemer.address,
    //     supported: true,
    //     type: "ContributionReward",
    //     voteParams: contributionRewardVotingmachineParamsHash,
    //     votingMachine: votingMachine.address,
    //   },
    // };
    // addresses["ContributionReward"] = contributionReward.address;

    
    // await waitBlocks(1);
    // // -------------------------------------------------------------------------------------------------------

    // let sfuelcontract;
    // console.log("IMPORTING EXISTING SFUEL TOP-UP CONTRACT at ", SFuelContractsAddress);
    // sfuelcontract = await hre.ethers.getContractAt("SFuelContracts", SFuelContractsAddress);
    // console.log("Allow worksystems to topup sFuel");
    // await sfuelcontract.addAddress(addresses["DataSpotting"])
    // await sfuelcontract.addAddress(addresses["DataCompliance"])

    // console.log("ADD PARAMETERS TO PARAMETERS MANAGER");
    // if(networkName.startsWith('schain')){
    //   await parameters_manager.updateContractsAddresses(staking_manager.address,masterWallet.address,  reputation.address, rewards_manager.address, address_manager.address,
    //     addresses["DataSpotting"], addresses["DataCompliance"], addresses["DataIndexing"], addresses["DataArchiving"], sfuelcontract.address, tokens.EXDT.address)
    // }

    // await waitBlocks(1);



    // // --------------------- MASTER WALLET REPUTATION FOR WORKSYSTEMS
    // console.log("\n\nAdd the DataSpotting as allowed to mint Reputation in MasterWallet");
    // await masterWallet.addWorksystemAddress(spot_worksystem.address);
    // console.log("Add the DataCompliance as allowed to mint Reputation in MasterWallet\n");
    // await masterWallet.addWorksystemAddress(compliance_worksystem.address);

    // await waitBlocks(1);
    // console.log("\n\nAdd the AddressManager as allowed to mint Reputation in MasterWallet");
    // await masterWallet.addWorksystemAddress(address_manager.address);
    // console.log("Add the AddressManager as allowed to use Rewards in RewardsManager");
    // await rewards_manager.addAddress(address_manager.address);
    

    // await waitBlocks(1);
    // // --------------------- WORKSYSTEMS: LINK Stake, Rewards, Rep & Address to the system
    // console.log("Update Parameters Manager in all systems\n");    
    // await spot_worksystem.updateParametersManager(parameters_manager.address);
    // await compliance_worksystem.updateParametersManager(parameters_manager.address);
    // await indexing_worksystem.updateParametersManager(parameters_manager.address);
    // await archiving_worksystem.updateParametersManager(parameters_manager.address);
    // await rewards_manager.updateParametersManager(parameters_manager.address);
    // await address_manager.updateParametersManager(parameters_manager.address);
    

    // give back all ownerships to the DAO controller
    console.log("[DISABLED] Transfer ownerships to the DAO controller... (StakingManager & Worksystems)\n");
    // await spot_worksystem.transferOwnership(controller.address);
    // await format_worksystem.transferOwnership(controller.address);
    // await staking_manager.transferOwnership(controller.address);


    // Transfer all ownership and power to the dao
    console.log("Transfering ownership...");
    // Set the in the permission registry
    console.log("permissionRegistry: transferOwnership...");
    await permissionRegistry.transferOwnership(avatar.address);
    // console.log("exordeaoNFT: transferOwnership...");
    // await exordeaoNFT.transferOwnership(avatar.address);
    // console.log("controller: unregisterScheme...");
    // await controller.unregisterScheme(accounts[0], avatar.address);

    console.log("Done...");
    let proposals = {
      exorde: [],
    };

    // const startTime = deploymentConfig.startTimestampForActions;
    // console.log("evm_increaseTime..");
    // // Increase time to start time for actions
    // await hre.network.provider.request({
    //   method: "evm_increaseTime",
    //   params: [startTime - (await web3.eth.getBlock("latest")).timestamp],
    // });

    
    console.log(JSON.stringify(addresses));


    console.log("\nexit before test actions");
    process.exit(1)
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
          proposals.exorde.push(
            proposalCreationTx.receipt.logs[0].args._proposalId
          );
          break;
        case "vote":
          await votingMachine.vote(
            proposals.exorde[action.data.proposal],
            action.data.decision,
            action.data.amount,
            action.from,
            { from: action.from }
          );
          break;
        case "stake":
          await votingMachine.stake(
            proposals.exorde[action.data.proposal],
            action.data.decision,
            action.data.amount,
            { from: action.from }
          );
          break;
        case "execute":
          try {
            await votingMachine.execute(
              proposals.exorde[action.data.proposal],
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
            proposals.exorde[action.data.proposal],
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
