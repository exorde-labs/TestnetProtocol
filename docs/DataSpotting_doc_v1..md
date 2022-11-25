
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

Destroy Contract, important to release storage space if critical

### updateParametersManager

```solidity
function updateParametersManager(address addr) public
```

Updates Parameters Manager
  @param addr address of the Parameter Contract

### toggleRequiredStaking

```solidity
function toggleRequiredStaking(bool toggle_) public
```

Enable or disable Required Staking for participation 
  @param toggle_ boolean

### toggleTriggerSpotData

```solidity
function toggleTriggerSpotData(bool toggle_) public
```

Enable or disable Triggering Updates when Spotting Data
  @param toggle_ boolean

### toggleStrictRandomness

```solidity
function toggleStrictRandomness(bool toggle_) public
```

Enable or disable Strict Randomness
  @param toggle_ boolean

### toggleValidateLastReveal

```solidity
function toggleValidateLastReveal(bool toggle_) public
```

Enable or disable Automatic Batch Validation when last to reveal
  @param toggle_ boolean

### toggleForceValidateBatchFile

```solidity
function toggleForceValidateBatchFile(bool toggle_) public
```

Enable or disable Forcing the Validation of a Batch File in some conditions
  @param toggle_ boolean

### updateInstantSpotRewards

```solidity
function updateInstantSpotRewards(bool state_, uint256 divider_) public
```

Enable or disable instant rewards when SpottingData (Testnet)
  @param state_ boolean
  @param divider_ base rewards divider

### updateInstantRevealRewards

```solidity
function updateInstantRevealRewards(bool state_, uint256 divider_) public
```

Enable or disable instant rewards when Revealing (Testnet)
  @param state_ boolean
  @param divider_ base rewards divider

### updateMaxPendingDataBatch

```solidity
function updateMaxPendingDataBatch(uint256 MaxPendingDataBatchCount_) public
```

update MaxPendingDataBatchCount, limiting the queue of data to validate
  @param MaxPendingDataBatchCount_ max queue size

### updateSpotFileSize

```solidity
function updateSpotFileSize(uint256 file_size_) public
```

update file_size_, the spot atomic file size
  @param file_size_ spot atomic file size

### updateGasLeftLimit

```solidity
function updateGasLeftLimit(uint256 new_limit_) public
```

update Gas Left limit, limiting the validation loops iterations
  @param new_limit_ gas limit in wei

### getAttribute

```solidity
function getAttribute(bytes32 _UUID, string _attrName) public view returns (uint256)
```

getAttribute from UUID and attrName
  @param _UUID unique identifier
  @param _attrName name of the attribute

### setAttribute

```solidity
function setAttribute(bytes32 _UUID, string _attrName, uint256 _attrVal) internal
```

setAttribute from UUID , attrName & attrVal
  @param _UUID unique identifier
  @param _attrName name of the attribute
  @param _attrVal value of the attribute

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
  @param _worker worker address

### isInBusyWorkers

```solidity
function isInBusyWorkers(address _worker) public view returns (bool)
```

Checks if Worker is Busy
  @param _worker worker address

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
  @param _DataId index of the data to delete

### deleteDataBatch

```solidity
function deleteDataBatch(uint256 _BatchId) public
```

Delete DataBatch with ID _BatchId
  @param _BatchId index of the batch to delete

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
  @param iteration_count max number of iterations

### TriggerAllocations

```solidity
function TriggerAllocations(uint256 iteration_count) public
```

Trigger at most iteration_count Work Allocations (N workers on a Batch)
  @param iteration_count max number of iterations

### TriggerValidation

```solidity
function TriggerValidation(uint256 iteration_count) public
```

Trigger at most iteration_count Ended DataBatch validations
  @param iteration_count max number of iterations

### AreStringsEqual

```solidity
function AreStringsEqual(string _a, string _b) public pure returns (bool)
```

Checks if two strings are equal
  @param _a string
  @param _b string

