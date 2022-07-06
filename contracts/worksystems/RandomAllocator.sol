// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract RandomAllocator {

    /**
    @dev Initializer. Can only be called once.
    */
    // constructor() public  {
    //     for(uint256 i=0; i<5; i++){
    //         subsystems_seeds[i] = getRandom() + uint256(keccak256(abi.encodePacked(i)));
    //     }
    // }
    

    function getSeed() public view returns (bytes32 addr) {
        assembly {
            let freemem := mload(0x40)
            let start_addr := add(freemem, 0)
            if iszero(staticcall(gas(), 0x18, 0, 0, start_addr, 32)) {
              invalid()
            }
            addr := mload(freemem)
        }
    }


    /**
     * @dev Return value
     * @return value of 'number'
     */
    function getRandom() public view returns (uint256){
        uint256 r = uint256(keccak256(abi.encodePacked(block.timestamp + uint256(keccak256(abi.encodePacked(getSeed()))) + block.difficulty + ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)))));
        return r;
    }

    /**
     * @dev Return value
     * @return value of 'number'
     */
     function generateIntegers(uint256 _k, uint256 N_range) public view returns (uint256[] memory){
        require(_k >= 0);
        require(N_range > 0);
        

        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp + uint256(keccak256(abi.encodePacked(getSeed())))+ ((uint256(keccak256(abi.encodePacked(block.coinbase))))))));
        // uint256 b = 2531011;
        uint256[] memory integers = new uint256[](_k);

        uint256 c = 0;
        uint256 l = 0;
        while( c < _k ){
            uint256 randNumber = (uint256(keccak256(abi.encodePacked(seed-25100011,l)))) % N_range;
            bool already_exists = false;
            for(uint256 i = 0; i < c ; i++){
                if(integers[i] == randNumber){
                    already_exists = true;
                    break;
                }
            }
            if(!already_exists){
                integers[c] = randNumber;
                // integers[c] = l;
                c = c + 1;
            }
            l = l + 1;
        }

        return integers;
    }


    /**
     * @dev Return value
     * @return value of 'number'
     */
    function shuffle_array_(uint256[] memory _myArray) private view returns(uint256[] memory){
        require(_myArray.length > 0);
        uint256 a = _myArray.length;
        uint256 b = _myArray.length;
        for(uint256 i = 0; i< b ; i++){
            uint256 randNumber =(uint256(keccak256
            (abi.encodePacked(getRandom(),_myArray[i]))) % a)+1;
            uint256 interim = _myArray[randNumber - 1];
            _myArray[randNumber-1]= _myArray[a-1];
            _myArray[a-1] = interim;
            a = a-1;
        }
        uint256[] memory result;
        result = _myArray;
        return result;
    }

    
    /**
     * @dev Return value
     * @return value of 'number'
     */
    function reset_index_array(uint256[] memory _myArray) private pure returns(uint256[] memory){
        uint256 N = _myArray.length;
        for(uint256 i = 0; i<N ; i++){
            _myArray[i] = i;
        }
        uint256[] memory result;
        result = _myArray;
        return result;
    }


    function shuffle_array(uint256 N) public view returns(uint256[] memory){
        require(N > 0);
        uint256[] memory indexArray = new uint256[](N);
        uint256[] memory  array = shuffle_array_(reset_index_array(indexArray));
        uint256[] memory result;
        result = array;
        return result;
    }


    function random_selection(uint256 k, uint256 N) public view returns(uint256[] memory){
        require(   N > 0 && k <= N && k >= 1 ,"k or N are not OK during random selection" );
        uint256[] memory indexArray = new uint256[](N);
        uint256[] memory resultArray = new uint256[](k);
        uint256[] memory array = shuffle_array_(reset_index_array(indexArray));
        for(uint256 i = 0; i < k; i++){
            resultArray[i] = array[i];
        }
        return resultArray;
    }
}