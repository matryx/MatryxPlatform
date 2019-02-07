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
        uint256 totalBalance;                                        // total allocated mtx balance of the platform
        mapping(address=>uint256) balanceOf;                         // maps user addresses to user balances
        mapping(bytes32=>uint256) commitBalance;                     // maps commit hashes to commit mtx balances

        mapping(address=>LibTournament.TournamentData) tournaments;  // maps tournament addresses to tournament structs
        mapping(address=>LibRound.RoundData) rounds;                 // maps round addresses to round structs
        mapping(address=>LibUser.UserData) users;                    // maps user addresses to user structs

        address[] allTournaments;                                    // all matryx tournament addresses
        address[] allRounds;                                         // all matryx round addresses
        address[] allUsers;                                          // all matryx user addresses

        mapping(bytes32=>LibCommit.Commit) commits;                  // maps commit hashes to commits
        mapping(bytes32=>LibCommit.Group) groups;                    // maps group hashes to group structs
        mapping(bytes32=>bytes32) commitHashes;                      // maps content hashes to commit hashes
        mapping(bytes32=>address[]) commitToRounds;                  // maps commits to rounds they've been submitted to
        mapping(bytes32=>LibCommit.CommitWithdrawalStats) commitWithdrawalStats; // maps commit hash to withdrawal stats

        bytes32[] allGroups;                                         // all group hashes; length is new group number
        bytes32[] initialCommits;                                    // all commits without parents
        uint256 commitDistributionDepth;                             // max depth to traverse to distribute commit funds
        mapping(bytes32=>uint256) commitClaims;                      // timestamp of content hash claim
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

    /// @dev Gets information about the Platform
    /// @return  Info Struct that contains system, token, and owner
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

    /// @dev Withdraws any unallocated ERC20 tokens from Platform
    /// @param token  ERC20 token address to use
    function withdrawTokens(address token) external onlyOwner {
        uint256 balance = IToken(token).balanceOf(address(this));

        // if current token, check if any extraneous tokens
        if (token == info.token) {
            balance = balance.sub(data.totalBalance);
        }

        require(IToken(token).transfer(msg.sender, balance), "Transfer failed");
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
    function getUsers() external view returns (address[] memory);

    function enterMatryx() external;
    function createTournament(LibTournament.TournamentDetails calldata, LibRound.RoundDetails calldata) external returns (address);
    
    function setCommitDistributionDepth(uint256 depth) external;
}

