
## DataSpotting

### _SpotSubmitted

```solidity
event _SpotSubmitted(uint256 DataID, string file_hash, string URL_domain, address sender)
```

### _SpotCheckCommitted

```solidity
event _SpotCheckCommitted(uint256 DataID, uint256 numTokens, address voter)
```

### _SpotCheckRevealed

```solidity
event _SpotCheckRevealed(uint256 DataID, uint256 numTokens, uint256 votesFor, uint256 votesAgainst, uint256 choice, address voter)
```

### _BatchValidated

```solidity
event _BatchValidated(uint256 DataID, string file_hash, bool isVotePassed)
```

### _WorkAllocated

```solidity
event _WorkAllocated(uint256 batchID, address worker)
```

### _WorkerRegistered

```solidity
event _WorkerRegistered(address worker, uint256 timestamp)
```

### _WorkerUnregistered

```solidity
event _WorkerUnregistered(address worker, uint256 timestamp)
```

### _StakeAllocated

```solidity
event _StakeAllocated(uint256 numTokens, address voter)
```

### _VotingRightsWithdrawn

```solidity
event _VotingRightsWithdrawn(uint256 numTokens, address voter)
```

### _TokensRescued

```solidity
event _TokensRescued(uint256 DataID, address voter)
```

### _DataBatchDeleted

```solidity
event _DataBatchDeleted(uint256 batchID)
```

### BytesFailure

```solidity
event BytesFailure(bytes bytesFailure)
```

### TimeframeCounter

```solidity
struct TimeframeCounter {
  uint256 timestamp;
  uint256 counter;
}
```

### DataStatus

```solidity
enum DataStatus {
  TBD,
  APPROVED,
  REJECTED,
  FLAGGED
}
```

### WorkerState

```solidity
struct WorkerState {
  uint256 allocated_work_batch;
  uint256 succeeding_novote_count;
  uint256 last_interaction_date;
  bool registered;
  bool unregistration_request;
  uint256 registration_date;
  uint256 allocated_batch_counter;
  uint256 majority_counter;
  uint256 minority_counter;
}
```

### BatchMetadata

```solidity
struct BatchMetadata {
  uint256 start_idx;
  uint256 counter;
  uint256 uncommited_workers;
  uint256 unrevealed_workers;
  bool complete;
  bool checked;
  bool allocated_to_work;
  uint256 commitEndDate;
  uint256 revealEndDate;
  uint256 votesFor;
  uint256 votesAgainst;
  string batchIPFSfile;
  uint256 item_count;
  enum DataSpotting.DataStatus status;
}
```

### SpottedData

```solidity
struct SpottedData {
  string ipfs_hash;
  address author;
  uint256 timestamp;
  uint256 item_count;
  string URL_domain;
  string extra;
  enum DataSpotting.DataStatus status;
}
```

### LastAllocationTime

```solidity
uint256 LastAllocationTime
```

### NB_TIMEFRAMES

```solidity
uint256 NB_TIMEFRAMES
```

### GlobalSpotFlowManager

```solidity
struct DataSpotting.TimeframeCounter[15] GlobalSpotFlowManager
```

### ItemFlowManager

```solidity
struct DataSpotting.TimeframeCounter[15] ItemFlowManager
```

### UserChecksCommits

```solidity
mapping(address => mapping(uint256 => bool)) UserChecksCommits
```

### UserChecksReveals

```solidity
mapping(address => mapping(uint256 => bool)) UserChecksReveals
```

### UserVotes

```solidity
mapping(uint256 => mapping(address => uint256)) UserVotes
```

### UserNewFiles

```solidity
mapping(uint256 => mapping(address => string)) UserNewFiles
```

### UserBatchCounts

```solidity
mapping(uint256 => mapping(address => uint256)) UserBatchCounts
```

### UserBatchFrom

```solidity
mapping(uint256 => mapping(address => string)) UserBatchFrom
```

### UserSubmissions

```solidity
mapping(address => uint256[]) UserSubmissions
```

### dllMap

