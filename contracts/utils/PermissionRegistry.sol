// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title PermissionRegistry.
 * @dev A registry of smart contracts functions and ERC20 transfers that are allowed to be called between contracts.
 * A time delay in seconds over the permissions can be set form any contract, this delay would be added to any new
 * permissions sent by that address.
 * The PermissionRegistry owner (if there is an owner and owner address is not 0x0) can overwrite/set any permission.
 * The registry allows setting "wildcard" permissions for recipients and functions, this means that permissions like
 * this contract can call any contract, this contract can call this function to any contract or this contract call
 * call any function in this contract can be set.
 * The smart contracts permissions are stored using the asset 0x0 and stores the `from` address, `to` address,
 *   `value` uint256 and `fromTime` uint256, if `fromTime` is zero it means the function is not allowed.
 * The ERC20 transfer permissions are stored using the asset of the ERC20 and stores the `from` address, `to` address,
 *   `value` uint256 and `fromTime` uint256, if `fromTime` is zero it means the function is not allowed.
 * The registry also allows the contracts to keep track on how much value was transferred for every asset in the actual
 * block, it adds the value transferred in all permissions used, this means that if a wildcard value limit is set and
 * a function limit is set it will add the value transferred in both of them.
 */

contract PermissionRegistry is OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    mapping(address => uint256) public permissionDelay;
    address public constant ANY_ADDRESS = address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa);
    bytes4 public constant ANY_SIGNATURE = bytes4(0xaaaaaaaa);

    event PermissionSet(
        address asset,
        address from,
        address to,
        bytes4 functionSignature,
        uint256 fromTime,
        uint256 value
    );

    struct Permission {
        uint256 valueTransferred;
        uint256 valueTransferedOnBlock;
        uint256 valueAllowed;
        uint256 fromTime;
        bool isSet;
    }

    // asset address => from address => to address => function call signature allowed => Permission
    mapping(address => mapping(address => mapping(address => mapping(bytes4 => Permission)))) public permissions;

    Permission emptyPermission = Permission(0, 0, 0, 0, false);

    /**
     * @dev initializer
     */
    function initialize() public initializer {
        __Ownable_init();
    }

    /**
     * @dev Set the time delay for a call to show as allowed
     * @param _timeDelay The amount of time that has to pass after permission addition to allow execution
     */
    function setPermissionDelay(uint256 _timeDelay) public {
        permissionDelay[msg.sender] = _timeDelay;
    }

    // TO DO: Add removePermission function that will set the value isSet in the permissions to false and trigger PermissionRemoved event

    /**
     * @dev Sets the time from which the function can be executed from a contract to another a with which value.
     * @param asset The asset to be used for the permission address(0) for ETH and other address for ERC20
     * @param from The address that will execute the call
     * @param to The address that will be called
     * @param functionSignature The signature of the function to be executed
     * @param valueAllowed The amount of value allowed of the asset to be sent
     * @param allowed If the function is allowed or not.
     */
    function setPermission(
        address asset,
        address from,
        address to,
        bytes4 functionSignature,
        uint256 valueAllowed,
        bool allowed
    ) public {
        if (msg.sender != owner()) {
            require(from == msg.sender, "PermissionRegistry: Only owner can specify from value");
        }
        require(to != address(this), "PermissionRegistry: Cant set permissions to PermissionRegistry");
        if (allowed) {
            permissions[asset][from][to][functionSignature].fromTime = block.timestamp.add(permissionDelay[from]);
            permissions[asset][from][to][functionSignature].valueAllowed = valueAllowed;
        } else {
            permissions[asset][from][to][functionSignature].fromTime = 0;
            permissions[asset][from][to][functionSignature].valueAllowed = 0;
        }
        permissions[asset][from][to][functionSignature].isSet = true;
        emit PermissionSet(
            asset,
            from,
            to,
            functionSignature,
            permissions[asset][from][to][functionSignature].fromTime,
            permissions[asset][from][to][functionSignature].valueAllowed
        );
    }

    /**
     * @dev Get the time delay to be used for an address
     * @param fromAddress The address that will set the permission
     */
    function getPermissionDelay(address fromAddress) public view returns (uint256) {
        return permissionDelay[fromAddress];
    }

    /**
     * @dev Gets the time from which the function can be executed from a contract to another and with which value.
     * In case of now being allowed to do the call it returns zero in both values
     * @param asset The asset to be used for the permission address(0) for ETH and other address for ERC20
     * @param from The address from which the call will be executed
     * @param to The address that will be called
     * @param functionSignature The signature of the function to be executed
     */
    function getPermission(
        address asset,
        address from,
        address to,
        bytes4 functionSignature
    ) public view returns (uint256 valueAllowed, uint256 fromTime) {
        Permission memory permission;

        // If the asset is an ERC20 token check the value allowed to be transferred
        if (asset != address(0)) {
            // Check if there is a value allowed specifically to the `to` address
            if (permissions[asset][from][to][ANY_SIGNATURE].isSet) {
                permission = permissions[asset][from][to][ANY_SIGNATURE];
            }
            // Check if there is a value allowed to any address
            else if (permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE].isSet) {
                permission = permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE];
            }

            // If the asset is ETH check if there is an allowance to any address and function signature
        } else {
            // Check is there an allowance to the implementation address with the function signature
            if (permissions[asset][from][to][functionSignature].isSet) {
                permission = permissions[asset][from][to][functionSignature];
            }
            // Check is there an allowance to the implementation address for any function signature
            else if (permissions[asset][from][to][ANY_SIGNATURE].isSet) {
                permission = permissions[asset][from][to][ANY_SIGNATURE];
            }
            // Check if there is there is an allowance to any address with the function signature
            else if (permissions[asset][from][ANY_ADDRESS][functionSignature].isSet) {
                permission = permissions[asset][from][ANY_ADDRESS][functionSignature];
            }
            // Check if there is there is an allowance to any address and any function
            else if (permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE].isSet) {
                permission = permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE];
            }
        }
        return (permission.valueAllowed, permission.fromTime);
    }

    /**
     * @dev Sets the value transferred in a permission on the actual block and checks the allowed timestamp.
     *      It also checks that the value does not go over the permission other global limits.
     * @param asset The asset to be used for the permission address(0) for ETH and other address for ERC20
     * @param from The address from which the call will be executed
     * @param to The address that will be called
     * @param functionSignature The signature of the function to be executed
     * @param valueTransferred The value to be transferred
     */
    function setPermissionUsed(
        address asset,
        address from,
        address to,
        bytes4 functionSignature,
        uint256 valueTransferred
    ) public {
        uint256 fromTime = 0;

        // If the asset is an ERC20 token check the value allowed to be transferred, no signature used
        if (asset != address(0)) {
            // Check if there is a value allowed to any address
            if (permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE].isSet) {
                fromTime = permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE].fromTime;
                _setValueTransferred(permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE], valueTransferred);
            }
            // Check if there is a value allowed specifically to the `to` address
            if (permissions[asset][from][to][ANY_SIGNATURE].isSet) {
                fromTime = permissions[asset][from][to][ANY_SIGNATURE].fromTime;
                _setValueTransferred(permissions[asset][from][to][ANY_SIGNATURE], valueTransferred);
            }

            // If the asset is ETH check if there is an allowance to any address and function signature
        } else {
            // Check if there is there is an allowance to any address and any function
            if (permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE].isSet) {
                fromTime = permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE].fromTime;
                _setValueTransferred(permissions[asset][from][ANY_ADDRESS][ANY_SIGNATURE], valueTransferred);
            }
            // Check if there is there is an allowance to any address with the function signature
            if (permissions[asset][from][ANY_ADDRESS][functionSignature].isSet) {
                fromTime = permissions[asset][from][ANY_ADDRESS][functionSignature].fromTime;
                _setValueTransferred(permissions[asset][from][ANY_ADDRESS][functionSignature], valueTransferred);
            }
            // Check is there an allowance to the implementation address for any function signature
            if (permissions[asset][from][to][ANY_SIGNATURE].isSet) {
                fromTime = permissions[asset][from][to][ANY_SIGNATURE].fromTime;
                _setValueTransferred(permissions[asset][from][to][ANY_SIGNATURE], valueTransferred);
            }
            // Check is there an allowance to the implementation address with the function signature
            if (permissions[asset][from][to][functionSignature].isSet) {
                fromTime = permissions[asset][from][to][functionSignature].fromTime;
                _setValueTransferred(permissions[asset][from][to][functionSignature], valueTransferred);
            }
        }
        require(fromTime > 0 && fromTime < block.timestamp, "PermissionRegistry: Call not allowed");
    }

    /**
     * @dev Sets the value transferred in a a permission on the actual block.
     * @param permission The permission to add the value transferred
     * @param valueTransferred The value to be transferred
     */
    function _setValueTransferred(Permission storage permission, uint256 valueTransferred) internal {
        if (permission.valueTransferedOnBlock < block.number) {
            permission.valueTransferedOnBlock = block.number;
            permission.valueTransferred = valueTransferred;
        } else {
            permission.valueTransferred = permission.valueTransferred.add(valueTransferred);
        }
        require(permission.valueTransferred <= permission.valueAllowed, "PermissionRegistry: Value limit reached");
    }

    /**
     * @dev Gets the time from which the function can be executed from a contract to another.
     * In case of now being allowed to do the call it returns zero in both values
     * @param asset The asset to be used for the permission address(0) for ETH and other address for ERC20
     * @param from The address from which the call will be executed
     * @param to The address that will be called
     * @param functionSignature The signature of the function to be executed
     */
    function getPermissionTime(
        address asset,
        address from,
        address to,
        bytes4 functionSignature
    ) public view returns (uint256) {
        (, uint256 fromTime) = getPermission(asset, from, to, functionSignature);
        return fromTime;
    }

    /**
     * @dev Gets the value allowed from which the function can be executed from a contract to another.
     * In case of now being allowed to do the call it returns zero in both values
     * @param asset The asset to be used for the permission address(0) for ETH and other address for ERC20
     * @param from The address from which the call will be executed
     * @param to The address that will be called
     * @param functionSignature The signature of the function to be executed
     */
    function getPermissionValue(
        address asset,
        address from,
        address to,
        bytes4 functionSignature
    ) public view returns (uint256) {
        (uint256 valueAllowed, ) = getPermission(asset, from, to, functionSignature);
        return valueAllowed;
    }
}
