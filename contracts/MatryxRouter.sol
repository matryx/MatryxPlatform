pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

contract MatryxRouter {
    uint256 version;
    address proxy;

    constructor(uint256 _version, address _proxy) public {
        version = _version;
        proxy = _proxy;
    }

    function () public {
        assembly {
            let ptr := mload(0x40)
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let platform := 0x4d6174727978506c6174666f726d000000000000000000000000000000000000

            // prepare for lookup platform from MPC
            mstore(ptr, mul(0xc53cfd9a, offset))                                // getContract(uint256,bytes32)
            mstore(add(ptr, 0x04), sload(version_slot))                         // arg 0 - version of this router
            mstore(add(ptr, 0x24), platform)                                    // arg 1 - 'MatryxPlatform'

            // call getContract to get MatryxPlatform from MPC
            let res := call(gas, sload(proxy_slot), 0, ptr, 0x44, 0, 0x20)      // call MatryxProxy.getContract
            if iszero(res) { revert(0, 0) }                                     // safety check
            platform := mload(0)                                                // load platform address into memory

            // forward method to MatryxPlatform
            calldatacopy(ptr, 0, calldatasize)                                  // copy calldata for forwarding
            res := call(gas, platform, 0, ptr, calldatasize, 0, 0)              // forward method to MatryxPlatform
            if iszero(res) { revert(0, 0) }                                     // safety check

            // forward returndata to caller
            returndatacopy(ptr, 0, returndatasize)                              // copy returndata into ptr
            return(ptr, returndatasize)                                         // return returndata from forwarded call
        }
    }
}