```solidity
mapping(address => struct DLL.SpottedData) dllMap
```

### store

```solidity
mapping(bytes32 => uint256) store
```

### SpotsMapping

```solidity
mapping(uint256 => struct DataSpotting.SpottedData) SpotsMapping
```

### DataBatch

```solidity
mapping(uint256 => struct DataSpotting.BatchMetadata) DataBatch
```

### WorkersState

```solidity
mapping(address => struct DataSpotting.WorkerState) WorkersState
```

### WorkersSpotFlowManager

```solidity
mapping(address => struct DataSpotting.TimeframeCounter[15]) WorkersSpotFlowManager
```

### SystemStakedTokenBalance

```solidity
mapping(address => uint256) SystemStakedTokenBalance
```

### WorkersPerBatch

```solidity
mapping(uint256 => address[]) WorkersPerBatch
```

### availableWorkers

```solidity
address[] availableWorkers
```

### busyWorkers

```solidity
address[] busyWorkers
```

### toUnregisterWorkers

```solidity
address[] toUnregisterWorkers
```

### isAvailableWorker

```solidity
mapping(address => bool) isAvailableWorker
```

### isBusyWorker

```solidity
mapping(address => bool) isBusyWorker
```

### isToUnregisterWorker

```solidity
mapping(address => bool) isToUnregisterWorker
```

### availableWorkersIndex

```solidity
mapping(address => uint256) availableWorkersIndex
```

### busyWorkersIndex

```solidity
mapping(address => uint256) busyWorkersIndex
```

### toUnregisterWorkersIndex

```solidity
mapping(address => uint256) toUnregisterWorkersIndex
```

### LastRandomSeed

```solidity
uint256 LastRandomSeed
```

### DataNonce

```solidity
uint256 DataNonce
```

### BatchDeletionCursor

```solidity
uint256 BatchDeletionCursor
```

### LastBatchCounter

```solidity
uint256 LastBatchCounter
```

### BatchCheckingCursor

```solidity
uint256 BatchCheckingCursor
```

### AllocatedBatchCursor

```solidity
uint256 AllocatedBatchCursor
```

### AllTxsCounter

```solidity
uint256 AllTxsCounter
```

### AllItemCounter

```solidity
uint256 AllItemCounter
```

### AcceptedBatchsCounter

```solidity
uint256 AcceptedBatchsCounter
```

### RejectedBatchsCounter

```solidity
uint256 RejectedBatchsCounter
```

### NotCommitedCounter

```solidity
uint256 NotCommitedCounter
```

### NotRevealedCounter

```solidity
uint256 NotRevealedCounter
```

### InstantSpotRewards

```solidity
bool InstantSpotRewards
```

### InstantRevealRewards

```solidity
bool InstantRevealRewards
```

### InstantSpotRewardsDivider

```solidity
uint256 InstantSpotRewardsDivider
```

### InstantRevealRewardsDivider

```solidity
uint256 InstantRevealRewardsDivider
```

### MaxPendingDataBatchCount

```solidity
uint256 MaxPendingDataBatchCount
```

### SPOT_FILE_SIZE

```solidity
uint256 SPOT_FILE_SIZE
```

### GAS_LEFT_LIMIT

```solidity
uint256 GAS_LEFT_LIMIT
```

### STAKING_REQUIREMENT_TOGGLE_ENABLED

```solidity
bool STAKING_REQUIREMENT_TOGGLE_ENABLED
```

### TRIGGER_WITH_SPOTDATA_TOGGLE_ENABLED

```solidity
bool TRIGGER_WITH_SPOTDATA_TOGGLE_ENABLED
```

### STRICT_RANDOMNESS_REQUIREMENT

```solidity
bool STRICT_RANDOMNESS_REQUIREMENT
```

### VALIDATE_ON_LAST_REVEAL

```solidity
bool VALIDATE_ON_LAST_REVEAL
```

### FORCE_VALIDATE_BATCH_FILE

```solidity
bool FORCE_VALIDATE_BATCH_FILE
```

### token

