pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/LibConstruction.sol";
import "../libraries/submission/LibSubmission.sol";
import "../libraries/submission/LibSubmissionTrust.sol";

contract JMatryxSubmission {
    address owner;
    address platform;
    address tournament;
    address round;

    LibConstruction.SubmissionData data; // slot 4
    LibSubmission.RewardData rewardData; // slot 13, divisor 15
    LibSubmission.TrustData trustData;
    LibConstruction.ContributorsAndReferences contribsAndRefs;
    LibSubmission.FileDownloadTracking downloadData;

    constructor(address _owner, address _platform, address _tournament, address _round, LibConstruction.SubmissionData _submissionData) public {
        assembly {
            sstore(owner_slot, _owner)                                // _owner
            sstore(platform_slot, _platform)                          // _platform
            sstore(tournament_slot, _tournament)                      // _tournament
            sstore(round_slot, _round)                                // _round

            // copy _submissionData struct to data
            sstore(data_slot, mload(0x100))                           // submisisonData.title[0]
            sstore(add(data_slot, 1), mload(0x120))                   // submisisonData.title[1]
            sstore(add(data_slot, 2), mload(0x140))                   // submisisonData.title[2]
            sstore(add(data_slot, 3), mload(0x160))                   // submisisonData.descriptionHash[0]
            sstore(add(data_slot, 4), mload(0x180))                   // submisisonData.descriptionHash[1]
            sstore(add(data_slot, 5), mload(0x1a0))                   // submisisonData.fileHash[0]
            sstore(add(data_slot, 6), mload(0x1c0))                   // submisisonData.fileHash[1]

            // get current time
            let start := timestamp()
            sstore(add(data_slot, 7), start)                          // submisisonData.timeSubmitted = now
            sstore(add(data_slot, 8), start)                          // submisisonData.timeUpdated = now

            // allow submission owner to view its files
            mstore(0x0, _owner)
            mstore(0x20, downloadData_slot)
            let s_ownerAllowed := keccak256(0x0, 0x40)
            sstore(s_ownerAllowed, 1)                                 // permittedToViewFile[_owner] = true

            let sizeOfAllowed := sload(add(downloadData_slot, 1))
            mstore(0x0, add(downloadData_slot, 1))
            let s_allAllowed := keccak256(0x0, 0x20)                  // downloadData.allPermittedToViewFile
            sstore(add(s_allAllowed, sizeOfAllowed), _owner)          // downloadData.allPermittedToViewFile.push(_owner)
            sizeOfAllowed := add(sizeOfAllowed, 1)

            let sOffset := 0x100000000000000000000000000000000000000000000000000000000
            mstore(0x0, mul(0x893d20e8, sOffset))
            if iszero(call(gas(), _tournament, 0, 0, 0x04, 0, 0x20))  // tournament.getOwner()
            {
                revert(0, 0)
            }
            mstore(0x20, downloadData_slot)

            // allow tournament owner to view submisison files
            let s_tournamentOwnerAllowed := keccak256(0x0, 0x40)
            sstore(s_tournamentOwnerAllowed, 1)                       // allowedToViewFile[tournamentOwner] = true

            sstore(add(s_allAllowed, sizeOfAllowed), mload(0x0))      // downloadData.allPermittedToViewFile.push(_owner)
            sstore(add(downloadData_slot, 1), add(sizeOfAllowed, 1))  // downloadData.allPermittedToViewFile.size += 2
        }
    }

    function () public {
        assembly {
            let sOffset := 0x100000000000000000000000000000000000000000000000000000000
            switch div(calldataload(0), sOffset)

            // case 0x7eba7ba6 { getSlot() }                                  // getSlot(uint256)
            case 0xe76c293e { getTournament() }                            // getTournament()
            case 0x9f8743f7 { getRound() }                                 // getRound()
            case 0xa52dd12f { return32(isAccessible(arg(0), sOffset)) }    // isAccessible(address)
            case 0x3bc5de30 { getData(sOffset) }                           // getData()
            case 0xff3c1a8f { getTitle(sOffset) }                          // getTitle()
            case 0x245edf06 { getDescriptionHash(sOffset) }                // getDescriptionHash()
            case 0x8493f71f { getFileHash(sOffset) }                       // getFileHash()
            case 0x14889e99 { getPermittedDownloaders() }                  // getPermittedDownloaders()
            case 0x7a6337fa { getReferences(sOffset) }                     // getReferences()
            case 0xaf157c19 { getContributors(sOffset) }                   // getContributors()
            case 0xf23e1cb4 { getContributorRewardDistribution(sOffset) }  // getContributorRewardDistribution()
            case 0xae1ca692 { getTimeSubmitted() }                         // getTimeSubmitted()
            case 0x8efa5410 { getTimeUpdated() }                           // getTimeUpdated()
            case 0x9b057610 { getTotalWinnings() }                         // getTotalWinnings()
            case 0xb09103d8 { unlockFile(sOffset) }                        // unlockFile()
            case 0x5de8439f { updateData(sOffset) }                        // updateData((bytes32[3],bytes32[2],bytes32[2]))
            case 0x49ca4d7f { updateContributors(sOffset) }                // updateContributors((address[],uint256[],uint256[]))
            case 0x93d1e712 { updateReferences(sOffset) }                  // updateReferences((address[],uint256[]))
            case 0x09b542bb { addToWinnings(sOffset) }                     // addToWinnings(uint256)
            case 0x32c9c9d3 { flagMissingReference(sOffset) }              // flagMisingReference(address)
            case 0x0cbfdb2d { removeMissingReferenceFlag(sOffset) }        // removeMissingReferenceFlag(address)
            case 0x0a181f52 { setContributorsAndReferences(sOffset) }      // setContributorsAndReferences((address[],uint256[],address[]))
            case 0x12065fe0 { getBalance(sOffset) }                        // getBalance()
            case 0xc885bc58 { withdrawReward(sOffset) }                    // withdrawReward()
            case 0x42849570 { myReward(sOffset) }                          // myReward()

            // Ownable stuff
            case 0x893d20e8 { getOwner() }                                 // getOwner()
            case 0x2f54bf6e { isOwner() }                                  // isOwner(address)
            case 0xf2fde38b { transferOwnership() }                        // transferOwnership(address)

            // Bro why you tryna call a function that doesn't exist?       // ¯\_(ツ)_/¯
            default {                                                      // (╯°□°）╯︵ ┻━┻
                mstore(0, 0xdead)
                log0(0x1e, 0x02)
                mstore(0, calldataload(0))
                log0(0, 0x04)
                return(0, 0x20)
            }

            // ----------------------
            //     Helper Methods
            // ----------------------

            /// @dev Gets nth argument from calldata
            function arg(n) -> a {
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
            function safesub(a, b) -> c {
                require(or(lt(b, a), eq(b, a)))
                c := sub(a, b)
            }

            /// @dev SafeMath addition
            function safeadd(a, b) -> c {
                c := add(a, b)
                require(or(eq(a, c), lt(a, c)))
            }

            function returnDynamicArray(s_array)
            {
                mstore(0, s_array)   // contribsAndRefs.references
                let s_elems := keccak256(0, 0x20)

                // length of dyn array
                let len := sload(s_array)
                let ptr := mload(0x40)
                let ret := ptr

                // size of array elements
                mstore(ptr, 0x20)
                ptr := add(ptr, 0x20)
                // number of elements in array
                mstore(ptr, len)

                // add all references to memory
                for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                    ptr := add(ptr, 0x20)
                    mstore(ptr, sload(add(s_elems, i)))
                }

                // 0x40 for elem size + length
                return(ret, add(0x40, mul(len, 0x20)))
            }

            // -----------------
            //     Modifiers
            // -----------------

            function onlyPlatform() {
                require(eq(sload(platform_slot), caller()))
            }

            function onlyTournament() {
                require(eq(sload(tournament_slot), caller()))
            }

            function onlyOwner() {
                require(eq(sload(owner_slot), caller()))
            }

            function ownerContributorOrRound() {
                mstore(0x0, caller())
                mstore(0x20, add(rewardData_slot, 3))  // rewardData.contributorToBountyDividend
                mstore(0x0, sload(keccak256(0x0, 0x40)))
                require(or(or(eq(sload(owner_slot), caller()), mload(0)), eq(sload(round_slot), caller()))) // require msg.sender == owner or contributor or round
            }

            function onlyHasEnteredMatryx(offset) {
                mstore(0x0, mul(0x7a348ab3, offset))  // hasEnteredMatryx(address)
                mstore(0x04, caller())
                require(call(gas(), sload(platform_slot), 0, 0, 0x24, 0, 0x20))
                require(mload(0x0))
            }

            function atLeastInReview(offset) {
                mstore(0, mul(0x1865c57d, offset))                           // getState()
                require(call(gas(), sload(round_slot), 0, 0, 0x04, 0, 0x20)) // round.getState()
                require(gt(mload(0), 2))                                     // round.state >= InReview
            }

            function whenAccessible(offset) {
                require(isAccessible(caller(), offset))
            }

            function s_callerCanViewFile(offset) -> b {
                mstore(0x0, caller())
                mstore(0x20, downloadData_slot)
                let s_allowed := keccak256(0x0, 0x40)
                b := s_allowed
            }

            function onlySubmissionOrRound(offset) {
                mstore(0, mul(0x8b706ff8, offset))                           // submissionExixts(address)
                mstore(0x04, caller())
                require(call(gas(), sload(round_slot), 0, 0, 0x24, 0, 0x20)) //round.submissionExists(msg.sender)
                let isSubmission := mload(0)
                let isRound := eq(sload(round_slot), caller())
                require(or(isSubmission, isRound))
            }

            function onlyOwnerOrThis() {
                require(or(eq(sload(owner_slot), caller()), eq(address(), caller())))
            }

            function duringOpenSubmission(offset) {
                mstore(0, mul(0x1865c57d, offset))                           // getState()
                require(call(gas(), sload(round_slot), 0, 0, 0x04, 0, 0x20)) // round.getState()
                require(eq(mload(0), 2))                                     // LibEnum.RoundState.Open
            }


            // -----------------
            //     Functions
            // -----------------

            function getTournament() {
                return32(sload(tournament_slot))
            }

            function getRound() {
                return32(sload(round_slot))
            }

            // function isAccessible(address _requester) public view returns (bool)
            function isAccessible(_requester, offset) -> a {
                let platform := sload(platform_slot)
                let round := sload(round_slot)
                let owner := sload(owner_slot)

                a := eq(platform, _requester)                                               // isPlatform
                a := or(a, eq(round, _requester))                                           // isRound
                a := or(a, eq(owner, _requester))                                           // ownsThisSubmission

                let state := 0
                if iszero(a) {
                    mstore(0, mul(0x1865c57d, offset))                                    // getState()
                    require(call(gas(), round, 0, 0, 0x04, 0, 0x20))                      // round.getState
                    state := mload(0)

                    a := or(a, gt(state, 4))                                              // round is Closed or Abandoned
                }

                if iszero(a) {
                    let tournament := sload(tournament_slot)

                    mstore(0, mul(0x52c01fab, offset))                                    // isEntrant(address)
                    mstore(0x04, _requester)
                    require(call(gas(), tournament, 0, 0, 0x24, 0, 0x20))                 // tournament.isEntrant(_requester)
                    let isEntrant := mload(0)

                    mstore(0, mul(0x893d20e8, offset))                                    // getOwner()
                    require(call(gas(), tournament, 0, 0, 0x04, 0, 0x20))                 // tournament.getOwner
                    let ownsTournament := eq(mload(0), _requester)

                    let roundAtLeastInReview := gt(state, 2)                              // after 2, in review (or more)
                    a := or(a, and(roundAtLeastInReview, or(ownsTournament, isEntrant)))  // duringReviewAndRequesterInTournament
                }

                if iszero(a) {
                    mstore(0, mul(0x818b5fa8, offset))                                    // isSubmission(address)
                    mstore(0x04, _requester)
                    require(call(gas(), platform, 0, 0, 0x24, 0, 0x20))                   // platform.isSubmission(caller)
                    a := or(a, mload(0))
                }

                if iszero(a) {
                    mstore(0, _requester)
                    mstore(0x20, downloadData_slot)
                    let access_pos := keccak256(0, 0x40)
                    let access := sload(access_pos)                                       // downloadData.permittedToViewFile[_requester]
                    a := or(a, access)
                }
            }

            function getData(offset) {
                whenAccessible(offset)

                let data := mload(0x40)
                mstore(data, sload(data_slot))                          // data.title[0]
                mstore(add(data, 0x20), sload(add(data_slot, 1)))       // data.title[1]
                mstore(add(data, 0x40), sload(add(data_slot, 2)))       // data.title[2]
                mstore(add(data, 0x60), sload(add(data_slot, 3)))       // data.descriptionHash[0]
                mstore(add(data, 0x80), sload(add(data_slot, 4)))       // data.descriptionHash[1]

                let allowed := sload(s_callerCanViewFile(offset))
                if eq(allowed, 0) {                                     // if(!allowedToViewFile[msg.sender])
                    mstore(add(data, 0xa0), 0)                          // data.fileHash[0]
                    mstore(add(data, 0xc0), 0)                          // data.fileHash[1]
                }
                if eq(allowed, 1) {
                    mstore(add(data, 0xa0), sload(add(data_slot, 5)))   // data.fileHash[0]
                    mstore(add(data, 0xc0), sload(add(data_slot, 6)))   // data.fileHash[1]
                }
                mstore(add(data, 0xe0), sload(add(data_slot, 7)))       // data.timeSubmitted
                mstore(add(data, 0x100), sload(add(data_slot, 8)))      // data.timeUpdated

                return(data, 0x120)
            }

            function getTitle(offset) {
                whenAccessible(offset)

                let title := mload(0x40)
                mstore(title, sload(data_slot))                         // data.title[0]
                mstore(add(title, 0x20), sload(add(data_slot, 1)))      // data.title[1]
                mstore(add(title, 0x40), sload(add(data_slot, 2)))      // data.title[2]

                return(title, 0x60)
            }

            function getDescriptionHash(offset) {
                whenAccessible(offset)

                let description := mload(0x40)
                mstore(description, sload(add(data_slot, 3)))              // data.descriptionHash[0]
                mstore(add(description, 0x20), sload(add(data_slot, 4)))   // data.descriptionHash[1]

                return(description, 0x40)
            }

            function getFileHash(offset) {
                whenAccessible(offset)
                require(sload(s_callerCanViewFile(offset)))


                let file := mload(0x40)
                mstore(file, sload(add(data_slot, 5)))              // data.fileHash[0]
                mstore(add(file, 0x20), sload(add(data_slot, 6)))   // data.fileHash[1]

                return(file, 0x40)
            }

            function getPermittedDownloaders() {
                returnDynamicArray(add(downloadData_slot, 1))
            }

            // function getReferences() public view whenAccessible(msg.sender) returns(address[])
            function getReferences(offset) {
                whenAccessible(offset)
                returnDynamicArray(add(contribsAndRefs_slot, 2))
            }

            // function getContributors() public view whenAccessible(msg.sender) returns(address[])
            function getContributors(offset) {
                whenAccessible(offset)
                returnDynamicArray(contribsAndRefs_slot)
            }

            function getContributorRewardDistribution(offset) {
                whenAccessible(offset)

                let ptr := mload(0x40)
                let len := sload(contribsAndRefs_slot)

                mstore(ptr, 0x20)           // elem size
                mstore(add(ptr, 0x20), len) // arr len

                mstore(0, contribsAndRefs_slot)
                let s_car := keccak256(0, 0x20)

                mstore(0x20, add(rewardData_slot, 3)) // rewardData.contributorToBountyDividend

                for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                    let con := sload(add(s_car, i))
                    mstore(0, con)
                    let dist := keccak256(0, 0x40)    // rewardData.contributorToBountyDividend[contributor]
                    mstore(add(ptr, mul(add(i, 2), 0x20)), sload(dist))
                }

                return(ptr, mul(add(len, 2), 0x20))
            }

            function getTimeSubmitted() {
                return32(sload(add(data_slot, 7))) // data.timeSubmitted
            }

            function getTimeUpdated() {
                return32(sload(add(data_slot, 8))) // data.timeUpdated
            }

            function getTotalWinnings() {
                return32(sload(rewardData_slot))  // rewardData.winnings
            }

            function unlockFile(offset) {
                onlyHasEnteredMatryx(offset)
                atLeastInReview(offset)

                let s_allowed := s_callerCanViewFile(offset)
                if eq(sload(s_allowed), 0) {
                    sstore(s_allowed, 1)
                }

                mstore(0x0, add(downloadData_slot, 1))
                let s_allowedArray := keccak256(0x0, 0x20)
                let size := sload(add(downloadData_slot, 1))
                sstore(add(s_allowedArray, size), caller())
                sstore(add(downloadData_slot, 1), add(size, 1))
            }

            // function updateData(LibConstruction.SubmissionModificationData _modificationData) public onlyOwner duringOpenSubmission
            function updateData(offset) {
                onlyOwner()
                duringOpenSubmission(offset)

                let ptr := mload(0x40)
                // LibSubmission.updateData(LibConstruction.SubmissionData storage,LibConstruction.SubmissionModificationData)
                mstore(ptr, mul(0x92ee1390, offset))
                mstore(add(ptr, 0x04), data_slot)

                // copy _modification data
                calldatacopy(add(ptr, 0x24), 0x04, 0xe0)

                require(delegatecall(gas(), LibSubmission, ptr, 0x104, 0, 0))
            }

            // function updateContributors(LibConstruction.ContributorsModificationData _contributorsModificationData) public onlyOwner duringOpenSubmission
            function updateContributors(offset) {
                onlyOwner()
                duringOpenSubmission(offset)

                let ptr := mload(0x40)
                // LibSubmisison.updateContributors(LibConstruction.SubmissionData storage,LibConstruction.ContributorsAndReferences storage,LibSubmission.RewardData storage,LibSubmission.FileDownloadTracking storage,LibConstruction.ContributorsModificationData)
                mstore(ptr, mul(0x852972b2, offset))
                mstore(add(ptr, 0x04), data_slot)
                mstore(add(ptr, 0x24), contribsAndRefs_slot)
                mstore(add(ptr, 0x44), rewardData_slot)
                mstore(add(ptr, 0x64), downloadData_slot)

                // copy _contributorsModificationData and update location
                let size := sub(calldatasize(), 0x04)
                let m_cmd := add(ptr, 0x84)
                calldatacopy(m_cmd, 0x04, size)
                mstore(m_cmd, add(mload(m_cmd), 0x80))

                require(delegatecall(gas(), LibSubmission, ptr, add(size, 0x84), 0, 0)) // LibSubmission.updateContributors()
            }

            // function updateReferences(LibConstruction.ReferencesModificationData _referencesModificationData) public onlyOwner duringOpenSubmission
            function updateReferences(offset) {
                onlyOwner()
                duringOpenSubmission(offset)

                let ptr := mload(0x40)
                // LibSubmission.updateReferences(address,LibConstruction.SubmissionData storage,LibConstruction.ContributorsAndReferences storage,LibSubmission.TrustData storage,LibConstruction.ReferencesModificationData)
                mstore(ptr, mul(0x2612f55c, offset))
                mstore(add(ptr, 0x04), sload(platform_slot))
                mstore(add(ptr, 0x24), data_slot)
                mstore(add(ptr, 0x44), contribsAndRefs_slot)
                mstore(add(ptr, 0x64), trustData_slot)

                // copy _referencesModificationData and update location
                let size := sub(calldatasize(), 0x04)
                let m_rmd := add(ptr, 0x84)
                calldatacopy(m_rmd, 0x04, size)
                mstore(m_rmd, add(mload(m_rmd), 0x80))

                require(delegatecall(gas(), LibSubmission, ptr, add(size, 0x84), 0, 0))
            }

            // function addToWinnings(uint256 _amount) public onlySubmissionOrRound
            function addToWinnings(offset) {
                onlySubmissionOrRound(offset)

                sstore(rewardData_slot, add(sload(rewardData_slot), arg(0)))
            }

            //  function flagMissingReference(address _reference) public onlyHasEnteredMatryx
            function flagMissingReference(offset) {
                onlyHasEnteredMatryx(offset)
                let ptr := mload(0x40)
                // LibSubmissionTrust.flagMissingReference(LibSubmission.TrustData storage,address)
                mstore(ptr, mul(0x35974e8f, offset))
                mstore(add(ptr,0x04), trustData_slot)
                mstore(add(ptr,0x24), arg(0))
                require(delegatecall(gas(), LibSubmissionTrust, ptr, 0x44, 0, 0))
            }

            //  function removeMissingReferenceFlag(address _reference) public onlyHasEnteredMatryx
            function removeMissingReferenceFlag(offset) {
                onlyHasEnteredMatryx(offset)
                let ptr := mload(0x40)

                // LibSubmissionTrust.flagMissingReference(LibSubmission.TrustData storage,address)
                mstore(ptr, mul(0xb0bba0ff, offset))
                mstore(add(ptr,0x04), trustData_slot)
                mstore(add(ptr,0x24), arg(0))
                require(delegatecall(gas(), LibSubmissionTrust, ptr, 0x44, 0, 0))
            }

            //  function setContributorsAndReferences(LibConstruction.ContributorsAndReferences _contribsAndRefs) public onlyTournament
            function setContributorsAndReferences(offset) {
                onlyTournament()
                let ptr := mload(0x40)

                // LibSubmission.setContributorsAndReferences(LibConstruction.ContributorsAndReferences storage,LibSubmission.RewardData storage,LibSubmission.TrustData storage,LibSubmission.FileDownloadTracking storage,LibConstruction.ContributorsAndReferences)
                mstore(ptr, mul(0x15392d2f, offset))
                mstore(add(ptr, 0x04), contribsAndRefs_slot)
                mstore(add(ptr, 0x24), rewardData_slot)
                mstore(add(ptr, 0x44), trustData_slot)
                mstore(add(ptr, 0x64), downloadData_slot)

                // copy _contribsAndRefs and update location
                let size := sub(calldatasize(), 0x04)
                let m_car := add(ptr, 0x84)
                calldatacopy(m_car, 0x04, size)
                mstore(m_car, add(mload(m_car), 0x80))

                require(delegatecall(gas(), LibSubmission, ptr, add(size, 0x84), 0, 0))
            }

            // function getBalance() public view returns (uint256)
            function getBalance(offset) {
                mstore(0, mul(0xf8b2cb4f, offset)) // getBalance(address)
                mstore(0x04, address())

                // call round.getBalance() and put in 0
                require(call(gas(), sload(round_slot), 0, 0, 0x24, 0, 0x20))
                return(0, 0x20)
            }

            // function withdrawReward() public ownerContributorOrRound
            function withdrawReward(offset) {
                ownerContributorOrRound()

                let ptr := mload(0x40)
                // LibSubmission.withdrawReward(address,LibConstruction.ContributorsAndReferences storage,LibSubmission.RewardData storage,LibSubmission.TrustData storage)
                mstore(ptr, mul(0x36b39c08, offset))
                mstore(add(ptr,0x04), sload(platform_slot))
                mstore(add(ptr,0x24), contribsAndRefs_slot) // Already referring to storage in parameters
                mstore(add(ptr,0x44), rewardData_slot)
                mstore(add(ptr,0x64), trustData_slot)

                require(delegatecall(gas(), LibSubmission, ptr, 0x84, 0, 0))
            }

            // function myReward() public view returns (uint256)
            function myReward(offset) {
                let ptr := mload(0x40)

                // LibSubmisison.getTransferAmount(address,LibSubmission.RewardData storage,LibSubmission.TrustData storage)
                mstore(ptr, mul(0x223c8136, offset))
                mstore(add(ptr, 0x04), sload(platform_slot))
                mstore(add(ptr, 0x24), rewardData_slot)
                mstore(add(ptr, 0x44), trustData_slot)

                require(delegatecall(gas(), LibSubmission, ptr, 0x64, 0, 0x20))
                let amount := mload(0)

                // LibSubmisison._myReward(LibConstruction.ContributorsAndReferences storage,LibSubmission.RewardData storage,address,uint256)
                mstore(ptr, mul(0xbf1053e2, offset))
                mstore(add(ptr, 0x04), contribsAndRefs_slot)
                mstore(add(ptr, 0x24), rewardData_slot)
                mstore(add(ptr, 0x44), caller())
                mstore(add(ptr, 0x64), amount)

                require(delegatecall(gas(), LibSubmission, ptr, 0x84, 0, 0x20))
                return(0, 0x20)
            }

            // Ownable stuffs
            function getOwner() {
                return32(sload(owner_slot))
            }

            function isOwner() {
                let _sender := arg(0)
                return32(eq(sload(owner_slot), _sender))
            }

            /// @dev transferOwnership: transfers ownership to newOwner
            /// @param address newOwner
            function transferOwnership() {
                onlyOwner()
                let _newOwner := arg(0)
                require(_newOwner)
                sstore(owner_slot, _newOwner)
            }
        }
    }
}


