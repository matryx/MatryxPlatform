pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

contract MatryxRouter {
    uint256 version;
    address proxy;

    constructor(uint256 _version, address _proxy) {
        version = _version;
        proxy = _proxy;
    }

    function () public {
        assembly {
            // prepare for lookup platform from MPC
            let ptr := mload(0x40)
            mstore(ptr, 0xc53cfd9a)                                 // getContract(uint256,bytes32)
            mstore(add(ptr, 0x04), sload(version_slot))             // uint256 _version: version of this router
            mstore(add(ptr, 0x24), 0x4d6174727978506c6174666f726d)  // bytes32 _contractName: 'MatryxPlatform'

            // call getContract to get MatryxPlatform from MPC
            let res := call(gas(), sload(proxy_slot), 0, ptr, 0x44, 0, 0x20)
            if iszero(res) { revert(0, 0) }
            let platform := mload(0)

            calldatacopy(ptr, 0x0, calldatasize)
            res := call(gas, platform, 0, ptr, calldatasize, ptr, 0)
            if iszero(res) { revert(0, 0) }

            let size := returndatasize
            returndatacopy(ptr, ptr, size)
            return(ptr, size)
        }
    }
}
