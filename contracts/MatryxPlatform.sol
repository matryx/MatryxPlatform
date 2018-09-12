pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";

contract MatryxPlatform {
    address proxy;
    uint256 version;

    uint256[] arr;

    mapping(address=>bytes32) contractToLibraryName;                           // contract address => 'Lib_____' (hex)

    constructor(address _proxy, uint256 _version) public {
        proxy = _proxy;
        version = _version;
        arr.push(3);
        arr.push(4);
        arr.push(3);
    }

    function () public {
        assembly {
            // constants
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let libPlatform := 0x4c6962506c6174666f726d000000000000000000000000000000000000000000

            let ptr := mload(0x40)                                              // scratch space for calldata
            let proxy := sload(proxy_slot)                                      // load proxy address
            let version := sload(version_slot)                                  // load version number

            // get library name for contract
            mstore(0, caller)                                                   // key - caller
            mstore(0x20, contractToLibraryName_slot)                            // map - contract library name
            let libName := sload(keccak256(0, 0x40))                            // get library name for contract
            if iszero(libName) { libName := libPlatform }                       // default to LibPlatform

            // call proxy and get library address
            mstore(ptr, mul(0xc53cfd9a, offset))                                // getContract(uint256,bytes32)
            mstore(add(ptr, 0x04), version)                                     // arg 0 - version
            mstore(add(ptr, 0x24), libName)                                     // arg 1 - library name
            let res := call(gas, proxy, 0, ptr, 0x44, 0, 0x20)                  // call proxy.getContract
            if iszero(res) { revert(0, 0) }                                     // safety check
            let libAddress := mload(0)                                          // store libAddress from response

            // get fnData from proxy
            mstore(ptr, mul(0x3b15aabf, offset))                                // getContractMethod(uint256,bytes32,bytes32)
            mstore(add(ptr, 0x04), version)                                     // arg 0 - version
            mstore(add(ptr, 0x24), libName)                                     // arg 1 - library name
            calldatacopy(add(ptr, 0x44), 0, 0x04)                               // arg 2 - fn selector
            res := call(gas, proxy, 0, ptr, 0x64, ptr, 0)                       // call proxy.getContractMethod
            if iszero(res) { revert(0, 0) }                                     // safety check

            returndatacopy(ptr, 0, returndatasize)                              // copy fnData into ptr
            let ret := add(ptr, mload(ptr))                                     // ret is pointer to start of fnData

            let m_injParams := add(ret, mload(add(ret, 0x20)))                  // mem loc injected params
            let injParams_len := mload(m_injParams)                             // num injected params
            m_injParams := add(m_injParams, 0x20)                               // first injected param

            let m_dynParams := add(ret, mload(add(ret, 0x40)))                  // memory location of start of dynamic params
            let dynParams_len := mload(m_dynParams)                             // num dynamic params
            m_dynParams := add(m_dynParams, 0x20)                               // first dynamic param

            // forward calldata to LibTournament
            ptr := add(ptr, returndatasize)                                     // shift ptr to new scratch space
            mstore(ptr, mload(ret))                                             // forward call with modified selector

            let ptr2 := add(ptr, 0x04)                                          // copy of ptr for keeping track of injected params
            for { let i := 0 } lt(i, injParams_len) { i := add(i, 1) } {        // loop through injected params and insert
                let injParam := mload(add(m_injParams, mul(i, 0x20)))           // get injected param slot
                mstore(ptr2, injParam)                                          // store injected params into next slot
                ptr2 := add(ptr2, 0x20)                                         // shift ptr2
            }

            calldatacopy(ptr2, 0x04, sub(calldatasize, 0x04))                   // copy calldata after injected data storage

            // update dynamic params location
            for { let i := 0 } lt(i, dynParams_len) { i := add(i, 1) } {
                let idx := mload(add(m_dynParams, mul(i, 0x20)))                // get dynParam index in parameters
                let loc := add(ptr2, mul(idx, 0x20))                            // get location in memory of dynParam
                mstore(loc, add(mload(loc), mul(injParams_len, 0x20)))          // shift dynParam location by num injected
            }

            let size := add(calldatasize, mul(injParams_len, 0x20))             // calculate size of forwarded call
            res := delegatecall(gas, libAddress, ptr, size, ptr, 0)             // delegatecall to library
            if iszero(res) { revert(0, 0) }                                     // safety check

            returndatacopy(ptr, 0, returndatasize)                              // copy return data into ptr for returning
            return(ptr, returndatasize)                                         // return forwarded call returndata
        }
    }

    // event TournamentCreated(address _tournamentAddress);
    // function createTournament() public returns(address) {
    //     address tournamentAddress = new Tournament(this);
    //     emit TournamentCreated(tournamentAddress);
    //     return tournamentAddress;
    // }

    function setContractLibrary(address _contract, bytes32 _libraryName) public { // onlyOwner!!!
        contractToLibraryName[_contract] = _libraryName;
    }
}

interface IMatryxPlatform {
    // function test(uint256,uint256[],uint256) external view returns (uint256);
    function test(uint256) public view returns (uint256);
}

library LibPlatform {
    function test(uint256 n) public view returns (uint256) {
        return n + 1;
    }
    // function test(uint256[] storage injected, uint256 a, uint256[] b, uint256 c) public view returns (uint256) {
    //     return injected.length;
    // }
}

library LibTest {
    function test(uint256 n) public view returns (uint256) {
        return n;
    }
}

/*

proxy = contract(MatryxProxy.address, MatryxProxy);0
proxy.createVersion(1)
proxy.setVersion(1)
proxy.setContract(1, stringToBytes('LibPlatform'), LibPlatform.address)
proxy.addContractMethod(1, stringToBytes('LibPlatform'), '0x29e99f07', ['0x29e99f07', [], []])

// test(uint256,uint256[],uint256) => test(uint256[] storage,uint256,uin256[],uint256)
// proxy.addContractMethod(1, 'stringToBytes('LibPlatform')', '0xb01bd421', ['0x4cc53767', [2], [1]])

proxy.setContract(1, stringToBytes('LibTest'), LibTest.address)
proxy.addContractMethod(1, stringToBytes('LibPlatform'), '0x29e99f07', ['0x29e99f07', [], []])

p = contract(MatryxPlatform.address, IMatryxPlatform);0
p.setContractLibrary(network.accounts[0], stringToBytes('LibTest'))
p.test(10)
// p.test(3,[7,6,5],4)

*/