interface IJMatryxSubmission {
    // function getSlot(uint256) public view returns (bytes32);
    function getTournament() public view returns (address);
    function getRound() public view returns (address);
    function isAccessible(address _requester) public view returns (bool);
    function getData() public view returns(LibConstruction.SubmissionData _data);
    function getTitle() public view returns(bytes32[3]);
    function getDescriptionHash() public view returns (bytes32[2]);
    function getFileHash() public view returns (bytes32[2]);
    function getPermittedDownloaders() public view returns (address[]);
    function getReferences() public view returns(address[]);
    function getContributors() public view returns(address[]);
    function getContributorRewardDistribution() public view returns (uint256[]);
    function getTimeSubmitted() public view returns(uint256);
    function getTimeUpdated() public view returns(uint256);
    function getTotalWinnings() public view returns(uint256);
    function updateData(LibConstruction.SubmissionModificationData _modificationData) public;
    function updateContributors(LibConstruction.ContributorsModificationData _contributorsModificationData) public;
    function updateReferences(LibConstruction.ReferencesModificationData _referencesModificationData) public;
    function addToWinnings(uint256 _amount) public;
    function flagMissingReference(address _reference) public;
    function removeMissingReferenceFlag(address _reference) public;
    function setContributorsAndReferences(LibConstruction.ContributorsAndReferences _contribsAndRefs) public;
    function getBalance() public view returns (uint256);
    function withdrawReward() public;
    function myReward() public view returns (uint256);

    // Ownable stuffs
    function getOwner() public view returns (address _owner);
    function isOwner(address sender) public view returns (bool _isOwner);
    function transferOwnership(address newOwner) public;
}
