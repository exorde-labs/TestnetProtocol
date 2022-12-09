// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

/**
* @notice RandomAllocator seeds it randomness from getSeed() a native SKALE RNG Endpoint
*         It is sufficient that it rotates every block
*         The work allocation must be as random as possible, over time, statistically
*         We could use Oracles to improve randomness, but it is not relevant.
*/
contract RandomAllocator {

    uint256 constant EXTRA_ITERATIONS_  = 20;    
    uint256 constant public MAX_RANGE = 100; // must be low (< 200)

    /**
     * @notice Get Native RNG Seed endpoint from SKALE chain
     * @return addr bytes32 seed output
     */
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
     * @notice get Random Integer out of native seed
     * @return randomly generated integer
     */
    function getRandom() public view returns (uint256) {
        uint256 r = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp +
                        uint256(keccak256(abi.encodePacked(getSeed()))) +
                        block.difficulty +
                        ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp))
                )
            )
        );
        return r;
    }

    /**
     * @notice generate _k integers from 0 to N
     * @param _k integer (should be low)
     * @param N_range integer Should be low (<100)
     * @return randomly generated integers array of size _k
     */
    function generateIntegers(uint256 _k, uint256 N_range) public view returns (uint256[] memory) {
        require(N_range > 0 && _k <= N_range && _k >= 1, "k or N are not OK for RNG");
        require(N_range <= MAX_RANGE, "N_range is above MAX_RANGE (by default 100)");
        uint256 seed = uint256(keccak256(abi.encodePacked(uint256(keccak256(abi.encodePacked(getRandom()))))));
        uint256[] memory integers = new uint256[](_k);

        uint256 c = 0;
        uint256 nb_iterations = _k + EXTRA_ITERATIONS_;

                // This loop can be considered O(1) because nb_iterations is always lower than MAX_RANGE which is <= 100

        for (uint256 l = 0; l < nb_iterations; l++) {
            if (N_range > (uint256(keccak256(abi.encodePacked(seed + l * l))))){
                // if N_range is larger than the value on the right, 
                // then the modulo below will just return the first hash, which leads to weak randomness
                // So in that case we continue: this case should be very rare
                continue;
            }
            uint256 randNumber = (uint256(keccak256(abi.encodePacked(seed + l * l)))) % N_range;
            bool already_exists = false;
            // check if already generated
            for (uint256 i = 0; i < c; i++) {
                if (integers[i] == randNumber) {
                    already_exists = true;
                    break;
                }
            }
            if (!already_exists) {
                integers[c] = randNumber;
                c = c + 1;
            }
            if (c >= _k) {
                break;
            }
        }

        if (c < _k) {
            for (uint256 k = 0; k < N_range; k++) {
                uint256 newNumber = k;
                bool already_exists = false;
                for (uint256 i = 0; i < c; i++) {
                    if (integers[i] == newNumber) {
                        already_exists = true;
                        break;
                    }
                }
                if (!already_exists) {
                    integers[c] = newNumber;
                    c = c + 1;
                }
                if (c >= _k) {
                    break;
                }
            }
        }
        require(c == _k, "RNG insufficient");
        return integers;
    }

    /**
     * @dev Select k unique integer out of the N range (0,1,2,...,N)
     * @param k integer
     * @param N integer
     * @return array of selected random integers
     */
    function random_selection(uint256 k, uint256 N) public view returns (uint256[] memory) {
        uint256[] memory resultArray = generateIntegers(k, N);
        return resultArray;
    }
}
