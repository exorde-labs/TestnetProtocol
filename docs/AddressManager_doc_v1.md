
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

### isMasterOfMe

```solidity
function isMasterOfMe(address _master) public view returns (bool)
```

### isMasterOf

```solidity
function isMasterOf(address _master, address _address) public view returns (bool)
```

### getMasterSubs

```solidity
function getMasterSubs(address _master) public view returns (address[])
```

### isSubWorkerOfMe

```solidity
function isSubWorkerOfMe(address _worker) public view returns (bool)
```

### isSubWorkerOf

```solidity
function isSubWorkerOf(address _master, address _address) public view returns (bool)
```

### isSubInMasterArray

```solidity
function isSubInMasterArray(address _worker, address _master) public view returns (bool)
```

### getMaster

```solidity
function getMaster(address _worker) public view returns (address)
```

### PopFromSubsArray

```solidity
function PopFromSubsArray(address _master, address _worker) internal
```

### AreMasterSubLinked

```solidity
function AreMasterSubLinked(address _master, address _address) public view returns (bool)
```

### MasterClaimSub

```solidity
function MasterClaimSub(address _address) public
```

### MasterClaimManySubs

```solidity
function MasterClaimManySubs(address[] _addresses) public
```

### MasterRemoveSub

```solidity
function MasterRemoveSub(address _address) public
```

### MasterRemoveManySubs

```solidity
function MasterRemoveManySubs(address[] _addresses) public
```

### FetchHighestMaster

```solidity
function FetchHighestMaster(address _worker) public view returns (address)
```

### TransferRepToMaster

```solidity
function TransferRepToMaster(address _worker) internal
```

### TransferRewardsToMaster

```solidity
function TransferRewardsToMaster(address _worker) internal
```

### ClaimMaster

```solidity
function ClaimMaster(address _master) public
```

### RemoveMaster

```solidity
function RemoveMaster(address _master) public
```

## IAddressManager

### isSenderMasterOf

```solidity
function isSenderMasterOf(address _address) external returns (bool)
```

### isSenderSubOf

```solidity
function isSenderSubOf(address _master) external returns (bool)
```

### isSubAddress

```solidity
function isSubAddress(address _master, address _address) external returns (bool)
```

### addAddress

```solidity
function addAddress(address _address) external
```

### removeAddress

```solidity
function removeAddress(address _address) external
```