### ValidateDataBatch

```solidity
function ValidateDataBatch(uint256 _DataBatchId) internal
```

Trigger the validation of DataBatch
  @param _DataBatchId Integer identifier associated with target SpottedData

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
  @param user_ user

### GetCurrentWork

```solidity
function GetCurrentWork(address user_) public view returns (uint256)
```

Get newest work for user
  @param user_ user

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
  @param user_ user

### getUserPeriodSpotCount

```solidity
function getUserPeriodSpotCount(address user_) public view returns (uint256)
```

Count the total spots per TIMEFRAME (hour) per USER
  @param user_ user

### SpotData

```solidity
function SpotData(string[] file_hashs_, string[] URL_domains_, uint256[] item_counts_, string extra_) public returns (uint256 Dataid_)
```

Submit new data to the protocol, in the stream, which will be added to the latest batch
            file_hashs_, URL_domains_ & item_counts_ must be of same length
  @param file_hashs_ array of IPFS hashes, json format
  @param URL_domains_ array of URL top domain per file (for statistics purpose)
  @param item_counts_ array of size (in number of json items)
  @param extra_ extra information (for indexing / archival purpose)

### commitSpotCheck

```solidity
function commitSpotCheck(uint256 _DataBatchId, bytes32 _encryptedHash, bytes32 _encryptedVote, uint256 _BatchCount, string _From) public
```

Commits spot-check-vote on a DataBatch
  @param _DataBatchId DataBatch ID
  @param _encryptedHash encrypted hash of the submitted IPFS file (json format)
  @param _encryptedVote encrypted hash of the submitted IPFS vote
  @param _BatchCount Batch Count in number of items (in the aggregated IPFS hash)
  @param _From extra information (for indexing / archival purpose)

### revealSpotCheck

```solidity
function revealSpotCheck(uint256 _DataBatchId, string _clearIPFSHash, uint256 _clearVote, uint256 _salt) public
```

Reveals spot-check-vote on a DataBatch
  @param _DataBatchId DataBatch ID
  @param _clearIPFSHash clear hash of the submitted IPFS file (json format)
  @param _clearVote clear hash of the submitted IPFS vote
  @param _salt arbitraty integer used to hash the previous commit & verify the reveal

### requestAllocatedStake

```solidity
function requestAllocatedStake(uint256 _numTokens, address user_) internal
```

Loads _numTokens ERC20 tokens into the voting contract for one-to-one voting rights
  @dev Assumes that msg.sender has approved voting contract to spend on their behalf
  @param _numTokens The number of votingTokens desired in exchange for ERC20 tokens
  @param user_ The user address

### withdrawVotingRights

```solidity
function withdrawVotingRights(uint256 _numTokens, address user_) public
```

Withdraw _numTokens ERC20 tokens from the voting contract, revoking these voting rights
  @param _numTokens The number of ERC20 tokens desired in exchange for voting rights
  @param user_ The user address

### getSystemTokenBalance

```solidity
function getSystemTokenBalance(address user_) public view returns (uint256 tokens)
```

get Locked Token for the current Contract (WorkSystem)
  @param user_ The user address

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

_Unlocks tokens locked in unrevealed spot-check-vote where SpottedData has ended
  @param _DataBatchId Integer identifier associated with the target SpottedData_

### rescueTokensInMultipleDatas

```solidity
function rescueTokensInMultipleDatas(uint256[] _DataBatchIDs) public
```

_Unlocks tokens locked in unrevealed spot-check-votes where Datas have ended
  @param _DataBatchIDs Array of integer identifiers associated with the target Datas_

### getIPFShashesForBatch

```solidity
function getIPFShashesForBatch(uint256 _DataBatchId) public view returns (string[])
```

get all IPFS hashes, input of the batch 
  @param _DataBatchId ID of the batch

### getMultiBatchIPFShashes

