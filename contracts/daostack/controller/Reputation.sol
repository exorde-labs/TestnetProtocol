// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";

// Copied from @daostack/infra/contracts/Reputation.sol and added the MintMultiple function

/**
 * @title Reputation system
 * @dev A DAO has Reputation System which allows peers to rate other peers in order to build trust .
 * A reputation is use to assign influence measure to a DAO'S peers.
 * Reputation is similar to regular tokens but with one crucial difference: It is non-transferable.
 * The Reputation contract maintain a map of address to reputation value.
 * It provides an onlyOwner functions to mint and burn reputation _to (or _from) a specific address.
 */
contract Reputation is Ownable {
    uint8 public decimals = 18; //Number of decimals of the smallest unit
    // Event indicating minting of reputation to an address.
    event Mint(address indexed _to, uint256 _amount);
    // Event indicating burning of reputation for an address.
    event Burn(address indexed _from, uint256 _amount);

    // Store new Reputation checkpoint every 200 000 blocks (by default, updatable below)
    // Can become a problem after 200 million blocks.
    uint256 public checkpoint_interval = 200000; 
    uint256 public global_checkpoint_interval = 1000; 

    // @dev `Checkpoint` is the structure that attaches a block number to a
    //  given value, the block number attached is the one that last changed the
    //  value
    struct Checkpoint {
        // `fromBlock` is the block number that the value was generated from
        uint128 fromBlock;
        // `value` is the amount of reputation at a specific block number
        uint128 value;
    }

    address[] public _addresses;
    mapping(address => bool) public IsAddressSeen; //careful, is never reset

    // `balances` is the map that tracks the balance of each address, in this
    //  contract when the balance changes the block number that the change
    //  occurred is also included in the map
    mapping(address => Checkpoint[]) private balances;

    // Tracks the history of the `totalSupply` of the reputation
    Checkpoint[] private totalSupplyHistory;

    /**
  * @dev Returns all worker addresses between index A_ and index B
  * @param A_ Address of user to check against
  * @param B_ Integer identifier associated with target SpottedData
  * @return workers array of workers of size (B_-A_+1)
  */
    function getAllWorkersBetweenIndex(uint256 A_, uint256 B_) public view returns (address[] memory workers) {
        require(B_>= A_, " _B must be >= _A");
        require(B_<= (_addresses.length -1), " B_ is out of bounds");
        uint256 _array_size = B_ - A_+1;
        address[] memory address_list = new address[](_array_size);
        for (uint256 i = 0; i < _array_size; i++) {
            address_list[i] = _addresses[i+A_];
        }
        return address_list;
    }

    /**
  * @notice get _addresses length
  * @return length of the array
  */
    function getAllAddressLength() public view returns (uint256 length) {
        return _addresses.length;
    }

    /**
     * @dev Destroy address_list array, important to release storage space if critical
     */
    function deleteAllAddressArray() public onlyOwner {
        delete _addresses;  // WARNING: IsAddressSeen is not reset with this
    }

    /**
     * @dev Reset/clear IsAddressSeen for users_
     */
    function clearIsAddressSeen(address[] memory users_) public onlyOwner {
        for (uint256 i = 0; i < users_.length; i++){
            address _user = users_[i];
            delete IsAddressSeen[_user];
        }
    }

    /**
     * @dev Destroy checkpoints for users users_, important to release storage space if critical
     */
    function resetCheckpointsUsers(address[] memory users_) public onlyOwner {
        for (uint256 i = 0; i < users_.length; i++){
            address _user = users_[i];
            uint256 current_balance = balanceOf(_user) ;
            delete balances[_user];
            updateValueAtNow(balances[_user], current_balance, checkpoint_interval);
            require(balanceOf(_user) == current_balance, "Reputation: not preserved during resetCheckpointsUsers");
        }
    }

    // @notice Update the checkpoint invercal (in block count)
    // @param new_interval_ New interval amount in blocks
    function updateCheckpointInterval(uint256 new_interval_) public onlyOwner {
        require(new_interval_ > 1000, "new interval must be > 1000");
        checkpoint_interval = new_interval_;
    }

    // @notice Update the global checkpoint invercal (in block count)
    // @param new_global_interval_ New global interval amount in blocks
    function updateGlobalCheckpointInterval(uint256 new_global_interval_) public onlyOwner {
        require(new_global_interval_ > 1000, "new interval must be > 1000");
        global_checkpoint_interval = new_global_interval_;
    }


    // @notice Generates `_amount` reputation that are assigned to `_owner`
    // @param _user The address that will be assigned the new reputation
    // @param _amount The quantity of reputation generated
    // @return True if the reputation are generated correctly
    function mint(address _user, uint256 _amount) public onlyOwner returns (bool) {
        uint256 curTotalSupply = totalSupply();
        require(curTotalSupply + _amount >= curTotalSupply); // Check for overflow
        uint256 previousBalanceTo = balanceOf(_user);
        require(previousBalanceTo + _amount >= previousBalanceTo); // Check for overflow

        if ( !IsAddressSeen[_user] ){
            _addresses.push(_user);
            IsAddressSeen[_user] = true;
        }

        updateValueAtNow(totalSupplyHistory, curTotalSupply + _amount, global_checkpoint_interval);
        updateValueAtNow(balances[_user], previousBalanceTo + _amount, checkpoint_interval);
        emit Mint(_user, _amount);
        return true;
    }

    // @notice Generates `_amount` reputation that are assigned to `_owner`
    // @param _user The address that will be assigned the new reputation
    // @param _amount The quantity of reputation generated
    // @return True if the reputation are generated correctly
    function mintMultiple(address[] memory _user, uint256[] memory _amount) public onlyOwner returns (bool) {
        for (uint256 i = 0; i < _user.length; i++) {
            uint256 curTotalSupply = totalSupply();
            require(curTotalSupply + _amount[i] >= curTotalSupply); // Check for overflow
            uint256 previousBalanceTo = balanceOf(_user[i]);
            require(previousBalanceTo + _amount[i] >= previousBalanceTo); // Check for overflow
            updateValueAtNow(totalSupplyHistory, curTotalSupply + _amount[i], global_checkpoint_interval);
            updateValueAtNow(balances[_user[i]], previousBalanceTo + _amount[i], checkpoint_interval);

            if ( !IsAddressSeen[_user[i]] ){
                _addresses.push(_user[i]);
                IsAddressSeen[_user[i]] = true;
            }   
            emit Mint(_user[i], _amount[i]);
        }
        return true;
    }

    // @notice Burns `_amount` reputation from `_owner`
    // @param _user The address that will lose the reputation
    // @param _amount The quantity of reputation to burn
    // @return True if the reputation are burned correctly
    function burn(address _user, uint256 _amount) public onlyOwner returns (bool) {
        uint256 curTotalSupply = totalSupply();
        uint256 amountBurned = _amount;
        uint256 previousBalanceFrom = balanceOf(_user);
        if (previousBalanceFrom < amountBurned) {
            amountBurned = previousBalanceFrom;
        }
        updateValueAtNow(totalSupplyHistory, curTotalSupply - amountBurned, global_checkpoint_interval);
        updateValueAtNow(balances[_user], previousBalanceFrom - amountBurned, checkpoint_interval);
        emit Burn(_user, amountBurned);
        return true;
    }

    // @dev This function makes it easy to get the total number of reputation
    // @return The total number of reputation
    function totalSupply() public view returns (uint256) {
        return totalSupplyAt(block.number);
    }

    ////////////////
    // Query balance and totalSupply in History
    ////////////////
    /**
     * @dev return the reputation amount of a given owner
     * @param _owner an address of the owner which we want to get his reputation
     */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balanceOfAt(_owner, block.number);
    }

    // @notice Total amount of reputation at a specific `_blockNumber`.
    // @param _blockNumber The block number when the totalSupply is queried
    // @return The total amount of reputation at `_blockNumber`
    function totalSupplyAt(uint256 _blockNumber) public view returns (uint256) {
        if ((totalSupplyHistory.length == 0) || (totalSupplyHistory[0].fromBlock > _blockNumber)) {
            return 0;
            // This will return the expected totalSupply during normal situations
        } else {
            return getValueAt(totalSupplyHistory, _blockNumber);
        }
    }

    // @dev Queries the balance of `_owner` at a specific `_blockNumber`
    // @param _owner The address from which the balance will be retrieved
    // @param _blockNumber The block number when the balance is queried
    // @return The balance at `_blockNumber`
    function balanceOfAt(address _owner, uint256 _blockNumber) public view returns (uint256) {
        if ((balances[_owner].length == 0) || (balances[_owner][0].fromBlock > _blockNumber)) {
            return 0;
            // This will return the expected balance during normal situations
        } else {
            return getValueAt(balances[_owner], _blockNumber);
        }
    }

    ////////////////
    // Internal helper functions to query and set a value in a snapshot array
    ////////////////

    // @dev `getValueAt` retrieves the number of reputation at a given block number
    // @param checkpoints The history of values being queried
    // @param _block The block number to retrieve the value at
    // @return The number of reputation being queried
    function getValueAt(Checkpoint[] storage checkpoints, uint256 _block) internal view returns (uint256) {
        if (checkpoints.length == 0) {
            return 0;
        }

        // Shortcut for the actual value
        if (_block >= checkpoints[checkpoints.length - 1].fromBlock) {
            return checkpoints[checkpoints.length - 1].value;
        }
        if (_block < checkpoints[0].fromBlock) {
            return 0;
        }

        // Binary search of the value in the array
        uint256 min = 0;
        uint256 max = checkpoints.length - 1;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (checkpoints[mid].fromBlock <= _block) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return checkpoints[min].value;
    }
    
    // @dev `updateValueAtNow` used to update the `balances` map and the
    //  `totalSupplyHistory`
    // @param checkpoints The history of data being updated
    // @param _value The new number of reputation
    function updateValueAtNow(Checkpoint[] storage checkpoints, uint256 _value, uint256 checkpoint_interval_) internal {
        require(uint128(_value) == _value); //check value is in the 128 bits bounderies
        // Important: Do not add new value everytime there is a new block (storage consideration), 
        // Add only every "checkpoint_interval_" block, at most.
        if ( (checkpoints.length == 0) 
            || ( block.number > checkpoint_interval_ )
            && ( checkpoints[checkpoints.length - 1].fromBlock < (block.number - checkpoint_interval_) )) {
            Checkpoint memory newCheckPoint; // = checkpoints[checkpoints.length++];
            newCheckPoint.fromBlock = uint128(block.number);
            newCheckPoint.value = uint128(_value);
            checkpoints.push(newCheckPoint);
        } else {
            Checkpoint storage oldCheckPoint = checkpoints[checkpoints.length - 1];
            oldCheckPoint.value = uint128(_value);
        }
    }

}
