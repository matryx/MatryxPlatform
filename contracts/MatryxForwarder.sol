pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "./MatryxSystem.sol";

contract MatryxForwarder {
    struct Info {
        uint256 version;
        address system;
    }

    Info info;

    constructor(uint256 _version, address _system) public {
        info.version = _version;
        info.system = _system;
    }

    /// @dev
    /// Gets the address of the current version of Platform and forwards the
    /// received calldata to this address. Injects msg.sender at the front so
    /// Platform and libraries can know calling address
    function () external {
        uint256 version = info.version;
        address platform = IMatryxSystem(info.system).getContract(version, bytes32("MatryxPlatform"));

        assembly {
            let ptr := mload(0x40)
            let res

            // forward method to MatryxPlatform, injecting msg.sender
            if lt(calldatasize, 0x04) { revert(0, 0) }                          // prevent underflow
            calldatacopy(ptr, 0, 0x04)                                          // copy selector
            mstore(add(ptr, 0x04), caller)                                      // inject msg.sender
            mstore(add(ptr, 0x24), version)                                     // inject version
            calldatacopy(add(ptr, 0x44), 0x04, sub(calldatasize, 0x04))         // copy calldata for forwarding
            res := call(gas, platform, 0, ptr, add(calldatasize, 0x40), 0, 0)   // forward method to MatryxPlatform
            returndatacopy(ptr, 0, returndatasize)                              // copy returndata into ptr

            if iszero(res) { revert(ptr, returndatasize) }                      // safety check
            return(ptr, returndatasize)                                         // return returndata from forwarded call
        }
    }
}
