// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.8;

import "./RandomAllocator.sol";

contract RandomSubsets is RandomAllocator {
    
    // Function to generate K random unique subsets of length L without intersections, from a range of 0 to N
    function generateRandomSubsets(uint128 K, uint128 N, uint32 L) public view returns (uint256[][] memory) {
            // Check if K, L > 0 and if K * L <= N, to ensure it's possible to generate non-overlapping subsets
        require(K > 0 && L > 0 && K * L <= N, "Input is not valid for generating non-overlapping subsets");

        // Initialize the output array of arrays
        uint256[][] memory subsets = new uint256[][](K);

        // Initialize the highest index
        uint128 highestIndex = 0;

        // Generate K base indices and create subsets
        for (uint128 i = 0; i < K; i++) {
            // Check if there's enough room left to generate the remaining subsets
            uint128 remainingSubsets = K - i - 1;
            uint128 roomLeft = N - L * (remainingSubsets + 1) + 1;

            // If not enough room, update the highestIndex
            if (highestIndex > roomLeft) {
                highestIndex = roomLeft;
            }

            // Calculate the remaining range for generating integers
            uint128 remainingRange = N - L + 1 - highestIndex;

            // If the remaining range is not greater than 0, set the highest index to the proper value
            if (remainingRange <= 0) {
                highestIndex = N - L + 1;
                remainingRange = 1;
            }

            // Generate a random base index in the range [highestIndex, N - L + 1)
            uint256 baseIndex = generateIntegers(1, remainingRange)[0] + highestIndex;

            // Create the subset using the generated base index
            subsets[i] = new uint256[](2);
            subsets[i][0] = baseIndex;
            subsets[i][1] = baseIndex + L - 1;

            // Update the highest index
            highestIndex = uint128(subsets[i][1]) + 1;
        }

        // Sort the subsets based on the starting index to minimize the possibility of overlaps
        for (uint128 i = 0; i < K - 1; i++) {
            for (uint128 j = 0; j < K - i - 1; j++) {
                if (subsets[j][0] > subsets[j + 1][0]) {
                    uint256[] memory temp = subsets[j];
                    subsets[j] = subsets[j + 1];
                    subsets[j + 1] = temp;
                }
            }
        }

        return subsets;
    }
}