library LibPlatform {
    using SafeMath for uint256;

    event TournamentCreated(address _tournamentAddress);

    /// @dev Return if a Tournament exists
    /// @param data      Platform data struct
    /// @param tAddress  Tournament address
    /// @return          true if Tournament exists
    function isTournament(address, address, MatryxPlatform.Data storage data, address tAddress) public view returns (bool) {
        return data.tournaments[tAddress].info.owner != address(0);
    }

    /// @dev Return if a Round exists
    /// @param data      Platform data struct
    /// @param rAddress  Round address
    /// @return          true if Round exists
    function isRound(address, address, MatryxPlatform.Data storage data, address rAddress) public view returns (bool) {
        return data.rounds[rAddress].info.tournament != address(0);
    }

    /// @dev Return if user has entered Matryx
    /// @param data      Platform data struct
    /// @param uAddress  User address
    /// @return          true if user has entered Matryx
    function hasEnteredMatryx(address, address, MatryxPlatform.Data storage data, address uAddress) public view returns (bool) {
        return data.users[uAddress].entered;
    }

    /// @dev Return total allocated MTX in Platform
    /// @param data  Platform data struct
    /// @return      Total allocated MTX in Platform
    function getTotalBalance(address, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.totalBalance;
    }

    /// @dev Return balance of a Tournament, Round, or user address
    /// @param data      Platform data struct
    /// @param cAddress  Address to get the balance of
    /// @return          Address balance on Platform
    function getBalanceOf(address, address, MatryxPlatform.Data storage data, address cAddress) public view returns (uint256) {
        return data.balanceOf[cAddress];
    }

    /// @dev Return balance of a Commit
    /// @param data        Platform data struct
    /// @param commitHash  Commit hash to get the balance of
    /// @return            Balance of the commit on Platform
    function getCommitBalance(address, address, MatryxPlatform.Data storage data, bytes32 commitHash) public view returns (uint256) {
        return data.commitBalance[commitHash];
    }

    /// @dev Return total number of Tournaments
    /// @param data  Platform data struct
    /// @return      Number of Tournaments on Platform
    function getTournamentCount(address, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.allTournaments.length;
    }

    /// @dev Return total number of Users
    /// @param data  Platform data struct
    /// @return      Number of Users on Platform
    function getUserCount(address, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.allUsers.length;
    }

    /// @dev Return all Tournaments addresses
    /// @param data  Platform data struct
    /// @return      Array of Tournament addresses
    function getTournaments(address, address, MatryxPlatform.Data storage data) public view returns (address[] memory) {
        return data.allTournaments;
    }

    /// @dev Return all Users addresses
    /// @param data  Platform data struct
    /// @return      Array of User addresses
    function getUsers(address, address, MatryxPlatform.Data storage data) public view returns (address[] memory) {
        return data.allUsers;
    }

    /// @dev Withdraw available MTX balance
    /// @param sender  msg.sender to Platform
    /// @param info    Platform info struct
    /// @param data    Platform data struct
    function withdrawBalance(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        uint256 amount = data.balanceOf[sender];
        data.balanceOf[sender] = 0;
        data.totalBalance = data.totalBalance.sub(amount);
        data.users[sender].totalWithdrawn = data.users[sender].totalWithdrawn.add(amount);
        require(IToken(info.token).transfer(sender, amount));
    }

    /// @dev Enter Matryx
    /// @param sender  msg.sender to Platform
    /// @param info    Platform info struct
    /// @param data    Platform data struct
    function enterMatryx(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        require(!data.users[sender].entered, "Already entered Matryx");
        require(!data.users[sender].banned, "User has been banned");
        require(IToken(info.token).balanceOf(sender) > 0, "Must have MTX");

        data.users[sender].entered = true;
        data.users[sender].timeEntered = now;
        data.allUsers.push(sender);
    }

    /// @dev Creates a Tournament
    /// @param sender    msg.sender to Platform
    /// @param info      Platform info struct
    /// @param data      Platform data struct
    /// @param tDetails  Tournament details (title, descHash, fileHash, bounty, entryFee)
    /// @param rDetails  Round details (start, end, review, bounty)
    /// @return          Address of the created Tournament
    function createTournament(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibTournament.TournamentDetails memory tDetails, LibRound.RoundDetails memory rDetails) public returns (address) {
        require(data.users[sender].entered, "Must have entered Matryx");
        require(tDetails.bounty > 0, "Tournament bounty must be greater than 0");
        require(rDetails.bounty <= tDetails.bounty, "Round bounty cannot exceed Tournament bounty");
        require(IToken(info.token).allowance(sender, address(this)) >= tDetails.bounty, "Insufficient MTX");

        uint256 version = IMatryxSystem(info.system).getVersion();
        address tAddress = address(new MatryxTournament(version, info.system));

        IMatryxSystem(info.system).setContractType(tAddress, uint256(LibSystem.ContractType.Tournament));
        data.allTournaments.push(tAddress);

        LibUser.UserData storage user = data.users[sender];
        user.tournaments.push(tAddress);
        user.totalSpent = user.totalSpent.add(tDetails.bounty);

        LibTournament.TournamentData storage tournament = data.tournaments[tAddress];
        tournament.info.version = version;
        tournament.info.owner = sender;
        tournament.details = tDetails;

        data.totalBalance = data.totalBalance.add(tDetails.bounty);
        data.balanceOf[tAddress] = tDetails.bounty;
        require(IToken(info.token).transferFrom(sender, address(this), tDetails.bounty), "Transfer failed");

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

    /// @dev Sets commitDistributionDepth for how many ancestor commits value propagates to
    /// @param sender  msg.sender to Platform 
    /// @param info    Platform info struct
    /// @param data    Platform data struct
    /// @param depth   New commitDistributionDepth
    function setCommitDistributionDepth(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, uint256 depth) public {
        require(sender == info.owner, "Must be Platform owner");
        data.commitDistributionDepth = depth;
    }
}