```solidity
contract IERC20 token
```

### Parameters

```solidity
contract IParametersManager Parameters
```

### constructor

```solidity
constructor(address EXDT_token_) public
```

_Initializer. Can only be called once._

### destroyContract

```solidity
function destroyContract() public
```

_Destroy Contract, important to release storage space if critical_

### updateParametersManager

```solidity
function updateParametersManager(address addr) public
```

Updates Parameters Manager

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| addr | address | address of the Parameter Contract |

### toggleRequiredStaking

```solidity
function toggleRequiredStaking(bool toggle_) public
```

Enable or disable Required Staking for participation

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| toggle_ | bool | boolean |

### toggleTriggerSpotData

```solidity
function toggleTriggerSpotData(bool toggle_) public
```

Enable or disable Triggering Updates when Spotting Data

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| toggle_ | bool | boolean |

### toggleStrictRandomness

```solidity
function toggleStrictRandomness(bool toggle_) public
```

Enable or disable Strict Randomness

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| toggle_ | bool | boolean |

### toggleValidateLastReveal

```solidity
function toggleValidateLastReveal(bool toggle_) public
```

Enable or disable Automatic Batch Validation when last to reveal

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| toggle_ | bool | boolean |

### toggleForceValidateBatchFile

```solidity
function toggleForceValidateBatchFile(bool toggle_) public
```

Enable or disable Forcing the Validation of a Batch File in some conditions

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| toggle_ | bool | boolean |

### updateInstantSpotRewards

```solidity
function updateInstantSpotRewards(bool state_, uint256 divider_) public
```

Enable or disable instant rewards when SpottingData (Testnet)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| state_ | bool | boolean |
| divider_ | uint256 | base rewards divider |

### updateInstantRevealRewards

```solidity
function updateInstantRevealRewards(bool state_, uint256 divider_) public
```

Enable or disable instant rewards when Revealing (Testnet)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| state_ | bool | boolean |
| divider_ | uint256 | base rewards divider |

### updateMaxPendingDataBatch

```solidity
function updateMaxPendingDataBatch(uint256 MaxPendingDataBatchCount_) public
```

update MaxPendingDataBatchCount, limiting the queue of data to validate

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| MaxPendingDataBatchCount_ | uint256 | max queue size |

### updateSpotFileSize

```solidity
function updateSpotFileSize(uint256 file_size_) public
```

update file_size_, the spot atomic file size

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| file_size_ | uint256 | spot atomic file size |

### updateGasLeftLimit

```solidity
function updateGasLeftLimit(uint256 new_limit_) public
```

update Gas Left limit, limiting the validation loops iterations

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| new_limit_ | uint256 | gas limit in wei |

### getAttribute

```solidity
function getAttribute(bytes32 _UUID, string _attrName) public view returns (uint256)
```

getAttribute from UUID and attrName

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _UUID | bytes32 | unique identifier |
| _attrName | string | name of the attribute |

### setAttribute

```solidity
function setAttribute(bytes32 _UUID, string _attrName, uint256 _attrVal) internal
```

setAttribute from UUID , attrName & attrVal

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _UUID | bytes32 | unique identifier |
| _attrName | string | name of the attribute |
| _attrVal | uint256 | value of the attribute |

### _retrieveSFuel

```solidity
function _retrieveSFuel() internal
```

Refill the msg.sender with sFuel. Skale gasless "gas station network" equivalent

### isInAvailableWorkers

```solidity
function isInAvailableWorkers(address _worker) public view returns (bool)
```

Checks if Worker is Available

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _worker | address | worker address |

### isInBusyWorkers

```solidity
function isInBusyWorkers(address _worker) public view returns (bool)
```

Checks if Worker is Busy

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _worker | address | worker address |

### IsInLogoffList

```solidity
function IsInLogoffList(address _worker) public view returns (bool)
```

Checks if Worker in the "to log off" list

### REMOVED_WORKER_INDEX_VALUE

```solidity
uint256 REMOVED_WORKER_INDEX_VALUE
```

### PopFromAvailableWorkers