```solidity
function getMultiBatchIPFShashes(uint256 _DataBatchId_a, uint256 _DataBatchId_b) public view returns (string[])
```

get all IPFS hashes, input of batchs, between batch indices A and B (a < B)
  @param _DataBatchId_a ID of the starting batch
  @param _DataBatchId_b ID of the ending batch (included)

### getBatchCountForBatch

```solidity
function getBatchCountForBatch(uint256 _DataBatchId_a, uint256 _DataBatchId_b) public view returns (uint256 AverageURLCount, uint256[] batchCounts)
```

get all item counts for all batches between batch indices A and B (a < B)
  @param _DataBatchId_a ID of the starting batch
  @param _DataBatchId_b ID of the ending batch (included)

### getDomainsForBatch

```solidity
function getDomainsForBatch(uint256 _DataBatchId) public view returns (string[])
```

get top domain URL for a given batch
  @param _DataBatchId ID of the batch

### getFromsForBatch

```solidity
function getFromsForBatch(uint256 _DataBatchId) public view returns (string[])
```

get the From information for a given batch
  @param _DataBatchId ID of the batch

### getVotesForBatch

```solidity
function getVotesForBatch(uint256 _DataBatchId) public view returns (uint256[])
```

get all Votes on a given batch
  @param _DataBatchId ID of the batch

### getSubmittedFilesForBatch

```solidity
function getSubmittedFilesForBatch(uint256 _DataBatchId) public view returns (string[])
```

get all IPFS files submitted (during commit/reveal) on a given batch
  @param _DataBatchId ID of the batch

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

_Compares previous and next SpottedData's committed tokens for sorting purposes
  @param _prevID Integer identifier associated with previous SpottedData in sorted order
  @param _nextID Integer identifier associated with next SpottedData in sorted order
  @param _voter Address of user to check DLL position for
  @param _numTokens The number of tokens to be committed towards the SpottedData (used for sorting)
  @return APPROVED Boolean indication of if the specified position maintains the sort_

### isPassed

```solidity
function isPassed(uint256 _DataBatchId) public view returns (bool passed)
```

Determines if proposal has passed
  @dev Check if votesFor out of totalSpotChecks exceeds votesQuorum (requires DataEnded)
  @param _DataBatchId Integer identifier associated with target SpottedData

### getNumPassingTokens

