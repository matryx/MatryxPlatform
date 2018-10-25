pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./IMatryxToken.sol";

contract MatryxTrinity {
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
    function () public {
        assembly {
            let ptr := mload(0x40)
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let platform := 0x4d6174727978506c6174666f726d000000000000000000000000000000000000
            let version := sload(info_slot)
            let system := sload(add(info_slot, 1))

            // prepare for lookup platform from MSC
            mstore(ptr, mul(0xc53cfd9a, offset))                                // getContract(uint256,bytes32)
            mstore(add(ptr, 0x04), version)                                     // arg 0 - version of this forwarder
            mstore(add(ptr, 0x24), platform)                                    // arg 1 - 'MatryxPlatform'

            // call getContract to get MatryxPlatform from MSC
            let res := call(gas, system, 0, ptr, 0x44, 0, 0x20)                 // call MatryxSystem.getContract
            if iszero(res) { revert(0, 0) }                                     // safety check
            platform := mload(0)                                                // load platform address

            calldatacopy(ptr, 0, 0x04)                                          // copy signature
            let sig := div(mload(ptr), offset)                                  // shrink signature to 4 relevant bytes

            if or(eq(sig, 0x23b872dd), eq(sig, 0xa5f2a152)) {                   // if transferFrom or transferTo
                if iszero(eq(caller, platform)) { revert(0, 0) }                // require caller is Platform
                calldatacopy(ptr, 0, calldatasize)                              // copy calldata for forwarding
                res := delegatecall(gas, LibTrinity, ptr, calldatasize, 0, 0)   // forward method to LibTrinity
                if iszero(res) { revert(0, 0) }                                 // safety check
                return(0, 0)                                                    // return early (skip rest)
            }

            // forward method to MatryxPlatform, injecting msg.sender
            mstore(add(ptr, 0x04), caller)                                      // inject msg.sender
            mstore(add(ptr, 0x24), version)                                     // inject version
            calldatacopy(add(ptr, 0x44), 0x04, sub(calldatasize, 0x04))         // copy calldata for forwarding
            res := call(gas, platform, 0, ptr, add(calldatasize, 0x40), 0, 0)   // forward method to MatryxPlatform
            if iszero(res) { revert(0, 0) }                                     // safety check

            // forward returndata to caller
            returndatacopy(ptr, 0, returndatasize)                              // copy returndata into ptr
            return(ptr, returndatasize)                                         // return returndata from forwarded call
        }
    }
}

library LibTrinity {
    /// @dev Transfers MTX from sender to MatryxTrinity
    /// @param token   Token address
    /// @param sender  Sender of tokens
    /// @param amount  Amount of tokens
    function transferFrom(address token, address sender, uint256 amount) public {
        require(IMatryxToken(token).transferFrom(sender, this, amount), "Transfer failed");
    }

    /// @dev Transfers MTX from MatryxTrinity to recipient
    /// @param token      Token address
    /// @param recipient  Recipient of tokens
    /// @param amount     Amount of tokens
    function transferTo(address token, address recipient, uint256 amount) public {
        require(IMatryxToken(token).transfer(recipient, amount), "Transfer failed");
    }
}