```solidity
function PopFromAvailableWorkers(address _worker) internal
```

Pop _worker from the Busy workers

### PopFromBusyWorkers

```solidity
function PopFromBusyWorkers(address _worker) internal
```

Pop worker from the Busy workers

### PopFromLogoffList

```solidity
function PopFromLogoffList(address _worker) internal
```

### PushInAvailableWorkers

```solidity
function PushInAvailableWorkers(address _worker) internal
```

### PushInBusyWorkers

```solidity
function PushInBusyWorkers(address _worker) internal
```

### isWorkerAllocatedToBatch

```solidity
function isWorkerAllocatedToBatch(uint256 _DataBatchId, address _worker) public view returns (bool)
```

### SelectAddressForUser

```solidity
function SelectAddressForUser(address _worker, uint256 _TokensAmountToAllocate) public view returns (address)
```

### RegisterWorker

```solidity
function RegisterWorker() public
```

### UnregisterWorker

```solidity
function UnregisterWorker() public
```

### processLogoffRequests

```solidity
function processLogoffRequests(uint256 n_iteration) internal
```

### deleteData

```solidity
function deleteData(uint256 _DataId) public
```

Delete Spotted Data with ID _DataId

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataId | uint256 | index of the data to delete |

### deleteDataBatch

```solidity
function deleteDataBatch(uint256 _BatchId) public
```

Delete DataBatch with ID _BatchId

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _BatchId | uint256 | index of the batch to delete |

### deleteOldData

```solidity
function deleteOldData() internal
```

Delete Data in a rolling window

### TriggerUpdate

```solidity
function TriggerUpdate(uint256 iteration_count) public
```

Trigger potential Data Batches Validations & Work Allocations

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| iteration_count | uint256 | max number of iterations |

### TriggerAllocations

```solidity
function TriggerAllocations(uint256 iteration_count) public
```

Trigger at most iteration_count Work Allocations (N workers on a Batch)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| iteration_count | uint256 | max number of iterations |

### TriggerValidation

```solidity
function TriggerValidation(uint256 iteration_count) public
```

Trigger at most iteration_count Ended DataBatch validations

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| iteration_count | uint256 | max number of iterations |

### AreStringsEqual

```solidity
function AreStringsEqual(string _a, string _b) public pure returns (bool)
```

Checks if two strings are equal

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _a | string | string |
| _b | string | string |

### ValidateDataBatch

```solidity
function ValidateDataBatch(uint256 _DataBatchId) internal
```

Trigger the validation of DataBatch

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

### AllocateWork

```solidity
function AllocateWork() internal
```

Allocate last data batch to be checked by K out N currently available workers.

### IsNewWorkAvailable

```solidity
function IsNewWorkAvailable(address user_) public view returns (bool)
```

To know if new work is available for worker's address user_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user_ | address | user |

### GetCurrentWork

```solidity
function GetCurrentWork(address user_) public view returns (uint256)
```

Get newest work for user

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user_ | address | user |

### updateGlobalSpotFlow

```solidity
function updateGlobalSpotFlow() public
```

Update the global sliding counter of spotted data, measuring the spots per TIMEFRAME (hour)

### getGlobalPeriodSpotCount

```solidity
function getGlobalPeriodSpotCount() public view returns (uint256)
```

Count the total spots per TIMEFRAME (hour)

### updateItemCount

```solidity
function updateItemCount() public
```

Update the global sliding counter of validated data, measuring the URL per TIMEFRAME (hour)

### getPeriodItemCount

```solidity
function getPeriodItemCount() public view returns (uint256)
```

Count the total spots per TIMEFRAME (hour)

### updateUserSpotFlow

```solidity
function updateUserSpotFlow(address user_) public
```

Update the total spots per TIMEFRAME (hour) per USER

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user_ | address | user |

### getUserPeriodSpotCount

```solidity
function getUserPeriodSpotCount(address user_) public view returns (uint256)
```

Count the total spots per TIMEFRAME (hour) per USER

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user_ | address | user |

### SpotData

