pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./LibGlobals.sol";
import "./IToken.sol";

import "./MatryxSystem.sol";
import "./MatryxCommit.sol";
import "./MatryxUser.sol";
import "./MatryxTournament.sol";
import "./MatryxRound.sol";

contract MatryxPlatform {
    using SafeMath for uint256;

    struct Info {
        address system;
        address token;
        address owner;
    }

    struct Data {
        uint256 totalBalance;                                        // total mtx balance of the platform
        mapping(address=>uint256) balanceOf;                         // maps user addresses to user balances
        mapping(bytes32=>uint256) commitBalance;                     // maps commit hashes to commit mtx balances

        mapping(address=>LibTournament.TournamentData) tournaments;  // maps tournament addresses to tournament structs
        mapping(address=>LibRound.RoundData) rounds;                 // maps round addresses to round structs
        mapping(address=>LibUser.UserData) users;                    // maps user addresses to user structs
        mapping(bytes32=>address[]) categories;                      // makes category hash to all tournaments in category
        mapping(bytes32=>bool) categoryExists;                       // maps category hash to whether or not category exists

        address[] allTournaments;                                    // all matryx tournament addresses
        address[] allRounds;                                         // all round addresses to matryx tournaments
        address[] allUsers;                                          // all matryx user addresses
        bytes32[] allCategories;                                     // all categories tournaments have been made in

        mapping(bytes32=>LibCommit.Commit) commits;                  // maps commit hashes to commits
        mapping(bytes32=>LibCommit.Group) groups;                    // maps group hashes to group structs
        mapping(bytes32=>bytes32) commitHashes;                      // maps content hashes to commit hashes
        mapping(bytes32=>address[]) commitToRounds;                  // maps commits to rounds they've been submitted to

        bytes32[] allGroups;                                         // all group hashes. length is new group number
        bytes32[] initialCommits;                                    // all commits without parents
        uint256 commitDistributionDepth;
    }

    Info info;                                                       // slot 0
    Data data;                                                       // slot 3

    constructor(address system, address token) public {
        info.system = system;
        info.token = token;
        info.owner = msg.sender;
        data.commitDistributionDepth = 20;
    }

    /// @dev
    /// 1) Uses msg.sender to ask MatryxSystem for the type of library this call should be forwarded to
    /// 2) Uses this library type to lookup (in its own storage) the name of the library
    /// 3) Uses this name to ask MatryxSystem for the address of the contract (under this platform's version)
    /// 4) Uses name and signature to ask MatryxSystem for the data necessary to modify the incoming calldata
    ///    so as to be appropriate for the associated library call
    /// 5) Makes a delegatecall to the library address given by MatryxSystem with the library-appropriate calldata
    function () external {
        assembly {
            // constants
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let libPlatform := 0x4c6962506c6174666f726d000000000000000000000000000000000000000000

            let ptr := mload(0x40)                                              // scratch space for calldata
            let system := sload(info_slot)                                      // load info.system address

            mstore(0, mul(0x0d8e6e2c, offset))                                  // getVersion()
            let res := call(gas, system, 0, 0, 0x04, 0, 0x20)                   // call system getVersion
            if iszero(res) { revert(0, 0) }                                     // safety check
            let version := mload(0)                                             // store version from response

            mstore(0, mul(0xa8bc3927, offset))                                  // getLibraryName(address)
            mstore(0x04, caller)                                                // arg 0 - contract
            res := call(gas, system, 0, 0, 0x24, 0, 0x20)                       // call system getLibraryName
            if iszero(res) { revert(0, 0) }                                     // safety check
            let libName := mload(0)                                             // store libName from response

            if iszero(eq(libName, libPlatform)) {                               // if coming from MatryxForwarder or MatryxUser
                calldatacopy(0, 0x24, 0x20)                                     // get injected version from calldata
                version := mload(0)                                             // overwrite version var
            }

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

            mstore(ptr2, address)                                               // inject platform
            mstore(add(ptr2, 0x20), caller)                                     // inject msg.sender

            let cdOffset := 0x04                                                // calldata offset, after signature

            if iszero(eq(libName, libPlatform)) {                               // if coming from MatryxForwarder or MatryxUser
                mstore(ptr2, caller)                                            // overwrite injected platform with sender
                calldatacopy(add(ptr2, 0x20), 0x04, 0x20)                       // overwrite injected sender with address from forwarder
                cdOffset := add(cdOffset, 0x40)                                 // shift calldata offset for injected address and version
            }
            ptr2 := add(ptr2, 0x40)                                             // shift ptr2 to account for injected addresses

            for { let i := 0 } lt(i, injParams_len) { i := add(i, 1) } {        // loop through injected params and insert
                let injParam := mload(add(m_injParams, mul(i, 0x20)))           // get injected param slot
                mstore(ptr2, injParam)                                          // store injected params into next slot
                ptr2 := add(ptr2, 0x20)                                         // shift ptr2 by a word for each injected
            }

            calldatacopy(ptr2, cdOffset, sub(calldatasize, cdOffset))           // copy calldata after injected data storage

            for { let i := 0 } lt(i, dynParams_len) { i := add(i, 1) } {        // loop through params and update dynamic param locations
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

    modifier onlyOwner() {
        require(msg.sender == info.owner, "Must be Platform owner");
        _;
    }

    /// @dev Gets Information about the Platform
    /// @return  Info Struct that contains system, version, token, and owner
    function getInfo() public view returns (MatryxPlatform.Info memory) {
        return info;
    }

    /// @dev Sets the owner of the platform
    /// @param newOwner  New owner address
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0));
        info.owner = newOwner;
    }

    /// @dev Sets the Token address
    /// @param token  New token address
    function upgradeToken(address token) external onlyOwner {
        IToken(info.token).upgrade(data.totalBalance);

        require(IToken(token).balanceOf(address(this)) == data.totalBalance, "Token address must match upgraded token");
        info.token = token;
    }

    /// @dev Withdraws any Ether from Platform
    function withdrawEther() external onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    /// @dev Withdraws any ERC20 tokens from Platform
    /// @param token  ERC20 token address to use
    function withdrawTokens(address token) external onlyOwner {
        uint256 balance = IToken(token).balanceOf(address(this));

        // if current token, check if any extraneous tokens
        if (token == info.token) {
            balance = balance.sub(data.totalBalance);
        }

        require(IToken(token).transfer(msg.sender, balance));
    }
}

