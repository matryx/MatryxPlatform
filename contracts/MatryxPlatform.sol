pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./MatryxProxy.sol";
import "./MatryxTournament.sol";
import "./MatryxRound.sol";
import "./MatryxSubmission.sol";
import "./LibUser.sol";

contract MatryxPlatform {
    struct Info {
        address proxy;
        uint256 version;
        address owner;
    }

    struct Data {
        mapping(address=>LibTournament.TournamentData) tournaments;
        mapping(address=>LibRound.RoundData) rounds;
        mapping(address=>LibSubmission.SubmissionData) submissions;
        mapping(address=>LibUser.UserData) users;

        address[] allTournaments;
        address[] allRounds;
        address[] allSubmissions;
        address[] allUsers;
    }

    Info info; // slot 0
    Data data; // slot 3

    mapping(uint256=>bytes32) contractTypeToLibraryName;                        // contract type => 'Lib_____' (hex)

    // event TournamentCreated(address _tournamentAddress);
    // event RoundCreated(address _roundAddress);

    constructor(address _proxy, uint256 _version) public {
        info.proxy = _proxy;
        info.version = _version;
        info.owner = msg.sender;

        contractTypeToLibraryName[uint256(MatryxProxy.ContractType.Tournament)] = "LibTournament";
        contractTypeToLibraryName[uint256(MatryxProxy.ContractType.Round)] = "LibRound";
        contractTypeToLibraryName[uint256(MatryxProxy.ContractType.Submission)] = "LibSubmission";
    }

    modifier onlyOwner {
        require(msg.sender == info.owner);
        _;
    }

    function () public {
        assembly {
            // constants
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let libPlatform := 0x4c6962506c6174666f726d000000000000000000000000000000000000000000

            let ptr := mload(0x40)                                              // scratch space for calldata
            let proxy := sload(info_slot)                                       // load info.proxy address
            let version := sload(add(info_slot, 1))                             // load info.version number

            mstore(0, mul(0xe11aa6a2, offset))                                  // getContractType(address)
            mstore(0x04, caller)                                                // arg 0 - contract
            let res := call(gas, proxy, 0, 0, 0x24, 0, 0x20)                    // call proxy.getContractType
            if iszero(res) { revert(0, 0) }                                     // safety check

            // get library name for contract type                               // key - type (in 0x0) from getContractType
            mstore(0x20, contractTypeToLibraryName_slot)                        // map - contract type to library name
            let libName := sload(keccak256(0, 0x40))                            // get library name for contract type
            if iszero(libName) { libName := libPlatform }                       // default to LibPlatform

            // call proxy and get library address
            mstore(ptr, mul(0xc53cfd9a, offset))                                // getContract(uint256,bytes32)
            mstore(add(ptr, 0x04), version)                                     // arg 0 - version
            mstore(add(ptr, 0x24), libName)                                     // arg 1 - library name
            res := call(gas, proxy, 0, ptr, 0x44, 0, 0x20)                      // call proxy.getContract
            if iszero(res) { revert(0, 0) }                                     // safety check
            let libAddress := mload(0)                                          // store libAddress from response

            // get fnData from proxy
            mstore(ptr, mul(0x3b15aabf, offset))                                // getContractMethod(uint256,bytes32,bytes32)
            mstore(add(ptr, 0x04), version)                                     // arg 0 - version
            mstore(add(ptr, 0x24), libName)                                     // arg 1 - library name
            calldatacopy(add(ptr, 0x44), 0, 0x04)                               // arg 2 - fn selector
            res := call(gas, proxy, 0, ptr, 0x64, 0, 0)                         // call proxy.getContractMethod
            if iszero(res) { revert(0, 0) }                                     // safety check

            returndatacopy(ptr, 0, returndatasize)                              // copy fnData into ptr
            let ret := add(ptr, mload(ptr))                                     // ret is pointer to start of fnData

            let m_injParams := add(ret, mload(add(ret, 0x20)))                  // mem loc injected params
            let injParams_len := mload(m_injParams)                             // num injected params
            m_injParams := add(m_injParams, 0x20)                               // first injected param

            let m_dynParams := add(ret, mload(add(ret, 0x40)))                  // memory location of start of dynamic params
            let dynParams_len := mload(m_dynParams)                             // num dynamic params
            m_dynParams := add(m_dynParams, 0x20)                               // first dynamic param

            // forward calldata to library
            ptr := add(ptr, returndatasize)                                     // shift ptr to new scratch space
            mstore(ptr, mload(ret))                                             // forward call with modified selector

            let ptr2 := add(ptr, 0x04)                                          // copy of ptr for keeping track of injected params

            mstore(ptr2, caller)                                                // inject msg.sender
            ptr2 := add(ptr2, 0x20)                                             // shift ptr2

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
                mstore(loc, add(mload(loc), mul(add(injParams_len, 1), 0x20)))  // shift dynParam location by num injected
            }

            let size := add(calldatasize, mul(add(injParams_len, 1), 0x20))     // calculate size of forwarded call
            // log0(ptr, size)
            res := delegatecall(gas, libAddress, ptr, size, 0, 0)               // delegatecall to library
            if iszero(res) { revert(0, 0) }                                     // safety check

            returndatacopy(ptr, 0, returndatasize)                              // copy return data into ptr for returning
            return(ptr, returndatasize)                                         // return forwarded call returndata
        }
    }

    function setContractTypeLibrary(uint256 _contractType, bytes32 _libraryName) public { // onlyOwner!!!
        contractTypeToLibraryName[_contractType] = _libraryName;
    }

    function getContractTypeLibrary(uint256 _contractType) public view returns (bytes32) {
        return contractTypeToLibraryName[_contractType];
    }
}

interface IMatryxPlatform {
    function setContractTypeLibrary(uint256, bytes32) public;
    function getContractTypeLibrary(uint256) public view returns (bytes32);

    function getAllTournaments() public view returns (address[]);
    function createTournament() public returns (address);
    function enterTournament(address) public;
}

library LibPlatform {
    event TournamentCreated(address _tournamentAddress);

    function getAllTournaments(address sender, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.allTournaments;
    }

    function createTournament(address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public returns (address) {
        address tournamentAddress = new MatryxTournament(info.version, info.proxy);
        MatryxProxy(info.proxy).setContractType(tournamentAddress, MatryxProxy.ContractType.Tournament);
        data.allTournaments.push(tournamentAddress);
        emit TournamentCreated(tournamentAddress);

        LibTournament.TournamentData storage tournament = data.tournaments[tournamentAddress];
        tournament.owner = 0x7ac07ac0;

        return tournamentAddress;
    }

    function enterTournament(address sender, MatryxPlatform.Data storage data, address _tournamentAddress) public {
        // LibTournament.TournamentData storage tournamentData = data.tournaments[_tournamentAddress];
        // do stuff to enter
    }
}
