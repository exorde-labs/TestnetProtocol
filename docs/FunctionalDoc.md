

# Exorde Protocol Documentation!

Exorde Protocol, and especially its WorkSystem (DataSpotting) is a parallelized data-processing pipeline, where 2 types of participations are possible:

 1. **Submit Data to the Protocol (SpotData())**
 
 2. **Validate data by getting randomly allocated on a DataBatch**

# Network information

In order to connect, the available network configuration is available here:
https://github.com/MathiasExorde/TestnetProtocol-staging/blob/main/NetworkConfig.txt

The main information to connect and start reading/writing to the Exorde blockchain are:

 - RPC Endpoint: "https://mainnet.skalenodes.com/v1/light-vast-diphda",
 -  Chain ID: "2139927552"
- The blockExplorer can be found here: "https://light-vast-diphda.explorer.mainnet.skalenodes.com/",

Once connected to the right network, it is time to connect to the core protocol endpoints.

## Core protocol endpoints

Exorde Protocol is composed of several layers, from core to external service:

- **Core Endpoints**: **DAO Avatar, Main Controller, Permission Registry, Exorde Token**. These should not change, once deployed, these contracts & adresses stay forever.
- **Base Systems**: **StakingManager, RewardsManager, ConfigRegistry, Parameters, AddressManager, MasterWalletScheme**. These contract handle the Staking, Rewards, Master/Main Mapping, Global configuration & System Parameters, they are controlled by the Core contract & the governance, and can be updated over time.
- **Data-specific Systems**: **DataSpotting  (+ in the future  DataCompliance, DataIndexing & DataArchiving )**. These compose the data pipeline that is handling the stream of data blocks produced by Exorde Spotters. They work with the Base Systems to rewards Reputation & Tokens, they read their own parameters from the Parameters contract, etc.

The latest contract endpoints can be found usually here: https://github.com/MathiasExorde/TestnetProtocol-staging/blob/main/ContractsAddresses.txt
Later, only the Core Endpoints need to be trusted, as the other systems are appointed/controled by the Exorde DAO. 

## ABIs

In order to interact (read or write to) the contracts composing the protocol, you will need to interface via their respectives ABIs. These can be found here: https://github.com/MathiasExorde/TestnetProtocol-staging/tree/main/ABIs.
ABIs are jsons and for example, DataSpotting ABI itself can be found at https://github.com/MathiasExorde/TestnetProtocol-staging/blob/main/ABIs/DataSpotting.sol/DataSpotting.json in the sub item "abi" of this larger json file.

**The Protocol is a set of contracts with a set of precise functions (endpoints)**. To read/write a given protocol function (simple getters or state-modifying functions), you need to interface to the contract hosting this precise function, with its ABI.
Examples:

To read the given Reputation balance of an address: On the Reputation contract, using the function *BalanceOf(address)*.
To read the Available Stake of an address: On the StakingManager, using the function *AvailableStakedAmountOf(address)*.

## Reading User General State 

For a given worker wallet address, we can read its "state":

 - REP: *BalanceOf(address)* on Reputation contract EXDT Available
 - Rewards: *RewardsBalanceOf(..)* on the RewardsManager contract
 - Stakes: *balances(..), AvailableStakedAmountOf(..), AllocatedStakedAmountOf(..)* on StakingManager
 - Current Main Address: *FetchHighestMaster(..)*
 - Current Master (if set): *getMaster(..)*

User stakes are composed of 3 balances (readable with the balances() call):
- **Free Balance**: when user deposit tokens to the StakingManager, the end up here. All tokens in the balance can be withdrawn at will.
- **Staked Balance**: this balance is staked and can be allocated to Systems during participation (and released later depending on the processes)
- **Allocated Balance**: this balance is what is currently locked. This will change soon to show which systems are allocating what, and allow the StakingManager administrator to release these balances if needed (Change of Systems, updates, etc).

## Reading Global General State

Total Reputation, Rewards, Stake are easily readable. (...)

## Main WorkSystem

A user can do two things on DataSpotting (currently the only WorkSystem):
 -  Spot Data
 -  Participate in the Validation
 
Spotting Data (the input of the system) is as follows:
**SpotData(string[] memory file_hashs, string[] calldata URL_domains, uint256 item_count_, string memory extra_)**

-- file_hashs is a list of hashes, but can be a list of 1 file (currently that is what is done, spotting N files is not necessary at once)

-- URL_domains is a list of the main domain being spotted in the respective file, file_hashs and URL_domains must have same length

-- item_count_ is the number of item in the file (will be a list later)

Participating in the Validation is done with a commit-reveal scheme.

 - **commitSpotCheck(uint256  _DataBatchId, bytes32  _encryptedHash, bytes32  _encryptedVote, uint256  _BatchCount, string  memory  _From)**
 - 
- **revealSpotCheck(uint256  _DataBatchId, string  memory  _clearIPFSHash, uint256  _clearVote, uint256  _salt)**

