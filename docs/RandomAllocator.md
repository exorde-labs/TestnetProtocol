
## RandomAllocator

### getSeed

```solidity
function getSeed() public view returns (bytes32 addr)
```

Get Native RNG Seed endpoint from SKALE chain

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| addr | bytes32 | bytes32 seed output |

### getRandom

```solidity
function getRandom() public view returns (uint256)
```

get Random Integer out of native seed

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | randomly generated integer |

### generateIntegers

```solidity
function generateIntegers(uint256 _k, uint256 N_range) public view returns (uint256[])
```

generate _k integers from 0 to N

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _k | uint256 | integer |
| N_range | uint256 | integer |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256[] | randomly generated integers array of size _k |

### random_selection

```solidity
function random_selection(uint256 k, uint256 N) public view returns (uint256[])
```

_Select k unique integer out of the N range (0,1,2,...,N)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| k | uint256 | integer |
| N | uint256 | integer |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256[] | array of selected random integers |
