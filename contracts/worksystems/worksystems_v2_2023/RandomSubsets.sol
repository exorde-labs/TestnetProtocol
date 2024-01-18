// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./RandomAllocator.sol";

contract RandomSubsets is RandomAllocator {

        /**
    * @dev Generates `K` random unique subsets of varying length between `M` and `L` without intersections, from a range of 0 to `N`.
    * This is an approximative function, that can produce at most `K` subsets, but also can produce less, probabilistically.
    * The function uses a maximum of `maxFailedAttempts` attempts to generate the subsets, and returns an empty array if the attempts fail.
    * 
    * Requirements:
    * - `K`, `L`, `M` and `maxFailedAttempts` must be greater than zero.
    * - `M` must be less than or equal to `L`.
    * - `K * L` must be less than or equal to `N`.
    * 
    * @param K The number of subsets to generate.
    * @param N The maximum value of the range (inclusive) from which to generate the subsets.
    * @param L The maximum length of the subsets to generate.
    * @param M The minimum length of the subsets to generate.
    * @param maxFailedAttempts The maximum number of attempts to generate the subsets before giving up.
    * 
    * @return A two-dimensional array of unsigned integers representing the generated subsets. Each row in the array corresponds to a subset,
    *         and contains two elements: the start index and the end index (inclusive) of the subset. If the function fails to generate `K`
    *         subsets after `maxFailedAttempts`, it returns an empty array.
    */
    function _randomSubsets(uint128 K, uint128 N, uint128 L, uint128 M, uint128 maxFailedAttempts) private view returns (uint128[][] memory) {
        require(K > 0 && L > 0 && M > 0 && M <= L && K * L <= N, "Input is not valid for generating non-overlapping subsets");

        uint128[][] memory subsets = new uint128[][](K);

        uint128 highestIndex = 0;
        uint128 failedAttempts = 0;
        uint128 i = 0;

        // Keep track of the generated base indices using an array
        uint128[] memory generatedIndices = new uint128[](K);

        while (i < K) {
            // Calculate available space and space needed for the remaining subsets
            uint128 availableSpace = N - highestIndex;
            uint128 spaceNeeded = (K - i) * L;

            if (availableSpace < spaceNeeded) {
                // Not enough room left to generate the remaining subsets, increment failed attempts
                failedAttempts++;
                
                // Reset the highestIndex after a failed attempt
                highestIndex = 0;
            } else {
                // Calculate the remaining range for generating integers
                uint128 remainingRange = (N >= L && highestIndex <= N - L + 1) ? N - L + 1 - highestIndex : 1;


                // Check if the base index is already used
                bool indexExists = false;

                uint128 baseIndex = uint128(generateIntegersWithSeed(1, remainingRange, i+failedAttempts )[0] + highestIndex);
                uint128 upper_bound = L - M + 1;
                uint128 newSubsetEnd = baseIndex + M + uint128(generateIntegersWithSeed(1, upper_bound, i + failedAttempts + baseIndex)[0]);

                for (uint128 j = 0; j < i; j++) {
                    if ((generatedIndices[j] == baseIndex) ||
                        (baseIndex > subsets[j][0] && baseIndex < subsets[j][1]) ||
                        (newSubsetEnd > subsets[j][0] && newSubsetEnd < subsets[j][1]) ||
                        (baseIndex <= subsets[j][0] && newSubsetEnd >= subsets[j][1])) {
                        indexExists = true;
                        break;
                    }
                }
                

                if (!indexExists) {                                
                    // Generate random subsets of length between M and L
                    // Create the subset using the generated base index and subset length
                    subsets[i] = new uint128[](2);
                    subsets[i][0] = baseIndex;
                    subsets[i][1] = newSubsetEnd;

                    // Add the generated base index to the array of indices
                    generatedIndices[i] = baseIndex;

                    // Update the highest index
                    highestIndex = uint128(subsets[i][1]) + 1;
                    i++;
                }
                else{                    
                    failedAttempts++;
                }
            }

            // If the number of failed attempts reaches the maximum allowed, stop the loop
            if (failedAttempts >= maxFailedAttempts) {
                break;
            }
        }

        return subsets;
    }

    /**
    @dev Generates K random unique subsets of varying length between M and L without intersections, from a range of 0 to N with a minimum coverage.

    @param K_ The number of subsets to generate.
    @param N_ The maximum range of the subset generation.
    @param coverage The minimum coverage percentage for the subset generation.
    @return An array of K subsets, where each subset is an array of two integers representing the starting and ending points of the subset.

    @notice This function generates a set of non-overlapping subsets with a varying length between M and L.
    It takes the minimum coverage percentage into account to ensure a certain proportion of the range is covered by the subsets.
    It uses the following formulas to calculate the subset length and maximum failed attempts:

            M_ = (N_ * coverage) / (K_ * 100 * 4)
            L_ = M_ * 4
            maxFailedAttempts_ >= (K_ * N_ - K_ * L_ - N_ + L_ + ln[(N_ - L_ + 1 choose K_)] - ln(0.95)) / ln(1 - L_ / N_)
            We assume M = L / 4 (or L = 4M) and that a subset can be between M and 3*M in length on average.

            If the input is not valid for generating non-overlapping subsets, the function will revert.
    */
    function getRandomSubsets(uint128 K_, uint128 N_, uint128 coverage) public view returns (uint128[][] memory) {
        require(coverage > 0 && coverage <= 100, "coverage must be between 1 and 100");
        // Calculate the minimum and maximum subset lengths and the maximum failed attempts based on the input parameters.
        (uint128 M_, uint128 L_, uint128 maxFailedAttempts_) = _getParameters(K_, N_, coverage);
        // Generate the random non-overlapping subsets using the calculated minimum and maximum subset lengths and maximum failed attempts.
        return _randomSubsets(K_, N_, L_, M_, maxFailedAttempts_);
    }

    /**
        @dev This function takes the number of required non-overlapping subsets (K_), the range (N_), and the coverage percentage (coverage) as inputs and returns the lower bound of the subset length (M_), the upper bound of the subset length (L_), and the maximum failed attempts (maxFailedAttempts_) that are needed to generate K_ non-overlapping subsets of unique integers in the range 0 to N_ such that the cumulative length of all subsets covers coverage% of the range. This is an internal function that is used by the public getStandardSubsets function to compute the subset parameters.
        The function uses the formula M_ = (N_ * coverage) / (K_ * 100 * 4) to calculate the lower bound of the subset length and sets the upper bound to L_ = 4 * M_. It then computes the maximum failed attempts using the formula:
    
        maxFailedAttempts_ >= (K_ * N_ - K_ * L_ - N_ + L_ + ln[(N_ - L_ + 1 choose K_)] - ln(1 - 0.99)) / ln(1 - L_ / N_)
        We approximate this to 10.
        The value 0.99 represents the probability of generating a single non-overlapping subset and the formula ensures that all K_ subsets are generated with at least 99% probability. The function returns the calculated values as a tuple.
        @param K_ The number of required non-overlapping subsets.
        @param N_ The range of integers from which to generate the subsets.
        @param coverage The percentage of the range that should be covered by the subsets.
        @return M_ The lower bound of the subset length.
        @return L_ The upper bound of the subset length.
        @return maxFailedAttempts_ The maximum number of failed attempts that should be allowed during the subset generation process.
    */
    function _getParameters(uint128 K_, uint128 N_, uint128 coverage) public pure returns (uint128, uint128, uint128) {
        require(N_ >= 50, "N must be >= 50");
        require(coverage > 0 && coverage <= 100, "P must be between 1 and 100");
        // Calculate the minimum and maximum subset lengths and the maximum failed attempts based on the input parameters.
        uint128 M_ = uint128((N_ * coverage) / (K_ * 100.0 * 2)); // Subset length lower bound
        uint128 L_ = M_ * 4; // Subset length upper bound
        uint128 maxFailedAttempts_ = 10; // Maximum failed attempts
        // Generate the random non-overlapping subsets using the calculated minimum and maximum subset lengths and maximum failed attempts.
        if ( M_ == 0 || L_ == 0 ){
            M_ = N_ / 10 + 1;
            L_ = M_ * 4;
        }
        return (M_, L_, maxFailedAttempts_);
    }

    /**
        @dev Calculates the coverage (percentage) of a set of subsets.
        @param K_ The size of each subset.
        @param N_ The size of the superset.
        @param coverage The coverage array containing the starting and ending indexes of each subset.
        @return A tuple containing the number of non-empty subsets, the length of each subset, the total length of all non-empty subsets, and the coverage percentage of the superset.
    */
    function getCoverage(uint128 K_, uint128 N_, uint128 coverage) public view returns (uint128, uint128[] memory, uint128, uint128) {
        uint128[][] memory subsets = getRandomSubsets(K_, N_, coverage);
        uint128[] memory subset_lengths = new uint128[](subsets.length);
        uint128 cumulative_length;
        uint128 nb_subsets = 0;
        uint128 coverage_percentage = 0;
        for (uint i = 0; i < subsets.length; i++) {
            if (subsets[i].length > 0) { // Check if subset is not empty
                uint128 length = subsets[i][1] - subsets[i][0] + 1;
                subset_lengths[nb_subsets] = length;
                nb_subsets++;
                cumulative_length += length;
            }
        }
        coverage_percentage = cumulative_length * 100 / N_;
        return (nb_subsets, subset_lengths, cumulative_length, coverage_percentage);
    }
}
