
## AddressManager

### MasterClaimingWorker

```solidity
mapping(address => mapping(address => bool)) MasterClaimingWorker
```

### WorkerClaimingMaster

```solidity
mapping(address => mapping(address => bool)) WorkerClaimingMaster
```

### MasterToSubsMap

```solidity
mapping(address => address[]) MasterToSubsMap
```

### SubToMasterMap

```solidity
mapping(address => address) SubToMasterMap
```

### MAX_MASTER_LOOKUP

```solidity
uint256 MAX_MASTER_LOOKUP
```

### Parameters

```solidity
contract IParametersManager Parameters
```

### AddressAddedByMaster

```solidity
event AddressAddedByMaster(address account, address account2)
```

### AddressRemovedByMaster

```solidity
event AddressRemovedByMaster(address account, address account2)
```

### AddressAddedByWorker

```solidity
event AddressAddedByWorker(address account, address account2)
```

### AddressRemovedByWorker

```solidity
event AddressRemovedByWorker(address account, address account2)
```

### ReputationTransfered

```solidity
event ReputationTransfered(address account, address account2)
```

### RewardsTransfered

```solidity
event RewardsTransfered(address account, address account2)
```

### updateParametersManager

```solidity
function updateParametersManager(address addr) public
```

Updates the Parameters Manager contract to use

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| addr | address | new address of the Parameters Manager contract |

### isMasterOfMe

```solidity
function isMasterOfMe(address _master) public view returns (bool)
```

Returns if _master is a master of msg.sender

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _master | address | address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool true if _master is a Master of msg.sender |

### isMasterOf

```solidity
function isMasterOf(address _master, address _address) public view returns (bool)
```

Returns if _master is a master of _address

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _master | address | address |
| _address | address | address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool true if _master is a Master of _address |

### getMasterSubs

```solidity
function getMasterSubs(address _master) public view returns (address[])
```

Get all sub workers for a given Master address

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _master | address | address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address[] | array of addresses |

### isSubWorkerOfMe

```solidity
function isSubWorkerOfMe(address _worker) public view returns (bool)
```

Check if a worker is a sub address of the msg.sender

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _worker | address | worker address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool true if _worker is a wub worker of msg.sender (master) |

### isSubWorkerOf

```solidity
function isSubWorkerOf(address _master, address _address) public view returns (bool)
```

Returns the master claimed by worker _worker

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _master | address | address |
| _address | address | address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool true if _address is claimed by _master |

### isSubInMasterArray

```solidity
function isSubInMasterArray(address _worker, address _master) public view returns (bool)
```

Check if sub worker is in the MasterToSubsMap mapping of Master

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _worker | address | address |
| _master | address | address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool true if _address is in the MasterToSubsMap mapping of _master |

### getMaster

```solidity
function getMaster(address _worker) public view returns (address)
```

Returns the master claimed by worker _worker

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _worker | address | address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | address of worker's master address |

### PopFromSubsArray

```solidity
function PopFromSubsArray(address _master, address _worker) internal
```

Pops _worker from Master's MasterToSubsMap array

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _master | address | address |
| _worker | address | address |

### AreMasterSubLinked

```solidity
function AreMasterSubLinked(address _master, address _address) public view returns (bool)
```

Checks if a _master and _address and mapped in both ways (master & sub worker of)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _master | address | address |
| _address | address | address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool true if both addresses are mapped to each other |

### MasterClaimSub

```solidity
function MasterClaimSub(address _address) public
```

Add sub-worker addresses mapped to msg.sender

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _address | address | address |

### MasterClaimManySubs

```solidity
function MasterClaimManySubs(address[] _addresses) public
```

Add mutliple sub-worker addresses to be mapped to msg.sender

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _addresses | address[] | array of address |

### MasterRemoveSub

```solidity
function MasterRemoveSub(address _address) public
```

Remove sub-worker addresses mapped to msg.sender

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _address | address | address |

### MasterRemoveManySubs

```solidity
function MasterRemoveManySubs(address[] _addresses) public
```

Remove Multiple sub-worker addresses mapped to msg.sender

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _addresses | address[] | array of addresses |

### FetchHighestMaster

```solidity
function FetchHighestMaster(address _worker) public view returns (address)
```

Fetch the Highest Master on the graph starting from the _worker leaf

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _worker | address | address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The highest master of worker _worker, or _worker if no master found |

### TransferRepToMaster

```solidity
function TransferRepToMaster(address _worker) internal
```

Transfer Current Reputation (REP) of address _worker to its master

### TransferRewardsToMaster

```solidity
function TransferRewardsToMaster(address _worker) internal
```

Transfer Current Rewards of address _worker to its master

### ClaimMaster

```solidity
function ClaimMaster(address _master) public
```

Claim _master Address as master of msg.sender

### RemoveMaster

```solidity
function RemoveMaster(address _master) public
```

Unclaim _master Address as master of msg.sender
