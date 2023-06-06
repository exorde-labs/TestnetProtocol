// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ConfigRegistry is Ownable {
    mapping(bytes32 => string) internal ConfigFiles;

    // ------------------------------------------------------------------------------------------

    event ConfigUpdated(string indexed account);

    /**
    @dev Initializer. Can only be called once.
    */
    constructor() {
        string memory x = "db_hash";
        bytes32 key = keccak256(bytes(x));
        ConfigFiles[key] = "Qmc2tw8ZwERMRmyGU1cywPDsMLkQvkNEwRuECUHnUucLnh";
        x = "lang_detector_hash";
        key = keccak256(bytes(x));
        ConfigFiles[key] = "Qmbxy6YMd1HNDoKDdGTAKYdVBuUGUkA17aQVYdtHJv6fzd";
        x = "censoring_detector_hash";
        key = keccak256(bytes(x));
        ConfigFiles[key] = "QmbZzVcCwfhK4jYqUWR7yYFiT2YcRQ67yXHoXt7jefZjrF";
        x = "toxic_detector_hash";
        key = keccak256(bytes(x));
        ConfigFiles[key] = "QmYdVLenJEc48at6Y7zYbw8cLLLPddjGptezzbDkcctdXv";
        x = "fake_detector_hash";
        key = keccak256(bytes(x));
        ConfigFiles[key] = "QmQ4ocH6PNg5AWioDbWJQyvoZWh8VsdCjK1KCyuFjMTUdc";
        x = "categ_detector_hash";
        key = keccak256(bytes(x));
        ConfigFiles[key] = "QmNU4a4sy51PH9WntRQsVvmdVFq7jhwAnGsYL2wKpSFCCT";
        x = "languagesListHash";
        key = keccak256(bytes(x));
        ConfigFiles[key] = "QmQK6M7pum6W2ZRLdhgzEw7vH8GYMmvwR3aX3hFkMXWrus";
        x = "chineseDictHash";
        key = keccak256(bytes(x));
        ConfigFiles[key] = "QmPY8zU6xzwvjomzN5AkVfTa5zZp2RkXg2eM34vPECqotY";
        x = "japaneseDictHash";
        key = keccak256(bytes(x));
        ConfigFiles[key] = "QmfUzRtqVL9tqG11DpbJVBNoKjxQMyVuqv2uv2pinzucT6";
    }

    // ------------------------------------------------------------------------------------------

    function add(
        string calldata key,
        string calldata value,
        bool overwrite
    ) public onlyOwner returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(key));
        // overwrite existing entries only if the overwrite flag is set
        // or if a lookup returns length 0 at that location.
        if (overwrite || bytes(ConfigFiles[hash]).length == 0) {
            ConfigFiles[hash] = value;
            return true;
        }
        return false;
    }

    function addByHash(
        bytes32 hash,
        string calldata value,
        bool overwrite
    ) public onlyOwner returns (bool) {
        if (overwrite || bytes(ConfigFiles[hash]).length == 0) {
            ConfigFiles[hash] = value;
            return true;
        }
        return false;
    }

    function get(string calldata key) public view returns (string memory) {
        bytes32 hash = keccak256(abi.encodePacked(key));
        return ConfigFiles[hash];
    }

    function getHash(string calldata key) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(key));
    }
}
