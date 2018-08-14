pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "../libraries/LibConstruction.sol";
import "../libraries/round/LibRound.sol";
import "../libraries/tournament/LibTournamentAdminMethods.sol";
import "../interfaces/factories/IMatryxSubmissionFactory.sol";

contract JMatryxRound {
    address public platform;
    address public tournament;
    address public submissionFactory;

    LibConstruction.RoundData data;
    LibRound.SelectWinnersData winningSubmissionsData;
    LibRound.SubmissionsData submissionsData;
    LibRound.SubmissionAndEntrantTracking trackingData;

    constructor (address _platform, address _tournament, address _submissionFactory, LibConstruction.RoundData _roundData) public {
        assembly {
            sstore(platform_slot, _platform)                   // _platform
            sstore(tournament_slot, _tournament)               // _tournament
            sstore(submissionFactory_slot, _submissionFactory) // _submissionFactory

            // copy roundData struct to data, except last one roundData.closed
            for { let i := 0 } lt(i, 4) { i := add(i, 1) } {
                sstore(add(data_slot, i), mload(add(_roundData, mul(0x20, i))))
            }
        }
    }

    function () public {
        assembly {
            let sOffset := 0x100000000000000000000000000000000000000000000000000000000
            switch div(calldataload(0), sOffset)

            // case 0x7eba7ba6 { getSlot() }                              // getSlot(uint256)

            case 0xb6a34975 { submissionExists(sOffset) }              // submissionExists(address)
            case 0x38e43895 { addBounty() }                            // addBounty(uint256)
            case 0x1865c57d { return32(getState(sOffset)) }            // getState()
            case 0x2fc1f190 { getPlatform() }                          // getPlatform()
            case 0xe76c293e { getTournament() }                        // getTournament()
            case 0x3bc5de30 { getData() }                              // getData()
            case 0xc828371e { getStartTime() }                         // getStartTime()
            case 0x439f5ac2 { getEndTime() }                           // getEndTime()
            case 0x7bc935be { getReviewPeriodDuration() }              // getReviewPeriodDuration()
            case 0xf49bff7b { getBounty() }                            // getBounty()
            case 0xe45ceed2 { return32(getRemainingBounty(sOffset)) }  // getRemainingBounty()
            case 0x10fe9ae8 { return32(getTokenAddress(sOffset)) }     // getTokenAddress()
            case 0x54f6aa20 { getSubmissions() }                       // getSubmissions()
            case 0xf8b2cb4f { return32(getBalance(sOffset, arg(0))) }  // getBalance(address)
            case 0xe9e8b446 { getRoundBalance(sOffset) }               // getRoundBalance()
            case 0x389994f9 { submissionsChosen() }                    // submissionsChosen()
            case 0xed098460 { getWinningSubmissionAddresses() }        // getWinningSubmissionAddresses()
            case 0x241b15ad { return32(numberOfSubmissions()) }        // numberOfSubmissions()
            case 0x8fa4e7b9 { editRound(sOffset) }                     // editRound(uint256,(uint256,uint256,uint256,uint256,bool))
            case 0x2f0713bb { transferToTournament(sOffset) }          // transferToTournament(uint256)
            case 0x856646fd { selectWinningSubmissions(sOffset) }      // selectWinningSubmissions((address[],uint256[],uint256,uint256),(uint256,uint256,uint256,uint256,bool))
            case 0x07417cf1 { transferBountyToTournament(sOffset) }    // transferBountyToTournament()
            case 0x5325cdba { transferAllToWinners(sOffset) }          // transferAllToWinners(uint256)
            case 0x0e3db9f2 { startNow() }                             // startNow()
            case 0xe278fe6f { closeRound(sOffset) }                    // closeRound()
            case 0x57c60fb0 { createSubmission(sOffset) }              // createSubmission(address,address,(bytes32[3],bytes32[2],bytes32[2],uint256,uint256))

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
            function arg(n)->a {
                a := calldataload(add(0x04, mul(n, 0x20)))
            }

            // function getSlot() {
            //     return32(sload(arg(0)))
            // }

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
            function safesub(a, b)->c {
                require(or(lt(b, a), eq(b, a)))
                c := sub(a, b)
            }

            /// @dev SafeMath addition
            function safeadd(a, b)->c {
                c := add(a, b)
                require(or(eq(a, c), lt(a, c)))
            }

            // -----------------
            //     Modifiers
            // -----------------

            function duringOpenRound(offset) {
                let s := getState(offset)
                require(eq(s, 2)) // LibEnum.RoundState.Open
            }

            function duringReviewPeriod(offset) {
                let s := getState(offset)
                require(eq(s, 3)) // LibEnum.RoundState.InReview
            }

            function hasWinners(offset) {
                let s := getState(offset)
                require(eq(s, 4)) // LibEnum.RoundState.HasWinners
            }

            function onlyTournament() {
                require(eq(sload(tournament_slot), caller()))
            }

            // -----------------
            //     Functions
            // -----------------

            // function submissionExists(address _submissionAddress) public returns (bool)
            function submissionExists(submission) {
                mstore(0x0, arg(0))
                mstore(0x20, add(trackingData_slot,1))
                mstore(0x0, sload(keccak256(0x0, 0x40)))
                return(0x0, 0x20)
            }

            // function addBounty(uint256 _mtxAllocation) public onlyTournament
            function addBounty() {
                onlyTournament()

                let amount := arg(0)
                let bounty := sload(add(data_slot, 3)) // data.bounty
                bounty := safeadd(bounty, amount)      // safe add to bounty
                sstore(add(data_slot, 3), bounty)      // store back in data
            }

            // function getState() public view returns (uint256)
            function getState(offset)->s {
                let ptr := mload(0x40)
                // getState(address,LibConstruction.RoundData storage, LibRound.SelectWinnersData storage,LibRound.SubmissionsData storage)
                mstore(ptr, mul(0x05b00ec1, offset))
                mstore(add(ptr, 0x04), sload(platform_slot))
                mstore(add(ptr, 0x24), data_slot)
                mstore(add(ptr, 0x44), winningSubmissionsData_slot)
                mstore(add(ptr, 0x64), submissionsData_slot)

                require(delegatecall(gas(), LibRound, ptr, 0x84, 0x0, 0x20))
                s := mload(0x0)
            }

            // function getPlatform() public view returns (address)
            function getPlatform() {
                return32(sload(platform_slot))
            }

            // function getTournament() public view returns (address)
            function getTournament() {
                return32(sload(tournament_slot))
            }

            // function getData() public view returns (LibConstruction.RoundData _roundData);
            function getData() {
                let ptr := mload(0x40)
                mstore(ptr, sload(data_slot))                    // start
                mstore(add(ptr, 0x20), sload(add(data_slot, 1))) // end
                mstore(add(ptr, 0x40), sload(add(data_slot, 2))) // reviewPeriodDuration
                mstore(add(ptr, 0x60), sload(add(data_slot, 3))) // bounty
                mstore(add(ptr, 0x80), sload(add(data_slot, 4))) // closed
                return(ptr, 0xa0)
            }

            // function getStartTime() public view returns (uint256)
            function getStartTime() {
                return32(sload(data_slot))          // data.start
            }

            // function getEndTime() public view returns (uint256)
            function getEndTime() {
                return32(sload(add(data_slot, 1)))  // data.end
            }

            // function getReviewPeriodDuration() public view returns (uint256)
            function getReviewPeriodDuration() {
                return32(sload(add(data_slot, 2)))  // data.reviewPeriodDuration
            }

            // function getBounty() public view returns (uint256)
            function getBounty() {
                return32(sload(add(data_slot, 3)))  // data.bounty
            }

            // function getRemainingBounty() public view returns (uint256)
            function getRemainingBounty(offset)->r {
                r := getBalance(offset, address())
            }

            // getTokenAddress() public view returns (address _matryxTokenAddress)
            function getTokenAddress(offset)->token {
                mstore(0, mul(0x10fe9ae8, offset)) // getTokenAddress()

                // call platform.getTokenAddress and put in 0
                require(call(gas(), sload(platform_slot), 0, 0, 0x04, 0, 0x20))
                token := mload(0)
            }

            // function getSubmissions() public view returns (address[] _submissions)
            function getSubmissions() {
                mstore(0, submissionsData_slot)         // submissionsData.submissions
                let submissions := keccak256(0, 0x20)

                // length of dyn array
                let len := sload(submissionsData_slot)
                let ptr := mload(0x40)
                let ret := ptr

                // size of array elements
                mstore(ptr, 0x20)
                ptr := add(ptr, 0x20)
                // number of elements in array
                mstore(ptr, len)

                // add all winning submissions to memory
                for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                    ptr := add(ptr, 0x20)
                    mstore(ptr, sload(add(submissions, i)))
                }

                // 0x40 for elem size + length
                return(ret, add(0x40, mul(len, 0x20)))
            }

            // function getBalance(address _submissionAddress) public view returns (uint256)
            function getBalance(offset, account)->b {
                let token := getTokenAddress(offset)
                mstore(0x0, mul(0x70a08231, offset)) // balanceOf(address)
                mstore(0x04, account)
                require(call(gas(), token, 0, 0x0, 0x24, 0x0, 0x20))
                b := mload(0x0)
            }

            // function getRoundBalance() public view returns (uint256)
            function getRoundBalance(offset) {
                return32(getBalance(offset, address()))
            }

            // function submissionsChosen() public view returns (bool)
            function submissionsChosen() {
                return32(gt(sload(winningSubmissionsData_slot), 0)) // winningSubmissionsData.winningSubmissions
            }

            // getWinningSubmissionAddresses() public view returns (address[] _winningSubmissions)
            function getWinningSubmissionAddresses() {
                mstore(0, winningSubmissionsData_slot)  // winningSubmisisonsData.winningSubmissions
                let winningSubmissions := keccak256(0, 0x20)

                // length of dyn array
                let len := sload(winningSubmissionsData_slot)
                let ptr := mload(0x40)
                let ret := ptr

                // size of array elements
                mstore(ptr, 0x20)
                ptr := add(ptr, 0x20)
                // number of elements in array
                mstore(ptr, len)

                // add all winning submissions to memory
                for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                    ptr := add(ptr, 0x20)
                    mstore(ptr, sload(add(winningSubmissions, i)))
                }
                // 0x40 for elem size + length
                return(ret, add(0x40, mul(len, 0x20)))
            }

            // function numberOfSubmissions() public view returns (uint256)
            function numberOfSubmissions()->n {
                n := sload(submissionsData_slot) // submissionsData.submissions
            }

            // function editRound(uint256 _currentRoundEndTime, LibConstruction.RoundData _roundData) public onlyTournament
            function editRound(offset) {
                onlyTournament()

                let ptr := mload(0x40)
                // editRound(LibConstruction.RoundData storage,uint256,LibConstruction.RoundData)
                mstore(ptr, mul(0xb6668750, offset))
                mstore(add(ptr, 0x04), sload(data_slot))
                mstore(add(ptr, 0x24), arg(0))   // _currentRoundEndTime

                //copy _roundData
                calldatacopy(add(ptr, 0x44), 0x24, 0xa0)

                require(delegatecall(gas(), LibRound, ptr, 0xe4, 0, 0))
            }

            // function transferToTournament(uint256 _amount) public onlyTournament
            function transferToTournament(offset) {
                onlyTournament()

                require(eq(getState(offset), 0))      // getState () == LibEnums.RoundState.NotYetOpen

                let ptr := mload(0x40)
                mstore(ptr, mul(0xa9059cbb, offset))  // transfer(address,uint256)
                mstore(add(ptr, 0x04), caller())      // msg.sender
                mstore(add(ptr, 0x24), arg(0))        // _amount

                // call Token.transfer
                require(call(gas(), getTokenAddress(offset), 0, ptr, 0x44, 0, 0))
            }

            // function selectWinningSubmissions(LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData) public onlyTournament duringReviewPeriod
            function selectWinningSubmissions(offset) {
                onlyTournament()
                duringReviewPeriod(offset)

                let ptr := mload(0x40)
                mstore(ptr, mul(0x6e86d662, offset))                            // selectWinningSubmissions(LibConstruction.RoundData storage,LibRound.SelectWinnersData storage,LibRound.SelectWinnersData,LibConstruction.RoundData)
                mstore(add(ptr, 0x04), data_slot)                               // data
                mstore(add(ptr, 0x24), winningSubmissionsData_slot)             // winningSubmissionData

                let size := sub(calldatasize(), 0x04)
                calldatacopy(add(ptr, 0x44), 0x04, size)                        // _selectWinnersData, _roundData

                // update selectWinnersData location
                let swd_mem := add(ptr, 0x44)
                mstore(swd_mem, add(mload(swd_mem), 0x40))

                require(delegatecall(gas(), LibRound, ptr, add(0x44, size), 0, 0))
            }

            // function transferBountyToTournament() public onlyTournament returns (uint256)
            function transferBountyToTournament(offset) {
                onlyTournament()

                let remBounty := getRemainingBounty(offset)
                let ptr := mload(0x40)

                mstore(ptr, mul(0xa9059cbb, offset))            // transfer(address,uint256)
                mstore(add(ptr, 0x04), sload(tournament_slot))  // tournamentAddress
                mstore(add(ptr, 0x24), remBounty)               // remainingBounty

                require(call(gas(), getTokenAddress(offset), 0, ptr, 0x44, 0, 0)) // token.transfer(tournamentAddress, remBounty)
                return32(remBounty)
            }

            // function transferAllToWinners(uint256 _tournamentBalance) public onlyTournament
            function transferAllToWinners(offset) {
                onlyTournament()

                let ptr := mload(0x40)
                let token := getTokenAddress(offset)

                let wsl := sload(winningSubmissionsData_slot)   // winningSubmissionsData.winningSubmissions
                mstore(0, winningSubmissionsData_slot)          // winningSubmissionsData.winningSubmissions
                let s_subs := keccak256(0, 0x20)
                mstore(0, add(winningSubmissionsData_slot, 1))  // winningSubmissionsData.rewardDistribution
                let s_dist := keccak256(0, 0x20)

                let totalDist := sload(add(winningSubmissionsData_slot, 3)) // winningSubmissionsData.rewardDistributionTotal
                totalDist := mul(totalDist, 0xde0b6b3a7640000)              // *1e18
                let totalBal := add(sload(add(data_slot, 3)), arg(0))       // data.bounty
                totalBal := mul(totalBal, 0xde0b6b3a7640000)                // *1e18

                for { let i := 0 } lt(i, wsl) { i := add(i, 1) } {
                    let winner := sload(add(s_subs, i))
                    let reward := div(mul(sload(add(s_dist, i)), totalBal), totalDist)

                    mstore(ptr, mul(0xa9059cbb, offset))             // transfer(address,uint256)
                    mstore(add(ptr, 0x04), winner)
                    mstore(add(ptr, 0x24), reward)
                    // call token.transfer(winner, reward)
                    require(call(gas(), token, 0, ptr, 0x44, 0, 0))

                    mstore(ptr, mul(0x09b542bb, offset))             // addToWinnings(uint256)
                    mstore(add(ptr, 0x04), reward)
                    // call winner.addToWinnings(reward)
                    require(call(gas(), winner, 0, ptr, 0x24, 0, 0))
                }
            }

            // function startNow() public onlyTournament
            function startNow() {
                onlyTournament()

                let dur := safesub(sload(data_slot), sload(add(data_slot, 1)))  // data.end - data.start
                let start := timestamp()

                sstore(data_slot, start)                    // data.start = now
                sstore(add(data_slot, 1), add(start, dur))  // data.end = data.start + dur
            }

            // function closeRound() public onlyTournament hasWinners
            function closeRound(offset) {
                onlyTournament()
                hasWinners(offset)

                sstore(add(data_slot, 4), 1)  // data.closed = true
            }

            // function createSubmission(address _owner, address platformAddress, LibConstruction.SubmissionData submissionData) public onlyTournament duringOpenRound returns (address _submissionAddress)
            function createSubmission(offset) {
                onlyTournament()
                duringOpenRound(offset)

                let owner := arg(0)
                require(owner)

                let ptr := mload(0x40)
                // createSubmission(address,address,address,address,LibConstruction.SubmissionData)
                mstore(ptr, mul(0x6c4074f7, offset))
                mstore(add(ptr, 0x04), owner)                   // owner
                mstore(add(ptr, 0x24), arg(1))                  // platformAddress
                mstore(add(ptr, 0x44), sload(tournament_slot))  // tournamentAddress
                mstore(add(ptr, 0x64), address())               // roundAddress

                // copy submission data
                calldatacopy(add(ptr, 0x84), 0x44, 0x120) // 0x120 = 9 words

                // call SubmissionFactory.createSubmission
                require(call(gas(), sload(submissionFactory_slot), 0, ptr, 0x1a4, 0, 0x20))
                let a_sub := mload(0)

                // trackingData.submissionExists = true
                mstore(0, a_sub)
                mstore(0x20, add(trackingData_slot, 1))
                sstore(keccak256(0, 0x40), 1)

                // submissionsData.submissions.push(sub)
                mstore(0, submissionsData_slot)
                let s_subs := keccak256(0, 0x20)
                let len := sload(submissionsData_slot)
                sstore(submissionsData_slot, add(len, 1)) // increment num submissions
                sstore(add(s_subs, len), a_sub)           // add sub to submissionsData.submissions

                // TODO: Change to 'authors.push' once MatryxPeer is part of MatryxPlatform

                // trackingData.authorToSubmissionAddress
                mstore(0x0, owner)
                mstore(0x20, trackingData_slot)
                let s_authorSubsLen := keccak256(0x0, 0x40)
                let authorSubsLen := sload(s_authorSubsLen)

                mstore(0, s_authorSubsLen)
                let s_authorSubs := keccak256(0, 0x20)

                // if author not there, submissionsData.submissionOwners.push(author)
                if iszero(authorSubsLen) {
                    // submissionsData.submissionOwners.push(owner)
                    let s_subOwnersLen := add(submissionsData_slot, 1) // slot for submissionsData.submissionOwners
                    let subOwnersLen := sload(s_subOwnersLen)

                    mstore(0, s_subOwnersLen)
                    let s_subOwners := keccak256(0, 0x20)

                    sstore(s_subOwnersLen, add(subOwnersLen, 1))    // increment num submissionOwners
                    sstore(add(s_subOwners, subOwnersLen), owner)  // add owner to submissionOwners
                }

                // trackingData.authorToSubmissionAddress[submissionAuthor].push(submissionAddress);
                sstore(s_authorSubsLen, add(authorSubsLen, 1))   // increment num authorToSubmissionAddress[author]
                sstore(add(s_authorSubs, authorSubsLen), a_sub)  // add sub to authorToSubmissionAddress[author]

                // IMatryxTournament(tournamentAddress).invokeSubmissionCreatedEvent(submissionAddress);
                return32(a_sub)
            }
        }
    }
}

