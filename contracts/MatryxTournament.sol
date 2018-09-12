pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

contract MatryxTournament {
    uint256 platformVersion;
    address matryxProxyContract;

    constructor(uint256 _platformVersion, address _matryxProxyContract) {
        platformVersion = _platformVersion;
        matryxProxyContract = _matryxProxyContract;
    }

    function () public {
        assembly {
            // prepare for lookup LibTournament from MPC
            let ptr := mload(0x40)
            mstore(ptr, 0xf991d31a)                               // getContractAtVersion(bytes32, address)
            mstore(add(ptr, 0x04), 0x4c6962546f75726e616d656e74)  // LibTournament
            mstore(add(ptr, 0x24), sload(platformVersion_slot))   // Tournament version

            // call getContractAtVersion to get LibTournament from MPC
            let res := call(gas(), sload(matryxProxyContract_slot), 0, ptr, 0x44, 0, 0x20)
            if iszero(res) { revert(0, 0) }
            let LibT := mload(0)

            // forward calldata to LibTournament
            calldatacopy(ptr, 0, calldatasize())
            res := delegatecall(gas(), LibT, ptr, calldatasize(), ptr, 0)
            if iszero(res) { revert(0, 0) }
        }
    }
}