```solidity
function getNumPassingTokens(address _voter, uint256 _DataBatchId, uint256 _salt) public view returns (uint256 correctSpotChecks)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _voter | address |  |
| _DataBatchId | uint256 | Integer identifier associated with target SpottedData
   @param _salt Arbitrarily chosen integer used to generate secretHash
   @return correctSpotChecks Number of tokens voted for winning option |
| _salt | uint256 |  |

### DataEnded

```solidity
function DataEnded(uint256 _DataBatchId) public view returns (bool ended)
```

Determines if SpottedData is over
  @dev Checks isExpired for specified SpottedData's revealEndDate
  @return ended Boolean indication of whether Dataing period is over

### getUserDatas

```solidity
function getUserDatas(address user) public view returns (uint256[] user_Datas)
```

Get User Submitted Data (Spots)
  @return user_Datas the array of Data Spotted/Submitted by the user

### getLastDataId

```solidity
function getLastDataId() public view returns (uint256 DataId)
```

get Last Data Id
  @return DataId

### getLastBatchId

```solidity
function getLastBatchId() public view returns (uint256 LastBatchId)
```

get Last Batch Id
  @return LastBatchId

### getLastCheckedBatchId

```solidity
function getLastCheckedBatchId() public view returns (uint256 LastCheckedBatchId)
```

get Last Checked Batch Id
  @return LastCheckedBatchId

### getLastAllocatedBatchId

```solidity
function getLastAllocatedBatchId() public view returns (uint256 LastAllocatedBatchId)
```

getLastAllocatedBatchId
  @return LastAllocatedBatchId

### getBatchByID

```solidity
function getBatchByID(uint256 _DataBatchId) public view returns (struct DataSpotting.BatchMetadata batch)
```

get DataBatch By ID
  @return batch as BatchMetadata struct

### getBatchIPFSFileByID

```solidity
function getBatchIPFSFileByID(uint256 _DataBatchId) public view returns (string batch)
```

get Output Batch IPFS File By ID
  @return batch IPFS File

### getBatchsFilesByID

```solidity
function getBatchsFilesByID(uint256 _DataBatchId_a, uint256 _DataBatchId_b) public view returns (string[])
```

get all Output Batch IPFS Files (hashes),between batch indices A and B (a < B)
  @param _DataBatchId_a ID of the starting batch
  @param _DataBatchId_b ID of the ending batch (included)

### getDataByID

```solidity
function getDataByID(uint256 _DataId) public view returns (struct DataSpotting.SpottedData data)
```

get Data By ID
  @return data as SpottedData struct

### getTxCounter

```solidity
function getTxCounter() public view returns (uint256 Counter)
```

getCounter
  @return Counter of all "accepted transactions"

### getItemCounter

```solidity
function getItemCounter() public view returns (uint256 Counter)
```

getCounter
  @return Counter of the last Dataed a user started

### DataCommitEndDate

```solidity
function DataCommitEndDate(uint256 _DataBatchId) public view returns (uint256 commitEndDate)
```

Determines DataCommitEndDate
  @return commitEndDate indication of whether Dataing period is over

### DataRevealEndDate

```solidity
function DataRevealEndDate(uint256 _DataBatchId) public view returns (uint256 revealEndDate)
```

Determines DataRevealEndDate
  @return revealEndDate indication of whether Dataing period is over

### commitPeriodActive

```solidity
function commitPeriodActive(uint256 _DataBatchId) public view returns (bool active)
```

Checks if the commit period is still active for the specified SpottedData
  @dev Checks isExpired for the specified SpottedData's commitEndDate
  @param _DataBatchId Integer identifier associated with target SpottedData
  @return active Boolean indication of isCommitPeriodActive for target SpottedData

### commitPeriodOver

```solidity
function commitPeriodOver(uint256 _DataBatchId) public view returns (bool active)
```

Checks if the commit period is over
  @dev Checks isExpired for the specified SpottedData's commitEndDate
  @param _DataBatchId Integer identifier associated with target SpottedData
  @return active Boolean indication of isCommitPeriodActive for target SpottedData

### remainingCommitDuration

```solidity
function remainingCommitDuration(uint256 _DataBatchId) public view returns (uint256 remainingTime)
```

Checks if the commit period is still active for the specified SpottedData
  @dev Checks isExpired for the specified SpottedData's commitEndDate
  @param _DataBatchId Integer identifier associated with target SpottedData
  @return remainingTime Integer

### revealPeriodActive

```solidity
function revealPeriodActive(uint256 _DataBatchId) public view returns (bool active)
```

Checks if the reveal period is still active for the specified SpottedData
  @dev Checks isExpired for the specified SpottedData's revealEndDate
  @param _DataBatchId Integer identifier associated with target SpottedData

### revealPeriodOver

```solidity
function revealPeriodOver(uint256 _DataBatchId) public view returns (bool active)
```

Checks if the reveal period is over
  @dev Checks isExpired for the specified SpottedData's revealEndDate
  @param _DataBatchId Integer identifier associated with target SpottedData

### remainingRevealDuration

```solidity
function remainingRevealDuration(uint256 _DataBatchId) public view returns (uint256 remainingTime)
```

Checks if the commit period is still active for the specified SpottedData
  @dev Checks isExpired for the specified SpottedData's commitEndDate
  @param _DataBatchId Integer identifier associated with target SpottedData
  @return remainingTime Integer indication of isCommitPeriodActive for target SpottedData

### didCommit

```solidity
function didCommit(address _voter, uint256 _DataBatchId) public view returns (bool committed)
```

_Checks if user has committed for specified SpottedData
  @param _voter Address of user to check against
  @param _DataBatchId Integer identifier associated with target SpottedData
  @return committed Boolean indication of whether user has committed_

### didReveal

```solidity
function didReveal(address _voter, uint256 _DataBatchId) public view returns (bool revealed)
```

_Checks if user has revealed for specified SpottedData
  @param _voter Address of user to check against
  @param _DataBatchId Integer identifier associated with target SpottedData
  @return revealed Boolean indication of whether user has revealed_

### DataExists

```solidity
function DataExists(uint256 _DataBatchId) public view returns (bool exists)
```

_Checks if a SpottedData exists
  @param _DataBatchId The DataID whose existance is to be evaluated.
  @return exists Boolean Indicates whether a SpottedData exists for the provided DataID_

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

_Gets the bytes32 commitHash property of target SpottedData
  @param _voter Address of user to check against
  @param _DataBatchId Integer identifier associated with target SpottedData
  @return commitHash Bytes32 hash property attached to target SpottedData_

### getCommitIPFSHash

```solidity
function getCommitIPFSHash(address _voter, uint256 _DataBatchId) public view returns (bytes32 commitHash)
```

_Gets the bytes32 commitHash property of target SpottedData
  @param _voter Address of user to check against
  @param _DataBatchId Integer identifier associated with target SpottedData
  @return commitHash Bytes32 hash property attached to target SpottedData_

### getEncryptedHash

```solidity
function getEncryptedHash(uint256 _clearVote, uint256 _salt) public pure returns (bytes32 keccak256hash)
```

_Gets the bytes32 commitHash property of target SpottedData
  @param _clearVote vote Option
  @param _salt is the salt
  @return keccak256hash Bytes32 hash property attached to target SpottedData_

### getEncryptedStringHash

```solidity
function getEncryptedStringHash(string _hash, uint256 _salt) public pure returns (bytes32 keccak256hash)
```

_Gets the bytes32 commitHash property of target FormattedData
  @param _hash ipfs hash of aggregated data in a string
  @param _salt is the salt
  @return keccak256hash Bytes32 hash property attached to target FormattedData_

### getNumTokens

```solidity
function getNumTokens(address _voter, uint256 _DataBatchId) public view returns (uint256 numTokens)
```

_Wrapper for getAttribute with attrName="numTokens"
  @param _voter Address of user to check against
  @param _DataBatchId Integer identifier associated with target SpottedData
  @return numTokens Number of tokens committed to SpottedData in sorted SpottedData-linked-list_

### getLastNode

```solidity
function getLastNode(address _voter) public view returns (uint256 DataID)
```

_Gets top element of sorted SpottedData-linked-list
  @param _voter Address of user to check against
  @return DataID Integer identifier to SpottedData with maximum number of tokens committed to it_

### getLockedTokens

```solidity
function getLockedTokens(address _voter) public view returns (uint256 numTokens)
```

_Gets the numTokens property of getLastNode
  @param _voter Address of user to check against
  @return numTokens Maximum number of tokens committed in SpottedData specified_

### getInsertPointForNumTokens

```solidity
function getInsertPointForNumTokens(address _voter, uint256 _numTokens, uint256 _DataBatchId) public view returns (uint256 prevNode)
```

### isExpired

```solidity
function isExpired(uint256 _terminationDate) public view returns (bool expired)
```

_Checks if an expiration date has been reached
  @param _terminationDate Integer timestamp of date to compare current timestamp with
  @return expired Boolean indication of whether the terminationDate has passed_

### attrUUID

```solidity
function attrUUID(address user_, uint256 _DataBatchId) public pure returns (bytes32 UUID)
```

_Generates an identifier which associates a user and a SpottedData together
  @param _DataBatchId Integer identifier associated with target SpottedData
  @return UUID Hash which is deterministic from user_ and _DataBatchId_