interface IJMatryxRound {
    function submissionExists(address _submissionAddress) public view returns (bool);
    function addBounty(uint256 _mtxAllocation) public;
    function getState() public view returns (uint256);
    function getPlatform() public view returns (address);
    function getTournament() public view returns (address);
    function getData() public view returns (LibConstruction.RoundData _roundData);
    function getStartTime() public view returns (uint256);
    function getEndTime() public view returns (uint256);
    function getReviewPeriodDuration() public view returns (uint256);
    function getBounty() public view returns (uint256);
    function getRemainingBounty() public view returns (uint256);
    function getTokenAddress() public view returns (address);
    function getSubmissions() public view returns (address[] _submissions);
    function getBalance(address _submissionAddress) public view returns (uint256);
    function getRoundBalance() public view returns (uint256);
    function submissionsChosen() public view returns (bool);
    function getWinningSubmissionAddresses() public view returns (address[]);
    function numberOfSubmissions() public view returns (uint256);
    function editRound(uint256 _currentRoundEndTime, LibConstruction.RoundData _roundData) public;
    function transferToTournament(uint256 _amount) public;
    function selectWinningSubmissions(LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData) public;
    function transferBountyToTournament() public returns (uint256);
    function transferAllToWinners(uint256 _tournamentBalance) public;
    function startNow() public;
    function closeRound() public;
    function createSubmission(address _owner, address platformAddress, LibConstruction.SubmissionData submissionData) public returns (address _submissionAddress);
}
