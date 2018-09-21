pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

import "./MatryxSystem.sol";
import "./IMatryxToken.sol";

import "./MatryxTournament.sol";
import "./MatryxRound.sol";
import "./MatryxSubmission.sol";

import "./LibGlobals.sol";
import "./LibUser.sol";

contract MatryxPlatform {
    struct Info {
        address system;
        uint256 version;
        address token;
        address owner;
    }

    struct Data {
        mapping(address=>LibTournament.TournamentData) tournaments;
        mapping(address=>LibRound.RoundData) rounds;
        mapping(address=>LibSubmission.SubmissionData) submissions;
        mapping(address=>LibUser.UserData) users;
        mapping(bytes32=>address[]) categories;

        address[] allTournaments;
        address[] allRounds;
        address[] allSubmissions;
        address[] allUsers;
        bytes32[] allCategories;
    }

    Info info; // slot 0
    Data data; // slot 4

    // Maps contract types from MatryxSystem to human-readable library names.
    mapping(uint256=>bytes32) contractTypeToLibraryName;

    constructor(address system, uint256 version, address token) public {
        info.system = system;
        info.version = version;
        info.token = token;
        info.owner = msg.sender;

        contractTypeToLibraryName[uint256(MatryxSystem.ContractType.Tournament)] = "LibTournament";
        contractTypeToLibraryName[uint256(MatryxSystem.ContractType.Round)] = "LibRound";
        contractTypeToLibraryName[uint256(MatryxSystem.ContractType.Submission)] = "LibSubmission";
    }

    /// @dev
    /// 1) Uses msg.sender to ask MatryxSystem for the type of library this call should be forwarded to
    /// 2) Uses this library type to lookup (in its own storage) the name of the library
    /// 3) Uses this name to ask MatryxSystem for the address of the contract (under this platform's version)
    /// 4) Uses name and signature to ask MatryxSystem for the data necessary to modify the incoming calldata
    ///    so as to be appropriate for the associated library call
    /// 5) Makes a delegatecall to the library address given by MatryxSystem with the library-appropriate calldata
    function () public {
        assembly {
            // constants
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let libPlatform := 0x4c6962506c6174666f726d000000000000000000000000000000000000000000

            let ptr := mload(0x40)                                              // scratch space for calldata
            let system := sload(info_slot)                                      // load info.system address
            let version := sload(add(info_slot, 1))                             // load info.version number

            mstore(0, mul(0xe11aa6a2, offset))                                  // getContractType(address)
            mstore(0x04, caller)                                                // arg 0 - contract
            let res := call(gas, system, 0, 0, 0x24, 0, 0x20)                   // call system.getContractType
            if iszero(res) { revert(0, 0) }                                     // safety check

            // get library name for contract type                               // key - type (in 0x0) from getContractType
            mstore(0x20, contractTypeToLibraryName_slot)                        // map - contract type to library name
            let libName := sload(keccak256(0, 0x40))                            // get library name for contract type
            if iszero(libName) { libName := libPlatform }                       // default to LibPlatform

            // call system and get library address
            mstore(ptr, mul(0xc53cfd9a, offset))                                // getContract(uint256,bytes32)
            mstore(add(ptr, 0x04), version)                                     // arg 0 - version
            mstore(add(ptr, 0x24), libName)                                     // arg 1 - library name
            res := call(gas, system, 0, ptr, 0x44, 0, 0x20)                     // call system.getContract
            if iszero(res) { revert(0, 0) }                                     // safety check
            let libAddress := mload(0)                                          // store libAddress from response

            // get fnData from system
            mstore(ptr, mul(0x3b15aabf, offset))                                // getContractMethod(uint256,bytes32,bytes32)
            mstore(add(ptr, 0x04), version)                                     // arg 0 - version
            mstore(add(ptr, 0x24), libName)                                     // arg 1 - library name
            calldatacopy(add(ptr, 0x44), 0, 0x04)                               // arg 2 - fn selector
            res := call(gas, system, 0, ptr, 0x64, 0, 0)                        // call system.getContractMethod
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

    /// @dev    Gets Information about the Platform
    /// @return Info Struct that contains system, version, token, and owner
    function getInfo() public view returns (MatryxPlatform.Info) {
        return info;
    }

    /// @dev Gets the name of a library from a given contract type
    /// @param contractType  The type of the contract, as given by MatryxSystem
    /// @return              The name of the library as a bytes32
    function getContractTypeLibrary(uint256 contractType) public view returns (bytes32) {
        return contractTypeToLibraryName[contractType];
    }

    /// @dev Sets the name of a library for a given contract type
    /// @param contractType  The type of the contract, as given by MatryxSystem
    /// @param libraryName   The name of the library
    function setContractTypeLibrary(uint256 contractType, bytes32 libraryName) public {
        require(msg.sender == info.owner, "Must be Platform owner");
        contractTypeToLibraryName[contractType] = libraryName;
    }

    /// @dev Sets the Token address
    /// @param token  Address of MatryxToken
    function setTokenAddress(address token) external {
        require(msg.sender == info.owner, "Must be Platform owner");
        info.token = token;
    }
}

interface IMatryxPlatform {
    function getInfo() external view returns (MatryxPlatform.Info);
    function getContractTypeLibrary(uint256) external view returns (bytes32);
    function setContractTypeLibrary(uint256, bytes32) external;
    function setTokenAddress(address) external;

    function hasEnteredMatryx(address) external view returns (bool);

    function getTournamentCount() external view returns (uint256);
    function getTournaments(uint256, uint256) external view returns (address[]);
    function getTournamentsByCategory(bytes32, uint256, uint256) external view returns (address[]);
    function getCategories(uint256, uint256) external view returns (bytes32[]);
    function getTournamentsByUser(address) external view returns (address[]);
    function getSubmissionsByUser(address) external view returns (address[]);

    function enterMatryx() external;
    function addTournamentToCategory(address, bytes32) external;
    function createTournament(LibTournament.TournamentDetails, LibRound.RoundDetails) external returns (address);
}

// dependencies: LibTournament
library LibPlatform {
    using SafeMath for uint256;

    event TournamentCreated(address _tournamentAddress);

    /// @dev Return if user has entered Matryx
    /// @param data  Platform storage containing all contract data
    /// @return      If user has entered Matryx
    function hasEnteredMatryx(address, address, MatryxPlatform.Data storage data, address uAddress) public view returns (bool) {
        return data.users[uAddress].exists;
    }

    /// @dev Return total number of Tournaments
    /// @param data  Platform storage containing all contract data
    /// @return      Number of Tournaments on Platform
    function getTournamentCount(address, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.allTournaments.length;
    }

    /// @dev Return count Tournaments starting at startIndex
    /// @param info        Platform storage containing version number and system address
    /// @param data        Platform storage containing all contract data
    /// @param startIndex  Index of first Tournament to return
    /// @param count       Number of Tournaments to return. If 0, all
    /// @return            Array of Tournament addresses
    function getTournaments(address, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, uint256 startIndex, uint256 count) public view returns (address[]) {
        address LibUtils = MatryxSystem(info.system).getContract(info.version, "LibUtils");

        assembly {
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let ptr := mload(0x40)

            mstore(ptr, mul(0xe79eda2c, offset))                                // getSubArray(bytes32[] storage,uint256,uint256)
            mstore(add(ptr, 0x04), add(data_slot, 5))                           // data.allTournaments
            mstore(add(ptr, 0x24), startIndex)                                  // startIndex
            mstore(add(ptr, 0x44), count)                                       // count

            let res := delegatecall(gas, LibUtils, ptr, 0x64, 0, 0)             // call LibUtils.getSubArray
            if iszero(res) { revert(0, 0) }                                     // safety check

            returndatacopy(ptr, 0, returndatasize)                              // copy result into mem
            return(ptr, returndatasize)                                         // return result
        }
    }

    /// @dev Return all Tournaments for a category
    /// @param data      Platform storage containing all contract data
    /// @param category  Category name to get
    /// @return          Array of Tournament addresses for given category
    function getTournamentsByCategory(address, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 category, uint256 startIndex, uint256 count) public view returns (address[]) {
        address LibUtils = MatryxSystem(info.system).getContract(info.version, "LibUtils");

        assembly {
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let ptr := mload(0x40)

            mstore(0, category)
            mstore(0x20, add(data_slot, 4))                                     // data.categories
            let s_category := keccak256(0, 0x40)                                // data.categories[category] slot

            mstore(ptr, mul(0xe79eda2c, offset))                                // getSubArray(bytes32[] storage,uint256,uint256)
            mstore(add(ptr, 0x04), s_category)                                  // data.categories[category]
            mstore(add(ptr, 0x24), startIndex)                                  // startIndex
            mstore(add(ptr, 0x44), count)                                       // count

            let res := delegatecall(gas, LibUtils, ptr, 0x64, 0, 0)             // call LibUtils.getSubArray
            if iszero(res) { revert(0, 0) }                                     // safety check

            returndatacopy(ptr, 0, returndatasize)                              // copy result into mem
            return(ptr, returndatasize)                                         // return result
        }
    }

    /// @dev Return all categories
    /// @param data  Platform storage containing all contract data
    /// @return      Array of all category names
    function getCategories(address, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, uint256 startIndex, uint256 count) public view returns (bytes32[]) {
        address LibUtils = MatryxSystem(info.system).getContract(info.version, "LibUtils");

        assembly {
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let ptr := mload(0x40)

            mstore(ptr, mul(0xe79eda2c, offset))                                // getSubArray(bytes32[] storage,uint256,uint256)
            mstore(add(ptr, 0x04), add(data_slot, 9))                           // data.allCategories
            mstore(add(ptr, 0x24), startIndex)                                  // startIndex
            mstore(add(ptr, 0x44), count)                                       // count

            let res := delegatecall(gas, LibUtils, ptr, 0x64, 0, 0)             // call LibUtils.getSubArray
            if iszero(res) { revert(0, 0) }                                     // safety check

            returndatacopy(ptr, 0, returndatasize)                              // copy result into mem
            return(ptr, returndatasize)                                         // return result
        }
    }

    /// @dev Return all Tournaments for a user address
    /// @param data      Platform storage containing all contract data
    /// @param uAddress  User address
    /// @return          Array of all Tournaments for given user
    function getTournamentsByUser(address, address, MatryxPlatform.Data storage data, address uAddress) public view returns (address[]) {
        data.users[uAddress].tournaments;
    }

    /// @dev Return all Submissions for a user address
    /// @param data      Platform storage containing all contract data
    /// @param uAddress  User address
    /// @return          Array of all Submissions for given user
    function getSubmissionsByUser(address, address, MatryxPlatform.Data storage data, address uAddress) public view returns (address[]) {
        data.users[uAddress].submissions;
    }

    /// @dev Enter Matryx
    /// @param sender  msg.sender to Platform
    /// @param info    Platform storage containing version number and system address
    /// @param data    Platform storage containing all contract data and users
    function enterMatryx(address sender, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        require(!data.users[sender].exists, "Already entered Matryx");
        require(IMatryxToken(info.token).balanceOf(sender) > 0, "Must have MTX");

        data.users[sender].exists = true;
        data.allUsers.push(sender);
    }

    /// @dev Adds a Tournament to a category
    /// @param data      Platform storage containing all contract data
    /// @param tAddress  Tournament address
    /// @param category  Category name
    function addTournamentToCategory(address, address, MatryxPlatform.Data storage data, address tAddress, bytes32 category) public {
        if (data.categories[category].length == 0) {
            data.allCategories.push(category);
        }

        data.categories[category].push(tAddress);
    }

    // function removeTournamentFromCategory(address, address, MatryxPlatform.Data storage data, address tAddress, bytes32 category) public {
    //     // TODO
    // }

    /// @dev Creates a Tournament
    /// @param sender    msg.sender to Platform
    /// @param info      Platform storage containing version number and system address
    /// @param data      Platform storage containing all contract data and users
    /// @param tDetails  Tournament details (title, category, descHash, fileHash, bounty, entryFee)
    /// @param rDetails  Round details (start, end, review, bounty)
    /// @return          Address of the created Tournament
    function createTournament(address sender, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibTournament.TournamentDetails tDetails, LibRound.RoundDetails rDetails) public returns (address) {
        require(data.users[sender].exists, "Must have entered Matryx");
        require(rDetails.bounty <= tDetails.bounty, "Round bounty cannot exceed Tournament bounty");
        require(IMatryxToken(info.token).allowance(sender, this) >= tDetails.bounty, "Insufficient MTX");

        address tAddress = new MatryxTournament(info.version, info.system);

        MatryxSystem(info.system).setContractType(tAddress, MatryxSystem.ContractType.Tournament);
        data.allTournaments.push(tAddress);
        addTournamentToCategory(sender, sender, data, tAddress, tDetails.category);

        LibUser.UserData storage user = data.users[sender];
        user.tournaments.push(tAddress);
        user.totalSpent = user.totalSpent.add(tDetails.bounty);

        LibTournament.TournamentData storage tournament = data.tournaments[tAddress];
        tournament.info.owner = sender;
        tournament.details = tDetails;

        require(IMatryxToken(info.token).transferFrom(sender, tAddress, tDetails.bounty), "Transfer failed");

        // TODO: lookup on system, and use assembly to delegatecall
        // NOTE: if LibTournament is redeployed, relink and redeploy LibPlatform
        LibTournament.createRound(tAddress, sender, info, data, rDetails);

        emit TournamentCreated(tAddress);
        return tAddress;
    }

}

/**

p.enterMatryx()
token.approve(p.address, toWei(100))
tData = [stb('title', 3), stb('category'), stb('descHash', 2), stb('fileHash', 2), toWei(100), toWei(2)]
start = Math.floor(Date.now() / 1000) + 30
rData = [start, start + 30, 30, toWei(10)]
p.createTournament(tData, rData)
p.getTournaments(0,0).then(ts => t = contract(ts.pop(), IMatryxTournament));0
t.getRounds().then(rs => r = contract(rs.pop(), IMatryxRound));0
r.getSubmissions().then(ss => s = contract(ss.pop(), IMatryxSubmission));0

 */