```solidity
function SpotData(string[] file_hashs_, string[] URL_domains_, uint256[] item_counts_, string extra_) public returns (uint256 Dataid_)
```

Submit new data to the protocol, in the stream, which will be added to the latest batch
            file_hashs_, URL_domains_ & item_counts_ must be of same length

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| file_hashs_ | string[] | array of IPFS hashes, json format |
| URL_domains_ | string[] | array of URL top domain per file (for statistics purpose) |
| item_counts_ | uint256[] | array of size (in number of json items) |
| extra_ | string | extra information (for indexing / archival purpose) |

### commitSpotCheck

```solidity
function commitSpotCheck(uint256 _DataBatchId, bytes32 _encryptedHash, bytes32 _encryptedVote, uint256 _BatchCount, string _From) public
```

Commits spot-check-vote on a DataBatch

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | DataBatch ID |
| _encryptedHash | bytes32 | encrypted hash of the submitted IPFS file (json format) |
| _encryptedVote | bytes32 | encrypted hash of the submitted IPFS vote |
| _BatchCount | uint256 | Batch Count in number of items (in the aggregated IPFS hash) |
| _From | string | extra information (for indexing / archival purpose) |

### revealSpotCheck

```solidity
function revealSpotCheck(uint256 _DataBatchId, string _clearIPFSHash, uint256 _clearVote, uint256 _salt) public
```

Reveals spot-check-vote on a DataBatch

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | DataBatch ID |
| _clearIPFSHash | string | clear hash of the submitted IPFS file (json format) |
| _clearVote | uint256 | clear hash of the submitted IPFS vote |
| _salt | uint256 | arbitraty integer used to hash the previous commit & verify the reveal |

### requestAllocatedStake

```solidity
function requestAllocatedStake(uint256 _numTokens, address user_) internal
```

Loads _numTokens ERC20 tokens into the voting contract for one-to-one voting rights

_Assumes that msg.sender has approved voting contract to spend on their behalf_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _numTokens | uint256 | The number of votingTokens desired in exchange for ERC20 tokens |
| user_ | address | The user address |

### withdrawVotingRights

```solidity
function withdrawVotingRights(uint256 _numTokens, address user_) public
```

Withdraw _numTokens ERC20 tokens from the voting contract, revoking these voting rights

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _numTokens | uint256 | The number of ERC20 tokens desired in exchange for voting rights |
| user_ | address | The user address |

### getSystemTokenBalance

```solidity
function getSystemTokenBalance(address user_) public view returns (uint256 tokens)
```

get Locked Token for the current Contract (WorkSystem)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user_ | address | The user address |

### getAcceptedBatchesCount

```solidity
function getAcceptedBatchesCount() public view returns (uint256 count)
```

Get Total Accepted Batches

### getRejectedBatchesCount

```solidity
function getRejectedBatchesCount() public view returns (uint256 count)
```

Get Total Rejected Batches

### rescueTokens

```solidity
function rescueTokens(uint256 _DataBatchId) public
```

_Unlocks tokens locked in unrevealed spot-check-vote where SpottedData has ended_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | Integer identifier associated with the target SpottedData |

### rescueTokensInMultipleDatas

```solidity
function rescueTokensInMultipleDatas(uint256[] _DataBatchIDs) public
```

_Unlocks tokens locked in unrevealed spot-check-votes where Datas have ended_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchIDs | uint256[] | Array of integer identifiers associated with the target Datas |

### getIPFShashesForBatch

```solidity
function getIPFShashesForBatch(uint256 _DataBatchId) public view returns (string[])
```

get all IPFS hashes, input of the batch

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | ID of the batch |

### getMultiBatchIPFShashes

```solidity
function getMultiBatchIPFShashes(uint256 _DataBatchId_a, uint256 _DataBatchId_b) public view returns (string[])
```

get all IPFS hashes, input of batchs, between batch indices A and B (a < B)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId_a | uint256 | ID of the starting batch |
| _DataBatchId_b | uint256 | ID of the ending batch (included) |

