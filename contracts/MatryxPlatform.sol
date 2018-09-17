pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./MatryxProxy.sol";
import "./IMatryxToken.sol";

import "./MatryxTournament.sol";
import "./MatryxRound.sol";
import "./MatryxSubmission.sol";

import "./LibGlobals.sol";
import "./LibUser.sol";

contract MatryxPlatform {
    struct Info {
        address proxy;
        uint256 version;
        address token;
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
    Data data; // slot 4

    // Maps contract types from MatryxProxy to human-readable library names.
    mapping(uint256=>bytes32) contractTypeToLibraryName;

    constructor(address proxy, uint256 version, address token) public {
        info.proxy = proxy;
        info.version = version;
        info.token = token;
        info.owner = msg.sender;

        contractTypeToLibraryName[uint256(MatryxProxy.ContractType.Tournament)] = "LibTournament";
        contractTypeToLibraryName[uint256(MatryxProxy.ContractType.Round)] = "LibRound";
        contractTypeToLibraryName[uint256(MatryxProxy.ContractType.Submission)] = "LibSubmission";
    }

    /// @dev
    /// 1) Uses msg.sender to ask MatryxProxy for the type of library this call should be forwarded to
    /// 2) Uses this library type to lookup (in its own storage) the name of the library
    /// 3) Uses this name to ask MatryxProxy for the address of the contract (under this platform's version)
    /// 4) Uses name and signature to ask MatryxProxy for the data necessary to modify the incoming calldata
    ///    so as to be appropriate for the associated library call
    /// 5) Makes a delegatecall to the library address given by MatryxProxy with the library-appropriate calldata
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
            let ptr2 := add(ptr, mload(ptr))                                    // ptr2 is pointer to start of fnData

            let m_injParams := add(ptr2, mload(add(ptr2, 0x20)))                // mem loc injected params
            let injParams_len := mload(m_injParams)                             // num injected params
            m_injParams := add(m_injParams, 0x20)                               // first injected param

            let m_dynParams := add(ptr2, mload(add(ptr2, 0x40)))                // memory location of start of dynamic params
            let dynParams_len := mload(m_dynParams)                             // num dynamic params
            m_dynParams := add(m_dynParams, 0x20)                               // first dynamic param

            // forward calldata to library
            ptr := add(ptr, returndatasize)                                     // shift ptr to new scratch space
            mstore(ptr, mload(ptr2))                                            // forward call with modified selector

            ptr2 := add(ptr, 0x04)                                              // copy of ptr for keeping track of injected params

            mstore(ptr2, caller)                                                // inject msg.sender
            mstore(add(ptr2, 0x20), caller)                                     // inject msg.sender again if on platform

            let cdOffset := 0x04                                                // calldata offset, after signature

            if iszero(eq(libName, libPlatform)) {                               // if coming from forwarder:
                calldatacopy(add(ptr2, 0x20), 0x04, 0x20)                       // overwrite injected msg.sender with address from forwarder
                cdOffset := add(cdOffset, 0x20)                                 // shift calldata offset for injected address
            }
            ptr2 := add(ptr2, 0x40)                                             // shift ptr2

            for { let i := 0 } lt(i, injParams_len) { i := add(i, 1) } {        // loop through injected params and insert
                let injParam := mload(add(m_injParams, mul(i, 0x20)))           // get injected param slot
                mstore(ptr2, injParam)                                          // store injected params into next slot
                ptr2 := add(ptr2, 0x20)                                         // shift ptr2
            }

            calldatacopy(ptr2, cdOffset, sub(calldatasize, cdOffset))           // copy calldata after injected data storage

            // update dynamic params location
            for { let i := 0 } lt(i, dynParams_len) { i := add(i, 1) } {
                let idx := mload(add(m_dynParams, mul(i, 0x20)))                // get dynParam index in parameters
                let loc := add(ptr2, mul(idx, 0x20))                            // get location in memory of dynParam
                mstore(loc, add(mload(loc), mul(add(injParams_len, 2), 0x20)))  // shift dynParam location by num injected
            }

            // calculate size of forwarded call
            let size := add(0x04, sub(calldatasize, cdOffset))                  // calldatasize minus injected
            size := add(size, mul(add(injParams_len, 2), 0x20))                 // add size of injected

            res := delegatecall(gas, libAddress, ptr, size, 0, 0)               // delegatecall to library
            if iszero(res) { revert(0, 0) }                                     // safety check

            returndatacopy(ptr, 0, returndatasize)                              // copy return data into ptr for returning
            return(ptr, returndatasize)                                         // return forwarded call returndata
        }
    }

    /// @dev Sets the name of a library for a given contract type
    /// @param contractType The type of the contract, as given by MatryxProxy
    /// @param libraryName  The name of the library
    function setContractTypeLibrary(uint256 contractType, bytes32 libraryName) public {
        require(msg.sender == info.owner, "Must be Platform owner");
        contractTypeToLibraryName[contractType] = libraryName;
    }

    /// @dev Gets the name of a library from a given contract type
    /// @param contractType The type of the contract, as given by MatryxProxy
    /// @return              The name of the library as a bytes32
    function getContractTypeLibrary(uint256 contractType) public view returns (bytes32) {
        return contractTypeToLibraryName[contractType];
    }

    function getInfo() public view returns (MatryxPlatform.Info) {
        return info;
    }
}