interface IMatryxPlatform {
    function getInfo() external view returns (MatryxPlatform.Info memory);
    function setOwner(address) external;
    function upgradeToken(address) external;
    function withdrawEther() external;
    function withdrawTokens(address) external;
    function withdrawBalance() external;

    function isTournament(address) external view returns (bool);
    function isRound(address) external view returns (bool);
    function isSubmission(bytes32) external view returns (bool);
    function hasEnteredMatryx(address) external view returns (bool);

    function getTotalBalance() external view returns (uint256);
    function getBalanceOf(address) external view returns (uint256);
    function getCommitBalance(bytes32) external view returns (uint256);

    function getTournamentCount() external view returns (uint256);
    function getUserCount() external view returns (uint256);
    function getTournaments() external view returns (address[] memory);
    function getTournamentsByCategory(bytes32) external view returns (address[] memory);
    function getUsers() external view returns (address[] memory);
    function getCategories() external view returns (bytes32[] memory);

    function createCategory(bytes32) external;

    function enterMatryx() external;
    function addTournamentToCategory(address, bytes32) external;
    function removeTournamentFromCategory(address) external;
    function createTournament(LibTournament.TournamentDetails calldata, LibRound.RoundDetails calldata) external returns (address);

    function setCommitDistributionDepth(uint256 depth) external;
}

