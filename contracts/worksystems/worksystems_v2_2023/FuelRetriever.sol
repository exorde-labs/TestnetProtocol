// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "interfaces/IParametersManager.sol"; // Import the interface used for getting sFuel system address

abstract contract FuelRetriever {
    IParametersManager public Parameters;

    constructor(address _parametersManager) {
        require(_parametersManager != address(0), "Parameters Manager address cannot be zero.");
        Parameters = IParametersManager(_parametersManager);
    }

    /**
     * @notice Refill the msg.sender with sFuel. Skale gasless "gas station network" equivalent
     */
    function _retrieveSFuel() internal {
        require(address(Parameters) != address(0), "Parameters Manager must be set.");
        address sFuelAddress = Parameters.getsFuelSystem();
        require(sFuelAddress != address(0), "sFuel: null Address Not Valid");

        // Attempting the retrieveSFuel call
        (bool success, ) = sFuelAddress.call(
            abi.encodeWithSignature("retrieveSFuel(address)", msg.sender)
        );
        require(success, "receiver rejected _retrieveSFuel call");
    }
}