### getBatchCountForBatch

```solidity
function getBatchCountForBatch(uint256 _DataBatchId_a, uint256 _DataBatchId_b) public view returns (uint256 AverageURLCount, uint256[] batchCounts)
```

get all item counts for all batches between batch indices A and B (a < B)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId_a | uint256 | ID of the starting batch |
| _DataBatchId_b | uint256 | ID of the ending batch (included) |

### getDomainsForBatch

```solidity
function getDomainsForBatch(uint256 _DataBatchId) public view returns (string[])
```

get top domain URL for a given batch

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | ID of the batch |

### getFromsForBatch

```solidity
function getFromsForBatch(uint256 _DataBatchId) public view returns (string[])
```

get the From information for a given batch

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | ID of the batch |

### getVotesForBatch

```solidity
function getVotesForBatch(uint256 _DataBatchId) public view returns (uint256[])
```

get all Votes on a given batch

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | ID of the batch |

### getSubmittedFilesForBatch

```solidity
function getSubmittedFilesForBatch(uint256 _DataBatchId) public view returns (string[])
```

get all IPFS files submitted (during commit/reveal) on a given batch

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | ID of the batch |

### getActiveWorkersCount

```solidity
function getActiveWorkersCount() public view returns (uint256 numWorkers)
```

Get all current workers

### getAvailableWorkersCount

```solidity
function getAvailableWorkersCount() public view returns (uint256 numWorkers)
```

Get all available (idle) workers

### getBusyWorkersCount

```solidity
function getBusyWorkersCount() public view returns (uint256 numWorkers)
```

Get all busy workers

### validPosition

```solidity
function validPosition(uint256 _prevID, uint256 _nextID, address _voter, uint256 _numTokens) public view returns (bool APPROVED)
```

_Compares previous and next SpottedData's committed tokens for sorting purposes_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _prevID | uint256 | Integer identifier associated with previous SpottedData in sorted order |
| _nextID | uint256 | Integer identifier associated with next SpottedData in sorted order |
| _voter | address | Address of user to check DLL position for |
| _numTokens | uint256 | The number of tokens to be committed towards the SpottedData (used for sorting) |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| APPROVED | bool | Boolean indication of if the specified position maintains the sort |

### isPassed

```solidity
function isPassed(uint256 _DataBatchId) public view returns (bool passed)
```

Determines if proposal has passed

_Check if votesFor out of totalSpotChecks exceeds votesQuorum (requires DataEnded)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

### getNumPassingTokens