library LibPlatform {
    using SafeMath for uint256;

    event TournamentCreated(address _tournamentAddress);

    /// @dev Return if a Tournament exists
    /// @param tAddress  Tournament address
    /// @return          true if Tournament exists
    function isTournament(address, address, MatryxPlatform.Data storage data, address tAddress) public view returns (bool) {
        return data.tournaments[tAddress].info.owner != address(0);
    }

    /// @dev Return if a Round exists
    /// @param rAddress  Round address
    /// @return          true if Round exists
    function isRound(address, address, MatryxPlatform.Data storage data, address rAddress) public view returns (bool) {
        return data.rounds[rAddress].info.tournament != address(0);
    }

    /// @dev Return if user has entered Matryx
    /// @param data  Platform storage containing all contract data
    /// @return      If user has entered Matryx
    function hasEnteredMatryx(address, address, MatryxPlatform.Data storage data, address uAddress) public view returns (bool) {
        return data.users[uAddress].exists;
    }

    /// @dev Return total MTX in Platform
    /// @param data  Platform storage containing all contract data
    /// @return      Total MTX in Platform
    function getTotalBalance(address, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.totalBalance;
    }

    /// @dev Return balance of a Tournament, Round, or user address
    /// @param data      Platform storage containing all contract data
    /// @param cAddress  Address of the contract we get the balance of
    /// @return          Balance of the Forwarder contract
    function getBalanceOf(address, address, MatryxPlatform.Data storage data, address cAddress) public view returns (uint256) {
        return data.balanceOf[cAddress];
    }

    /// @dev Return balance of a Commit
    /// @param data        Platform storage containing all contract data
    /// @param commitHash  Hash of the commit we get the balance of
    /// @return            Balance of the Forwarder contract
    function getCommitBalance(address, address, MatryxPlatform.Data storage data, bytes32 commitHash) public view returns (uint256) {
        return data.commitBalance[commitHash];
    }

    /// @dev Return total number of Tournaments
    /// @param data  Platform storage containing all contract data
    /// @return      Number of Tournaments on Platform
    function getTournamentCount(address, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.allTournaments.length;
    }

    /// @dev Return total number of Users
    /// @param data  Platform storage containing all contract data
    /// @return      Number of Users on Platform
    function getUserCount(address, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.allUsers.length;
    }

    /// @dev Return all Tournaments
    /// @param data  Platform storage containing all contract data
    /// @return      Array of Tournament addresses
    function getTournaments(address, address, MatryxPlatform.Data storage data) public view returns (address[] memory) {
        return data.allTournaments;
    }

    /// @dev Return all Tournaments for a category
    /// @param data      Platform storage containing all contract data
    /// @param category  Category name to get
    /// @return          Array of Tournament addresses for given category
    function getTournamentsByCategory(address, address, MatryxPlatform.Data storage data, bytes32 category) public view returns (address[] memory) {
        return data.categories[category];
    }

    /// @dev Return all Users
    /// @param data        Platform storage containing all contract data
    /// @return            Array of User addresses
    function getUsers(address, address, MatryxPlatform.Data storage data) public view returns (address[] memory) {
        return data.allUsers;
    }

    /// @dev Return all Categories
    /// @param data        Platform storage containing all contract data
    /// @return            Array of Categories
    function getCategories(address, address, MatryxPlatform.Data storage data) public view returns (bytes32[] memory) {
        return data.allCategories;
    }

    /// @dev Withdraw available MTX balance
    function withdrawBalance(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        uint256 amount = data.balanceOf[sender];
        data.balanceOf[sender] = 0;
        data.totalBalance = data.totalBalance.sub(amount);
        data.users[sender].totalCashedOut = data.users[sender].totalCashedOut.add(amount);
        require(IToken(info.token).transfer(sender, amount));
    }

    /// @dev Creates a category
    /// @param sender    msg.sender to Platform
    /// @param info      Platform storage containing version number and system address
    /// @param data      Platform storage containing all contract data and users
    /// @param category  Category to create
    function createCategory(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, bytes32 category) public {
        require(sender == info.owner, "Must be Platform owner");
        require(!data.categoryExists[category], "Category already exists");

        data.allCategories.push(category);
        data.categoryExists[category] = true;
    }

    /// @dev Enter Matryx
    /// @param sender  msg.sender to Platform
    /// @param info    Platform storage containing version number and system address
    /// @param data    Platform storage containing all contract data and users
    function enterMatryx(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        require(!data.users[sender].exists, "Already entered Matryx");
        require(IToken(info.token).balanceOf(sender) > 0, "Must have MTX");

        data.users[sender].exists = true;
        data.users[sender].timeEntered = now;
        data.allUsers.push(sender);
    }

    /// @dev Adds a Tournament to a category
    /// @param data      Platform storage containing all contract data
    /// @param tAddress  Tournament address
    /// @param category  Category name
    function addTournamentToCategory(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, address tAddress, bytes32 category) public {
        require(sender == address(this) || IMatryxSystem(info.system).getContractType(sender) == uint256(LibSystem.ContractType.Tournament), "Must come from Platform or Tournament");
        require(data.categoryExists[category], "Category does not exist");

        data.categories[category].push(tAddress);
        data.tournaments[tAddress].details.category = category;
    }

    /// @dev Removes a Tournament from its current category
    /// @param data      Platform storage containing all contract data
    /// @param tAddress  Tournament address
    function removeTournamentFromCategory(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, address tAddress) public {
        require(sender == address(this) || IMatryxSystem(info.system).getContractType(sender) == uint256(LibSystem.ContractType.Tournament), "Must come from Platform or Tournament");

        uint256 version = IMatryxSystem(info.system).getVersion();
        address libUtils = IMatryxSystem(info.system).getContract(version, "LibUtils");

        bytes32 category = data.tournaments[tAddress].details.category;
        address[] storage categoryList = data.categories[category];
        uint256 index;

        for (index = 0; index < categoryList.length; index++) {
            if (categoryList[index] == tAddress) break;
        }

        assembly {
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let ptr := mload(0x40)

            mstore(ptr, mul(0x4a71ede8, offset))                        // removeArrayElement(bytes32[] storage,uint256)
            mstore(add(ptr, 0x04), categoryList_slot)                   // arg 0 - data.categories[tournament.category]
            mstore(add(ptr, 0x24), index)                               // arg 1 - index

            let res := delegatecall(gas, libUtils, ptr, 0x44, 0, 0)     // call LibUtils.removeArrayElement
            if iszero(res) { revert(0, 0) }                             // safety check
        }
    }

    /// @dev Creates a Tournament
    /// @param sender    msg.sender to Platform
    /// @param info      Platform storage containing version number and system address
    /// @param data      Platform storage containing all contract data and users
    /// @param tDetails  Tournament details (title, category, descHash, fileHash, bounty, entryFee)
    /// @param rDetails  Round details (start, end, review, bounty)
    /// @return          Address of the created Tournament
    function createTournament(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibTournament.TournamentDetails memory tDetails, LibRound.RoundDetails memory rDetails) public returns (address) {
        require(data.users[sender].exists, "Must have entered Matryx");
        require(tDetails.bounty > 0, "Tournament bounty must be greater than 0");
        require(rDetails.bounty <= tDetails.bounty, "Round bounty cannot exceed Tournament bounty");
        require(IToken(info.token).allowance(sender, self) >= tDetails.bounty, "Insufficient MTX");

        uint256 version = IMatryxSystem(info.system).getVersion();
        address tAddress = address(new MatryxTournament(version, info.system));

        IMatryxSystem(info.system).setContractType(tAddress, uint256(LibSystem.ContractType.Tournament));
        data.allTournaments.push(tAddress);
        addTournamentToCategory(self, self, info, data, tAddress, tDetails.category);

        LibUser.UserData storage user = data.users[sender];
        user.tournaments.push(tAddress);
        user.totalSpent = user.totalSpent.add(tDetails.bounty);

        LibTournament.TournamentData storage tournament = data.tournaments[tAddress];
        tournament.info.version = version;
        tournament.info.owner = sender;
        tournament.details = tDetails;

        data.totalBalance = data.totalBalance.add(tDetails.bounty);
        data.balanceOf[tAddress] = tDetails.bounty;
        require(IToken(info.token).transferFrom(sender, self, tDetails.bounty), "Transfer failed");

        address libTournament = IMatryxSystem(info.system).getContract(version, "LibTournament");
        assembly {
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let ptr := mload(0x40)

            mstore(ptr, mul(0xca0ba8b4, offset))                            // createRound(address,address,MatryxPlatform.Info storage,MatryxPlatform.Data storage,LibRound.RoundDetails)
            mstore(add(ptr, 0x04), tAddress)                                // arg 0 - self
            mstore(add(ptr, 0x24), sender)                                  // arg 1 - sender
            mstore(add(ptr, 0x44), info_slot)                               // arg 2 - info
            mstore(add(ptr, 0x64), data_slot)                               // arg 3 - data
            calldatacopy(add(ptr, 0x84), sub(calldatasize, 0x80), 0x80)     // arg 4 - rDetails

            let res := delegatecall(gas, libTournament, ptr, 0x104, 0, 0)   // call LibTournament.createRound
            if iszero(res) { revert(0, 0) }                                 // safety check
        }
        // LibTournament.createRound(tAddress, this, info, data, rDetails);

        emit TournamentCreated(tAddress);
        return tAddress;
    }

    function setCommitDistributionDepth(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, uint256 depth) public {
        require(sender == info.owner, "Must be Platform owner");
        data.commitDistributionDepth = depth;
    }
}
