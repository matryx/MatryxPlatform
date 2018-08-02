pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "../libraries/LibConstruction.sol";
import "../libraries/round/LibRound.sol";


contract JMatryxRound {
    address public owner;
    address public platform;
    address public tournament;
    address public submissionFactory;

    mapping(bytes32=>address) private contracts;    

    LibConstruction.RoundData data;
    LibRound.SelectWinnersData winningSubmissionsData;
    LibRound.SubmissionsData submissionsData;
    LibRound.SubmissionAndEntrantTracking submissionEntrantTrackingData;

    constructor (address _owner, address _platform, address _tournament, address _submissionFactory, LibConstruction.RoundData _roundData) public {
        assembly {
            sstore(owner_slot, mload(0x80))             // _owner
            sstore(platform_slot, mload(0xa0))          // _platform
            sstore(tournament_slot, mload(0xc0))        // _tournament
            sstore(submissionFactory_slot, mload(0xe0)) // _submissionFactory
            sstore(data_slot, mload(0x100))             // _roundData.start
            sstore(add(data_slot, 1), mload(0x120))     // _roundData.end
            sstore(add(data_slot, 2), mload(0x140))     // _roundData.reviewPeriodDuration
            sstore(add(data_slot, 3), mload(0x160))     // _roundData.bounty
            sstore(add(data_slot, 4), mload(0x180))     // _roundData.closed

            // bytes32 tournamentAdminLibHash = keccak256("LibTournamentAdminMethods");
            // contracts[tournamentAdminLibHash] = IMatryxRoundFactory(msg.sender).getContractAddress(tournamentAdminLibHash);
            // mstore(0, 0x4c6962546f75726e616d656e7441646d696e4d6574686f647300000000000000)
            // figure out better way to store Lib addresses for upgrade process
        }
    }

    function () public {
        assembly {
            let sigOffset := 0x100000000000000000000000000000000000000000000000000000000
            switch div(calldataload(0), sigOffset)

            // Bro why you tryna call a function that doesn't exist?  // ¯\_(ツ)_/¯
            default {                                                 // (╯°□°）╯︵ ┻━┻
                mstore(0, 0xdead)
                log0(0x1e, 0x02)
                mstore(0, calldataload(0))
                log0(0, 0x04)
                return(0, 0x20)
            }

            // Helper Methods
            // -------------------------------
            /// @dev Gets nth argument from calldata
            function arg(n) -> a {
                a := calldataload(add(0x04, mul(n, 0x20)))
            }

            /// @dev Stores the word v in memory and returns
            function return32(v) {
                mstore(0, v)
                return(0, 0x20)
            }

            /// @dev Reverts when v == 0
            function require(v) {
                if iszero(v) { revert(0, 0) }
            }

            /// @dev SafeMath subtraction
            function safesub(a, b) -> c {
                require(or(lt(b, a), eq(b, a)))
                c := sub(a, b)
            }

            /// @dev SafeMath addition
            function safeadd(a, b) -> c {
                c := add(a, b)
                require(or(eq(a, c), lt(a, c)))
            }

            // -----------------
            //    Modifiers
            // -----------------

            // modifier duringOpenRound()
            // modifier duringReviewPeriod()
            // modifier onlyTournament()
            // modifier onlyTournamentOrLib()


            // -----------------
            //    Functions
            // -----------------

            /*
                function submissionExists(address _submissionAddress) public returns (bool)
                function addBounty(uint256 _mtxAllocation) public onlyTournamentOrLib
                function setContractAddress(bytes32 _nameHash, address _contractAddress) public onlyOwner
                function getContractAddress(bytes32 _nameHash) public returns (address contractAddress)
                function getState() public view returns (uint256)
                function getPlatform() public view returns (address)
                function getTournament() public view returns (address)
                function getStartTime() public view returns (uint256)
                function getEndTime() public view returns (uint256)
                function getBounty() public view returns (uint256)
                function remainingBounty() public view returns (uint256)
                function getTokenAddress() public view returns (address)
                function getSubmissions() public view returns (address[] _submissions)
                function getBalance(address _submissionAddress) public view returns (uint256)
                function getRoundBalance() public view returns (uint256)
                function submissionsChosen() public view returns (bool)
                function getWinningSubmissionAddresses() public view returns (address[])
                function numberOfSubmissions() public view returns (uint256)
                function scheduleStart(LibConstruction.RoundData _roundData) internal
                function editRound(uint256 _currentRoundEndTime, LibConstruction.RoundData _roundData) public onlyTournament
                function transferToTournament(uint256 _amount) public onlyTournament
                function selectWinningSubmissions(LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData) public onlyTournamentOrLib duringReviewPeriod
                function transferBountyToTournament() public onlyTournament returns (uint256)
                function transferAllToWinners(uint256 _tournamentBalance) public onlyTournament
                function startNow() public onlyTournament
                function closeRound() public onlyTournament
                function createSubmission(address _owner, address platformAddress, LibConstruction.SubmissionData submissionData) public onlyTournamentOrLib duringOpenRound returns (address _submissionAddress)
            */
        }
    }
}
