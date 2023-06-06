// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

/**
 * @title RandomAllocator
 * @dev The RandomAllocator contract is a robust, precise, and comprehensive
 * random number generator, designed for use with downstream contracts that
 * require reliable random number generation over extended periods of time.
 * This contract utilizes the SKALE RNG (Random Number Generator) for its
 * randomness source, which is refreshed every few seconds due to BLS signature
 * rotation by SKALE validators. However, this contract is intended for use
 * with downstream contracts operating at a lower frequency, thus ensuring
 * robust randomness over the course of hours.
 *
 * The contract provides the following functionality:
 * 1. Get Native RNG Seed: This function retrieves the native RNG seed from
 *    the SKALE chain, allowing the contract to access a reliable source of
 *    randomness.
 * 2. Generate Random Integer: This function uses the native seed to generate
 *    a single random integer.
 * 3. Generate Unique Integers: This function generates a specified number (_k)
 *    of unique integers within a specified range (N_range), ensuring that each
 *    integer is unique within the given range.
 * 4. Random Selection: This function selects a specified number (k) of unique
 *    integers from a given range (N), returning an array containing the
 *    selected random integers.
 *
 * Note: As the SKALE RNG Randomness source is only refreshed every few seconds,
 * it is crucial that downstream contracts work at a lower frequency to ensure
 * statistically robust randomness over time.
 */
contract RandomAllocator {

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
                        uint256(keccak256(abi.encodePacked(getSeed(),block.timestamp)))
                )
            )
        );
        return r;
    }

    /**
     * @notice Generate _k unique integers from 0 to N_range
     * @param _k uint256 (should be low)
     * @param N_range uint256 Should be low (<100)
     * @return randomly generated integers array of size _k
     */
    function generateIntegers(uint256 _k, uint256 N_range) public view returns (uint256[] memory) {
        require(N_range > 0 && _k <= N_range && _k >= 1, "k or N are not OK for RNG");

        // Initialize a seed and create an array to store unique integers
        uint256 seed = uint256(keccak256(abi.encodePacked(uint256(keccak256(abi.encodePacked(getRandom()))))));
        uint256[] memory integers = new uint256[](_k);

        uint256 c = 0; // Counter for unique integers found
        uint256 nb_iterations = _k * 2; // Double the number of iterations to ensure enough unique integers are found

        // Iterate through the random numbers, considering O(1) complexity because nb_iterations is always low
        for (uint256 l = 0; l < nb_iterations; l++) {
            uint256 randNumber = (uint256(keccak256(abi.encodePacked(seed + l * l)))) % N_range;
            bool already_exists = false;

            // Check if the random number is already generated
            for (uint256 i = 0; i < c; i++) {
                if (integers[i] == randNumber) {
                    already_exists = true;
                    break;
                }
            }

            // If the random number is not already generated, add it to the array
            if (!already_exists) {
                integers[c] = randNumber;
                c = c + 1;
            }

            // If we have found _k unique integers, break the loop
            if (c >= _k) {
                break;
            }
        }

        require(c == _k, "RNG insufficient");
        return integers;
    }

    /**
     * @notice Generate _k unique integers from 0 to N_range
     * @param _k uint256 (should be low)
     * @param N_range uint256 Should be low (<100)
     * @param extra_seed an additional randomness input
     * @return randomly generated integers array of size _k
     */
    function generateIntegersWithSeed(uint256 _k, uint256 N_range, uint256 extra_seed) public view returns (uint256[] memory) {
        require(N_range > 0 && _k <= N_range && _k >= 1, "k or N are not OK for RNG");

        // Initialize a seed and create an array to store unique integers
        uint256 seed = uint256(keccak256(abi.encodePacked(uint256(keccak256(abi.encodePacked(getRandom()+extra_seed))))));
        uint256[] memory integers = new uint256[](_k);

        uint256 c = 0; // Counter for unique integers found
        uint256 nb_iterations = _k * 2; // Double the number of iterations to ensure enough unique integers are found

        // Iterate through the random numbers, considering O(1) complexity because nb_iterations is always low
        for (uint256 l = 0; l < nb_iterations; l++) {
            uint256 randNumber = (uint256(keccak256(abi.encodePacked(seed+l*l)))) % N_range;
            bool already_exists = false;

            // Check if the random number is already generated
            for (uint256 i = 0; i < c; i++) {
                if (integers[i] == randNumber) {
                    already_exists = true;
                    break;
                }
            }

            // If the random number is not already generated, add it to the array
            if (!already_exists) {
                integers[c] = randNumber;
                c = c + 1;
            }

            // If we have found _k unique integers, break the loop
            if (c >= _k) {
                break;
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