interface IMatryxPlatform {
    function setContractTypeLibrary(uint256, bytes32) external;
    function getContractTypeLibrary(uint256) external view returns (bytes32);
    function getInfo() external view returns (MatryxPlatform.Info);

    function getTournaments() external view returns (address[]);

    function enterMatryx() external;
    function createTournament(LibTournament.TournamentDetails, LibRound.RoundDetails) external returns (address);
}

// dependencies: LibTournament
library LibPlatform {
    event TournamentCreated(address _tournamentAddress);

    /// @dev Return all Tournaments
    /// @param data  Platform storage containing all contract data
    /// @return      Array of Tournament addresses
    function getTournaments(address, address, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.allTournaments;
    }

    /// @dev Enter Matryx
    /// @param sender  msg.sender to Platform
    /// @param info    Platform storage containing version number and proxy address
    /// @param data    Platform storage containing all contract data and users
    function enterMatryx(address sender, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        require(!data.users[sender].exists, "Already entered Matryx");
        require(IMatryxToken(info.token).balanceOf(sender) > 0, "Must have MTX");

        data.users[sender].exists = true;
        data.allUsers.push(sender);
    }

    /// @dev Creates a Tournament
    /// @param sender    msg.sender to Platform
    /// @param info      Platform storage containing version number and proxy address
    /// @param data      Platform storage containing all contract data and users
    /// @param tDetails  Tournament details (title, category, descHash, fileHash, bounty, entryFee)
    /// @param rDetails  Round details (start, end, review, bounty)
    /// @return          Address of the created Tournament
    function createTournament(address sender, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibTournament.TournamentDetails tDetails, LibRound.RoundDetails rDetails) public returns (address) {
        require(data.users[sender].exists, "Must have entered Matryx");
        require(rDetails.bounty <= tDetails.bounty, "Round bounty cannot exceed Tournament bounty");
        // require(IMatryxToken(info.token).allowance(sender, this) >= tDetails.bounty, "Insufficient MTX");

        address tAddress = new MatryxTournament(info.version, info.proxy);
        MatryxProxy(info.proxy).setContractType(tAddress, MatryxProxy.ContractType.Tournament);
        data.allTournaments.push(tAddress);
        data.users[sender].tournaments.push(tAddress);
        emit TournamentCreated(tAddress);

        LibTournament.TournamentData storage tournament = data.tournaments[tAddress];
        tournament.owner = sender;
        tournament.details = tDetails;

        require(IMatryxToken(info.token).transferFrom(sender, tAddress, tDetails.bounty), "Transfer failed");

        // NOTE: if LibTournament is redeployed, relink and redeploy LibPlatform
        LibTournament.createRound(tAddress, sender, info, data, rDetails);

        return tAddress;
    }
}

/**
token.setReleaseAgent(network.accounts[0])
token.releaseTokenTransfer()
token.mint(network.accounts[0], toWei(1e9))
token.approve(p.address, toWei(1e6))
p.enterMatryx()
p.createTournament([stb('title', 3), stb('category'), stb('descHash', 2), stb('fileHash', 2), toWei(1000), 2], [1,2,3,4])
p.getTournaments()

t = contract('tAddress', IMatryxTournament);0
t.createSubmission([stb('title', 3), stb('descHash', 2), stb('fileHash', 2)])
t.getRounds()

r = contract('rAddress', IMatryxRound);0
r.getSubmissions()

s = contract('sAddress', IMatryxSubmission);0

 */
