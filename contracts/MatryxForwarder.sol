pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

contract MatryxForwarder {
    uint256 version;
    address proxy;

    constructor(uint256 _version, address _proxy) public {
        version = _version;
        proxy = _proxy;
    }

    /// @dev
    /// Gets the address of the current version of the platform and forwards
    /// the received calldata to this address. Injects msg.sender at the front
    /// so Platform and libraries can know calling address
    function () public {
        assembly {
            let ptr := mload(0x40)
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let platform := 0x4d6174727978506c6174666f726d000000000000000000000000000000000000

            // prepare for lookup platform from MPC
            mstore(ptr, mul(0xc53cfd9a, offset))                                // getContract(uint256,bytes32)
            mstore(add(ptr, 0x04), sload(version_slot))                         // arg 0 - version of this forwarder
            mstore(add(ptr, 0x24), platform)                                    // arg 1 - 'MatryxPlatform'

            // call getContract to get MatryxPlatform from MPC
            let res := call(gas, sload(proxy_slot), 0, ptr, 0x44, 0, 0x20)      // call MatryxProxy.getContract
            if iszero(res) { revert(0, 0) }                                     // safety check
            platform := mload(0)                                                // load platform address

            // forward method to MatryxPlatform, injecting msg.sender
            calldatacopy(ptr, 0, 0x04)                                          // copy signature
            mstore(add(ptr, 0x04), caller)                                      // inject msg.sender
            calldatacopy(add(ptr, 0x24), 0x04, sub(calldatasize, 0x04))         // copy calldata for forwarding
            res := call(gas, platform, 0, ptr, add(calldatasize, 0x20), 0, 0)   // forward method to MatryxPlatform
            if iszero(res) { revert(0, 0) }                                     // safety check

            // forward returndata to caller
            returndatacopy(ptr, 0, returndatasize)                              // copy returndata into ptr
            return(ptr, returndatasize)                                         // return returndata from forwarded call
        }
    }
}