## **Staking requirements**

 The worker who wants to participate in the Exorde Protocol must have either:
1.  **Already enough Stake allocated** in this specific WorkSystem ( *SystemStakedTokenBalance(address)* )
2.  **Enough AvailableStake on StakingManager**, or have a Master/Main who has enough AvailableStake, in order for the WorkSystem to automatically ask the StakingManager for some Stake to get allocated.

If not enough AvailableStake (and nothing staked in the WorkSystem already), an address must do the following:

 1. Get enough tokens (25 is currently what is needed to participate) - not a problem on the Testnet
 2. Approve(num_tokens) on the EXDT Token Contract, to allow a transfer
 3. Deposit(num_tokens) on the StakingManager contract: will transfer the tokens & credit your free_balance.
 4. Stake(num_tokens) on the StakingManager contract, will move tokens from the free_balance to the staked_balanc


*All numbers must be divided by 10^18 to be displayed. 100000000000000000000 = 100 EXDT (or 100 REP).*


## WorkSystems ConfigRegistry

Parameters of the participation module itself are on the blockchain, on the ConfigRegistry.
The Config Registry is a mapper, that takes a **string** as input, and gives a string as output.
[Important] The output must be casted/formatted depending on what is used on the software it self.

The list of ConfigRegistry Parameters are as follows:

 1. autoScrapingFrequency 
 2. lastInfo 
 3. version
 4. _ModuleMinSpotBatchSize 
 5. SpotBucket 
 6. spammerList
 7. SpotcheckBucket

["_moduleHashContracts","_moduleHashSpotting","_moduleHashSpotChecking","_moduleHashApp"]


Currently, ConfigRegistry & Parameters can seem redundant but they are not: Parameters is for the parameters of the data processing pipelines (inside the protocol), ConfigRegistry sets the hyper-parameters of Exorde, outside of the Protocol. These parameters are for the participation software (or module). For instance, _ModuleMinSpotBatchSize  is the hyper-parameter deciding the minimum item count (number of URL/content in a file, stored in IPFS) before sumbitting the file during SpotData().


## DataSpotting Spotter Worker LifeCycle

Spotting data is simple, as long as you have enough staked, you can spot as much as you want.
There are 2 rate-limitations systems in the protocol:

- **User Rate Limitation**: Users can submit only N spots (a spot is a file containing >= _ModuleMinSpotBatchSize  URL items). N is set by Parameters and can be adjusted dynamically be the protocol governance itself & external watcher programs. This rate limitation system is sliding on a period of 1h.
- **Global Rate Limitation**: Similarly to the previous system, there is a global cap on the amount of spots submittable in the current period.

Both systems are capping the amount of spots per hours. The period is a sliding windows of 1 hour.

The protocol structures the stream in Data Batches, made of N spots. This N is dynamically adjusted over time. Data batches are identified by an integer (>= 1). There is no Batch 0, it is used only to represent the "no work" situation, or equivalent.

## DataSpotting Validator Worker LifeCycle

### Protocol Validation System

**Validating data is a sequential process:**

 1. A worker address signal itself available, for work as a validator, by **registering**. **Register()** has no arguments.
 2. A worker signal tiself unavailable by **unregistering**. Unregistration only happens when the worker has completed its current task (if any). **Unregister()** has no arguments either.

*Requirements: like Spotting, Validating requires a Stake, as described in Staking requirement.*

The Exorde Protocol works by splitting the input data streams in Data batches. Each Batch is a set of IPFS Files (>= 1), containing data that is properly formatted in a json structure. 

#### Validation Principles:
1. **A worker processes a single Batch ID (a job) at a time**. A worker can only vote on a batch that has been allocated to him.
2. **A worker will remain registered if he continues to work properly, and will continue to get allocated some work (if available).**
3. A worker can be unregistered by the protocol, and prevented from re-registering before a given duration (set in Parameters). This is similar to a "kick" mechanism. This can happen if the worker is not participating multiple times in a row, hurting the protocol mechanisms & the integrity of the data validation system.
5. **Participating is done by voting, and voting is done via commit-reveal schemes.**
6. **Commiting and revealing are performed in rounds, and each round has a timer**. If a worker fails to commit or reveal (or commit but not reveal), this participation will be considered null and the worker will be punished (& not rewarded)
7. Being rewarded depends on being in the majority during the validation consensus

### Participation Procedure

Workers, when **registered**, **must follow this participation algorithm**:



 1. Periodically check **IsNewWorkAvailable(address)**. If this call
    returns **true**, then a job (a Batch ID) is available and can be
    worked on immediately. 
2. The new job can fetched by calling
    **GetCurrentWork(address)**, returning a Batch ID. If called when no job is allocated, GetCurrentWork() returns 0. 
 3. The Worker can then fetch the list of IPFS files of the Batch ID he has to work on, with **getIPFShashesForBatch(BatchID)**. He then proceeds to download these off-chain files and move with the procedure.

*The address argument in the function above must be the worker address, not the Main/Master address.*
