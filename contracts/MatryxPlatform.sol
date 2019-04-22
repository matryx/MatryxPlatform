pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./IToken.sol";
import "./MatryxSystem.sol";
import "./LibTournament.sol";

contract MatryxPlatform {
    using SafeMath for uint256;

    struct Info {
        address system;
        address token;
        address owner;
    }

    struct Data {
        uint256 totalBalance;                                        // total allocated mtx balance of the platform
        mapping(address=>uint256) tournamentBalance;                 // maps tournament addresses to tournament balances
        mapping(bytes32=>uint256) commitBalance;                     // maps commit hashes to commit mtx balances

        mapping(address=>LibTournament.TournamentData) tournaments;  // maps tournament addresses to tournament structs
        mapping(bytes32=>LibTournament.SubmissionData) submissions;  // maps submission identifier to submission struct

        address[] allTournaments;                                    // all matryx tournament addresses

        mapping(bytes32=>LibCommit.Commit) commits;                  // maps commit hashes to commits
        mapping(bytes32=>LibCommit.Group) groups;                    // maps group hashes to group structs
        mapping(bytes32=>bytes32) commitHashes;                      // maps content hashes to commit hashes
        mapping(bytes32=>bytes32[]) commitToSubmissions;             // maps commits to submission created from them
        mapping(bytes32=>LibCommit.CommitWithdrawalStats) commitWithdrawalStats; // maps commit hash to withdrawal stats

        bytes32[] initialCommits;                                    // all commits without parents
        mapping(bytes32=>uint256) commitClaims;                      // timestamp of content hash claim

        mapping(address=>bool) whitelist;                            // user whitelist
        mapping(address=>bool) blacklist;                            // user blacklist
    }

    Info info;                                                       // slot 0
    Data data;                                                       // slot 3

    constructor(address system, address token) public {
        info.system = system;
        info.token = token;
        info.owner = msg.sender;
    }

    /// @dev
    /// 1) Uses msg.sender to ask MatryxSystem for the type of library this call should be forwarded to
    /// 2) Uses this library type to lookup (in its own storage) the name of the library
    /// 3) Uses this name to ask MatryxSystem for the address of the contract (under this platform's version)
    /// 4) Uses name and signature to ask MatryxSystem for the data necessary to modify the incoming calldata
    ///    so as to be appropriate for the associated library call
    /// 5) Makes a delegatecall to the library address given by MatryxSystem with the library-appropriate calldata
    function () external {
        uint256 version = IMatryxSystem(info.system).getVersion();
        bytes32 libName = IMatryxSystem(info.system).getLibraryName(msg.sender);
        bool isForwarded = libName != bytes32("LibPlatform");

        assembly {
            if isForwarded {
                calldatacopy(0, 0x24, 0x20)                                     // get injected version from calldata
                version := mload(0)                                             // overwrite version var
            }
        }

        address libAddress = IMatryxSystem(info.system).getContract(version, libName);

        assembly {
            // constants
            let offset := 0x100000000000000000000000000000000000000000000000000000000

            let res
            let ptr := mload(0x40)                                              // scratch space for calldata
            let system := sload(info_slot)                                      // load info.system address

            // get fnData from system
            mstore(ptr, mul(0x3b15aabf, offset))                                // getContractMethod(uint256,bytes32,bytes32)
            mstore(add(ptr, 0x04), version)                                     // arg 0 - version
            mstore(add(ptr, 0x24), libName)                                     // arg 1 - library name
            mstore(add(ptr, 0x44), 0)                                           // zero out uninitialized data
            calldatacopy(add(ptr, 0x44), 0, 0x04)                               // arg 2 - fn selector
            res := call(gas, system, 0, ptr, 0x64, 0, 0)                        // call system.getContractMethod
            returndatacopy(ptr, 0, returndatasize)                              // copy fnData into ptr
            if iszero(res) { revert(ptr, returndatasize) }                      // safety check
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

            if isForwarded {
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
            returndatacopy(ptr, 0, returndatasize)                              // copy return data into ptr for returning

            if iszero(res) { revert(ptr, returndatasize) }                        // safety check
            return(ptr, returndatasize)                                         // return forwarded call returndata
        }
    }

    modifier onlyOwner() {
        require(msg.sender == info.owner, "Must be Platform owner");
        _;
    }

    /// @dev Sets the owner of the platform
    /// @param newOwner  New owner address
    function setPlatformOwner(address newOwner) external onlyOwner {
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
    event TournamentCreated(address tournament, address creator);
    event TournamentUpdated(address tournament);
    event TournamentBountyAdded(address tournament, address donor, uint256 amount);

    event RoundCreated(address tournament, uint256 roundIndex);
    event RoundUpdated(address tournament, uint256 roundIndex);

    event SubmissionCreated(address tournament, bytes32 submissionHash, address creator);
    event SubmissionRewarded(address tournament, bytes32 submissionHash);

    event GroupMemberAdded(bytes32 commitHash, address user);

    event CommitClaimed(bytes32 commitHash);
    event CommitCreated(bytes32 parentHash, bytes32 commitHash, address creator, bool isFork);

    function setPlatformOwner(address newOwner) external;
    function upgradeToken(address token) external;
    function withdrawTokens(address token) external;

    function getInfo() external view returns (MatryxPlatform.Info memory);
    function isTournament(address tournament) external view returns (bool);
    function isCommit(bytes32 commitHash) external view returns (bool);
    function isSubmission(bytes32 submissionHash) external view returns (bool);

    function getTotalBalance() external view returns (uint256);

    function getTournamentCount() external view returns (uint256);
    function getTournaments() external view returns (address[] memory);
    function getSubmission(bytes32 submissionHash) external view returns (LibTournament.SubmissionData memory);

    function blacklist(address user) external;
    function createTournament(LibTournament.TournamentDetails calldata, LibTournament.RoundDetails calldata) external returns (address);
}