```solidity
function getNumPassingTokens(address _voter, uint256 _DataBatchId, uint256 _salt) public view returns (uint256 correctSpotChecks)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _voter | address |  |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |
| _salt | uint256 | Arbitrarily chosen integer used to generate secretHash |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| correctSpotChecks | uint256 | Number of tokens voted for winning option |

### DataEnded

```solidity
function DataEnded(uint256 _DataBatchId) public view returns (bool ended)
```

Determines if SpottedData is over

_Checks isExpired for specified SpottedData's revealEndDate_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| ended | bool | Boolean indication of whether Dataing period is over |

### getUserDatas

```solidity
function getUserDatas(address user) public view returns (uint256[] user_Datas)
```

Get User Submitted Data (Spots)

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| user_Datas | uint256[] | the array of Data Spotted/Submitted by the user |

### getLastDataId

```solidity
function getLastDataId() public view returns (uint256 DataId)
```

get Last Data Id

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| DataId | uint256 |  |

### getLastBatchId

```solidity
function getLastBatchId() public view returns (uint256 LastBatchId)
```

get Last Batch Id

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| LastBatchId | uint256 |  |

### getLastCheckedBatchId

```solidity
function getLastCheckedBatchId() public view returns (uint256 LastCheckedBatchId)
```

get Last Checked Batch Id

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| LastCheckedBatchId | uint256 |  |

### getLastAllocatedBatchId

```solidity
function getLastAllocatedBatchId() public view returns (uint256 LastAllocatedBatchId)
```

getLastAllocatedBatchId

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| LastAllocatedBatchId | uint256 |  |

### getBatchByID

```solidity
function getBatchByID(uint256 _DataBatchId) public view returns (struct DataSpotting.BatchMetadata batch)
```

get DataBatch By ID

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| batch | struct DataSpotting.BatchMetadata | as BatchMetadata struct |

### getBatchIPFSFileByID

```solidity
function getBatchIPFSFileByID(uint256 _DataBatchId) public view returns (string batch)
```

get Output Batch IPFS File By ID

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| batch | string | IPFS File |

### getBatchsFilesByID

```solidity
function getBatchsFilesByID(uint256 _DataBatchId_a, uint256 _DataBatchId_b) public view returns (string[])
```

get all Output Batch IPFS Files (hashes),between batch indices A and B (a < B)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId_a | uint256 | ID of the starting batch |
| _DataBatchId_b | uint256 | ID of the ending batch (included) |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | string[] | array of Batch File ID between index A and B (excluded), example getBatchsFilesByID(0,10) -> 0,9 |

### getDataByID

```solidity
function getDataByID(uint256 _DataId) public view returns (struct DataSpotting.SpottedData data)
```

get Data By ID

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| data | struct DataSpotting.SpottedData | as SpottedData struct |

### getTxCounter

```solidity
function getTxCounter() public view returns (uint256 Counter)
```

getCounter

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| Counter | uint256 | of all "accepted transactions" |

### getItemCounter

```solidity
function getItemCounter() public view returns (uint256 Counter)
```

getCounter

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| Counter | uint256 | of the last Dataed a user started |

### DataCommitEndDate

```solidity
function DataCommitEndDate(uint256 _DataBatchId) public view returns (uint256 commitEndDate)
```

Determines DataCommitEndDate

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| commitEndDate | uint256 | indication of whether Dataing period is over |

### DataRevealEndDate

```solidity
function DataRevealEndDate(uint256 _DataBatchId) public view returns (uint256 revealEndDate)
```

Determines DataRevealEndDate

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| revealEndDate | uint256 | indication of whether Dataing period is over |

### commitPeriodActive

```solidity
function commitPeriodActive(uint256 _DataBatchId) public view returns (bool active)
```

Checks if the commit period is still active for the specified SpottedData

_Checks isExpired for the specified SpottedData's commitEndDate_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| active | bool | Boolean indication of isCommitPeriodActive for target SpottedData |

### commitPeriodOver

```solidity
function commitPeriodOver(uint256 _DataBatchId) public view returns (bool active)
```

Checks if the commit period is over

_Checks isExpired for the specified SpottedData's commitEndDate_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| active | bool | Boolean indication of isCommitPeriodActive for target SpottedData |

### remainingCommitDuration

```solidity
function remainingCommitDuration(uint256 _DataBatchId) public view returns (uint256 remainingTime)
```

Checks if the commit period is still active for the specified SpottedData

_Checks isExpired for the specified SpottedData's commitEndDate_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| remainingTime | uint256 | Integer |

### revealPeriodActive

```solidity
function revealPeriodActive(uint256 _DataBatchId) public view returns (bool active)
```

Checks if the reveal period is still active for the specified SpottedData

_Checks isExpired for the specified SpottedData's revealEndDate_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

### revealPeriodOver

```solidity
function revealPeriodOver(uint256 _DataBatchId) public view returns (bool active)
```

Checks if the reveal period is over

_Checks isExpired for the specified SpottedData's revealEndDate_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

### remainingRevealDuration

```solidity
function remainingRevealDuration(uint256 _DataBatchId) public view returns (uint256 remainingTime)
```

Checks if the commit period is still active for the specified SpottedData

_Checks isExpired for the specified SpottedData's commitEndDate_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| remainingTime | uint256 | Integer indication of isCommitPeriodActive for target SpottedData |

### didCommit

```solidity
function didCommit(address _voter, uint256 _DataBatchId) public view returns (bool committed)
```

_Checks if user has committed for specified SpottedData_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _voter | address | Address of user to check against |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| committed | bool | Boolean indication of whether user has committed |

### didReveal

```solidity
function didReveal(address _voter, uint256 _DataBatchId) public view returns (bool revealed)
```

_Checks if user has revealed for specified SpottedData_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _voter | address | Address of user to check against |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| revealed | bool | Boolean indication of whether user has revealed |

### DataExists

```solidity
function DataExists(uint256 _DataBatchId) public view returns (bool exists)
```

_Checks if a SpottedData exists_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _DataBatchId | uint256 | The DataID whose existance is to be evaluated. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| exists | bool | Boolean Indicates whether a SpottedData exists for the provided DataID |

### AmIRegistered

```solidity
function AmIRegistered() public view returns (bool passed)
```

### isWorkerRegistered

```solidity
function isWorkerRegistered(address _worker) public view returns (bool passed)
```

### getCommitVoteHash

```solidity
function getCommitVoteHash(address _voter, uint256 _DataBatchId) public view returns (bytes32 commitHash)
```

_Gets the bytes32 commitHash property of target SpottedData_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _voter | address | Address of user to check against |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| commitHash | bytes32 | Bytes32 hash property attached to target SpottedData |

### getCommitIPFSHash

```solidity
function getCommitIPFSHash(address _voter, uint256 _DataBatchId) public view returns (bytes32 commitHash)
```

_Gets the bytes32 commitHash property of target SpottedData_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _voter | address | Address of user to check against |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| commitHash | bytes32 | Bytes32 hash property attached to target SpottedData |

### getEncryptedHash

```solidity
function getEncryptedHash(uint256 _clearVote, uint256 _salt) public pure returns (bytes32 keccak256hash)
```

_Gets the bytes32 commitHash property of target SpottedData_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _clearVote | uint256 | vote Option |
| _salt | uint256 | is the salt |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| keccak256hash | bytes32 | Bytes32 hash property attached to target SpottedData |

### getEncryptedStringHash

```solidity
function getEncryptedStringHash(string _hash, uint256 _salt) public pure returns (bytes32 keccak256hash)
```

_Gets the bytes32 commitHash property of target FormattedData_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _hash | string | ipfs hash of aggregated data in a string |
| _salt | uint256 | is the salt |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| keccak256hash | bytes32 | Bytes32 hash property attached to target FormattedData |

### getNumTokens

```solidity
function getNumTokens(address _voter, uint256 _DataBatchId) public view returns (uint256 numTokens)
```

_Wrapper for getAttribute with attrName="numTokens"_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _voter | address | Address of user to check against |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| numTokens | uint256 | Number of tokens committed to SpottedData in sorted SpottedData-linked-list |

### getLastNode

```solidity
function getLastNode(address _voter) public view returns (uint256 DataID)
```

_Gets top element of sorted SpottedData-linked-list_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _voter | address | Address of user to check against |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| DataID | uint256 | Integer identifier to SpottedData with maximum number of tokens committed to it |

### getLockedTokens

```solidity
function getLockedTokens(address _voter) public view returns (uint256 numTokens)
```

_Gets the numTokens property of getLastNode_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _voter | address | Address of user to check against |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| numTokens | uint256 | Maximum number of tokens committed in SpottedData specified |

### getInsertPointForNumTokens

```solidity
function getInsertPointForNumTokens(address _voter, uint256 _numTokens, uint256 _DataBatchId) public view returns (uint256 prevNode)
```

### isExpired

```solidity
function isExpired(uint256 _terminationDate) public view returns (bool expired)
```

_Checks if an expiration date has been reached_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _terminationDate | uint256 | Integer timestamp of date to compare current timestamp with |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| expired | bool | Boolean indication of whether the terminationDate has passed |

### attrUUID

```solidity
function attrUUID(address user_, uint256 _DataBatchId) public pure returns (bytes32 UUID)
```

_Generates an identifier which associates a user and a SpottedData together_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| user_ | address |  |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| UUID | bytes32 | Hash which is deterministic from user_ and _DataBatchId |
