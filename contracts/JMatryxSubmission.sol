pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../libraries/math/SafeMath.sol";
import "../libraries/math/SafeMath128.sol";
import "../libraries/strings/strings.sol";
import "../libraries/LibConstruction.sol";
import "../libraries/submission/LibSubmission.sol";

contract JMatryxSubmisison {
    address owner;
    address platform;
    address tournament;
    address round;

    LibConstruction.SubmissionData data;
    LibSubmission.RewardData rewardData;
    LibSubmission.TrustData trustData;
    LibConstruction.ContributorsAndReferences contribsAndRefs;

    constructor(address _owner, address _platform, address _tournament, address _round, LibConstruction.SubmissionData _submissionData) public {
        assembly {
            sstore(owner_slot, _owner)                      // _owner
            sstore(platform_slot, _platform)                // _platform
            sstore(tournament_slot, _tournament)            // _tournament
            sstore(round_slot, _round)                      // _round

            //copy _submissionData struct to data
            sstore(data_slot, mload(0x100))                 // submisisonData.title[0]
            sstore(add(data_slot, 1), mload(0x120))         // submisisonData.title[1]
            sstore(add(data_slot, 2), mload(0x140))         // submisisonData.title[2]
            sstore(add(data_slot, 3), mload(0x160))         // submisisonData.descriptionHash[0]
            sstore(add(data_slot, 4), mload(0x180))         // submisisonData.descriptionHash[1]
            sstore(add(data_slot, 5), mload(0x1a0))         // submisisonData.fileHash[0]
            sstore(add(data_slot, 6), mload(0x1c0))         // submisisonData.fileHash[1]

            let start := timestamp()
            sstore(add(data_slot, 7), mload(start))         // submisisonData.timeSubmitted = now
            sstore(add(data_slot, 8), mload(start))         // submisisonData.timeUpdated = now
        }
    }

    function () public {
        assembly {
            let sOffset := 0x100000000000000000000000000000000000000000000000000000000
            switch div(calldataload(0), sOffset)

            // case 0x7eba7ba6 { getSlot() }                          // getSlot(uint256)
            case 0xe76c293e { getTournament() }                       // getTournament()
            case 0x9f8743f7 { getRound() }                            // getRound()
            //case 0xa52dd12f { isAccessible() }                        // isAccessible(address)
            case 0x3bc5de30 { getData() }                             // getData()
            case 0xff3c1a8f { getTitle() }                            // getTitle()
            case 0xa5faa125 { getAuthor() }                           // getAuthor()
            case 0x245edf06 { getDescriptionHash() }                  // getDescriptionHash()
            case 0x8493f71f { getFileHash() }                         // getFileHash()
            case 0x7a6337fa { getReferences() }                       // getReferences()
            case 0xaf157c19 { getContributors() }                     // getContributors()
            case 0xae1ca692 { getTimeSubmitted() }                    // getTimeSubitted()
            case 0x9b057610 { getTotalWinnings() }                    // getTotalWinnings()
            case 0x56bc86d2 { updateData(sOffset) }                   // updateData(bytes32[3],bytes32[2],bytes32[2])
            case 0xe727e43e { updateContributors(sOffset) }           // updateContributors(address[],uint128[],address[])
            case 0x3287c22f { updateReferences(sOffset) }             // updateReferences(address[],address[])
            case 0x09b542bb { addToWinnings() }                       // addToWinnings(uint256)
            case 0x0fb3395c { addReference(sOffset) }                 // addReference(address)
            case 0x9fb86a87 { addReferences(sOffset) }                // addReference(address[])
            case 0x23bab50b { removeReference(sOffset) }                     // removeReference(address)
            case 0xc7af3551 { receiveReferenceRequest() }             // receiveReferenceRequest()
            case 0x444e31ca { cancelReferenceRequest(sOffset) }              // cancelReferenceRequest()
            case 0xe7139ec0 { approveReference(sOffset) }                    // approveReference(address)
            case 0xe4e3e83a { removeReferenceApproval(sOffset) }             // removeReferenceApproval(address)
            case 0x32c9c9d3 { flagMissingReference(sOffset) }                // flagMisingReference(address)
            case 0x0cbfdb2d { removeMissingReferenceFlag(sOffset) }          // removeMissingReferenceFlag(address)
            case 0x65795c6e { setContributorsAndReferences(sOffset) }        // setContributorsAndReferences(address[],uint128[],address[])
            case 0xf889b6d4 { addContributor(sOffset)}                       // addContributor(address,uint128)
            case 0x6948f406 { addContributors(sOffset) }                     // addContributors(address[],uint128[])
            case 0x74756091 { removeContributor(sOffset) }                   // removeContributor(uint256)
            case 0xbeda86b9 { removeContributors(sOffset) }                  // removeContributors(uint256[])
            case 0x12065fe0 { getBalance(sOffset) }                   // getBalance()
            case 0xc885bc58 { withdrawReward(sOffset) }               // withdrawReward()
            case 0x42849570 { myReward(sOffset) }                     // myReward()

            // Ownable stuff
            case 0x893d20e8 { getOwner() }                            // getOwner()
            case 0x2f54bf6e { isOwner() }                             // isOwner(address)
            case 0xf2fde38b { transferOwnership() }                   // transferOwnership(address)

            // Bro why you tryna call a function that doesn't exist?  // ¯\_(ツ)_/¯
            default {                                                 // (╯°□°）╯︵ ┻━┻
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

            // -----------------
            //     Modifiers
            // -----------------

            function onlyPlatform() {
                require(eq(sload(platform_slot), caller()))
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

            function onlyPeer(offset) {
                //TODO
                mstore(0, mul(0x3e44cf78, offset)) // MatryxPlatform.isPeer
                mstore(0x04, caller())
                require(call(gas(), sload(platform_slot), 0, 0, 0x24, 0, 0x20))
            }

            function whenAccessible() {
                //require(isAccessible(caller()))
            }

            function onlySubmissionOrRound() {
                //TODO
            }

            function onlyOwnerOrThis() {
                require(or(eq(sload(owner_slot), caller()), eq(address(), caller())))
            }

            function duringOpenSubmission() {
                //TODO
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

            //TODO
            //function isAccessible(address _requester) public view returns (bool)

            function getData() {
                whenAccessible()

                let data := mload(0x40)
                mstore(data, data_slot)                            // data.title[0]
                mstore(add(data, 0x20), sload(add(data_slot, 1)))  // data.title[1]
                mstore(add(data, 0x40), sload(add(data_slot, 2)))  // data.title[2]
                mstore(add(data, 0x60), sload(add(data_slot, 3)))  // data.descriptionHash[0]
                mstore(add(data, 0x80), sload(add(data_slot, 4)))  // data.descriptionHash[1]
                mstore(add(data, 0xa0), sload(add(data_slot, 5)))  // data.fileHash[0]
                mstore(add(data, 0xc0), sload(add(data_slot, 6)))  // data.fileHash[1]
                mstore(add(data, 0xe0), sload(add(data_slot, 7)))  // data.timeSubmitted
                mstore(add(data, 0x100), sload(add(data_slot, 8))) // data.timeUpdated

                return(data, 0x120)
            }

            function getTitle() {
                whenAccessible()

                let title := mload(0x40)
                mstore(title, data_slot)                            // data.title[0]
                mstore(add(title, 0x20), sload(add(data_slot, 1)))  // data.title[1]
                mstore(add(title, 0x40), sload(add(data_slot, 2)))  // data.title[2]

                return(title, 0x60)
            }

            function getAuthor() {
                whenAccessible()

                //TODO
                //author = IMatryxPlatform(platformAddress).peerAddress(_owner);
                //require(author != 0x0);
            }

            function getDescriptionHash() {
                whenAccessible()

                let description := mload(0x40)
                mstore(description, sload(add(data_slot, 3)))   //data.descriptionHash[0]
                mstore(description, sload(add(data_slot, 4)))   //data.descriptionHash[1]

                return(description, 0x40)
            }

            function getFileHash() {
                whenAccessible()

                let file := mload(0x40)
                mstore(file, sload(add(data_slot, 5)))   //data.fileHash[0]
                mstore(file, sload(add(data_slot, 6)))   //data.fileHash[1]

                return(file, 0x40)

            }

            // function getReferences() public view whenAccessible(msg.sender) returns(address[])
            function getReferences() {
                whenAccessible()

                mstore(0, add(contribsAndRefs_slot, 2))   // contribsAndRefs.references
                let refs := keccak256(0, 0x20)

                // length of dyn array
                let len := sload(add(contribsAndRefs_slot, 2))
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
                    mstore(ptr, sload(add(refs, i)))
                }

                // 0x40 for elem size + length
                return(ret, add(0x40, mul(len, 0x20)))
            }

            // function getContributors() public view whenAccessible(msg.sender) returns(address[])
            function getContributors() {
                whenAccessible()

                mstore(0, contribsAndRefs_slot)   // contribsAndRefs.contributors
                let contribs := keccak256(0, 0x20)

                // length of dyn array
                let len := sload(contribsAndRefs_slot)
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
                    mstore(ptr, sload(add(contribs, i)))
                }

                // 0x40 for elem size + length
                return(ret, add(0x40, mul(len, 0x20)))
            }

            function getTimeSubmitted() {
                return32(sload(add(data_slot, 7))) // data.timeSubmitted
            }

            function getTotalWinnings() {
                return32(sload(rewardData_slot))  // rewardData.winnings
            }

            // function updateData(LibConstruction.SubmissionModificationData _modificationData) public onlyOwner duringOpenSubmission
            function updateData(offset) {
                onlyOwner()
                duringOpenSubmission()

                let ptr := mload(0x40)
                //LibSubmission.updateData(LibConstruction.SubmissionData storage, LibConstruction.SubmissionModificationData)
                mstore(ptr, mul(0xc3734f8b, offset))
                mstore(add(ptr, 0x04), sload(data_slot))

                //copy _modification data
                calldatacopy(add(ptr, 0x24), 0x04, 0xe0)

                require(delegatecall(gas(), LibSubmission, ptr, 0x104, 0, 0))
            }

            // function updateContributors(LibConstruction.ContributorsModificationData _contributorsModificationData) public onlyOwner duringOpenSubmission
            function updateContributors(offset) {
                onlyOwner()
                //duringOpenSubmisison()

                let ptr := mload(0x40)
                //LibSubmisison.updateContributors(LibConstruction.SubmissionData storage, LibConstruction.ContributorsAndReferences storage, LibSubmission.RewardData storage, LibConstruction.ContributorsModificationData)
                mstore(ptr, mul(0xba97bbc6, offset))
                mstore(add(ptr, 0x04), sload(data_slot))
                mstore(add(ptr, 0x24), sload(contribsAndRefs_slot))
                mstore(add(ptr, 0x44), sload(rewardData_slot))

                //copy _contributorsModificationData
                calldatacopy(add(ptr, 0x64), 0x04, 0x60)

                require(delegatecall(gas(), LibSubmission, ptr, 0xc4, 0, 0))
            }

            // function updateReferences(LibConstruction.ReferencesModificationData _referencesModificationData) public onlyOwner duringOpenSubmission
            function updateReferences(offset) {
                onlyOwner()
                //duringOpenSubmission()

                let ptr := mload(0x40)
                //LibSubmisison.updateReferences(LibConstruction.SubmissionData storage,LibConstruction.ContributorsAndReferences storage,LibSubmission.TrustData storage,LibConstruction.ReferencesModificationData,address)
                mstore(ptr, mul(0x71bb6261, offset))
                mstore(add(ptr, 0x04), sload(data_slot))
                mstore(add(ptr, 0x24), sload(contribsAndRefs_slot))
                mstore(add(ptr, 0x44), sload(trustData_slot))

                //copy _referencesModificationData
                calldatacopy(add(ptr, 0x64), 0x04, 0x40)

                require(delegatecall(gas(), LibSubmission, ptr, 0xa4, 0, 0))
            }

            // function addToWinnings(uint256 _amount) public onlySubmissionOrRound
            function addToWinnings() {
                sstore(rewardData_slot, add(sload(rewardData_slot), arg(0)))
            }

            // function addReference(address _reference) public onlyOwner
            function addReference(offset) {
                onlyOwner()

                let ptr := mload(0x40)
                //LibSubmisisonTrust.addReference(LibConstruction.ContributorsAndReferences storage,LibSubmission.TrustData storage,address,address)
                mstore(ptr, mul(0xcb1602d7, offset))
                mstore(add(ptr, 0x04), sload(contribsAndRefs_slot))
                mstore(add(ptr, 0x24), sload(trustData_slot))
                mstore(add(ptr, 0x44), arg(0)) //_reference
                mstore(add(ptr, 0x64), sload(platform_slot))

                require(delegatecall(gas(), LibSubmissionTrust, ptr, 0x84, 0, 0))
            }

            // function addReferences(address[] _references) public onlyOwner
            function addReferences(offset) {
                onlyOwner()

                let ptr := mload(0x40)
                // LibSubmisisonTrust.addReferences(LibConstruction.SubmissionData storage,LibConstruction.ContributorsAndReferences storage,LibSubmission.TrustData storage,address[],address)
                mstore(ptr, mul(0xcf6cea4b, offset))
                mstore(add(ptr, 0x04), sload(platform_slot))
                mstore(add(ptr, 0x24), sload(data_slot))
                mstore(add(ptr, 0x44), sload(contribsAndRefs_slot))
                mstore(add(ptr, 0x64), sload(trustData_slot))
                //store references[]
                let size := sub(calldatasize(), 0x04)
                calldatacopy(add(ptr, 0x84), 0x04, size)

                require(delegatecall(gas(), LibSubmissionTrust, ptr, add(size, 0x84), 0, 0))
            }

            // function removeReference(address _reference) onlyOwner public
            function removeReference(offset) {
                onlyOwner()

                let ptr := mload(0x40)
                //LibSubmissionTrust.removeReference(LibConstruction.ContributorsAndReferences storage,LibSubmission.TrustData storage,address,address)
                mstore(ptr, mul(0xaf9d1a40, offset))
                mstore(add(ptr, 0x04), sload(contribsAndRefs_slot))
                mstore(add(ptr, 0x24), sload(trustData_slot))
                mstore(add(ptr, 0x44), arg(0)) //_reference
                mstore(add(ptr, 0x64), sload(platform_slot))

                require(delegatecall(gas(), LibSubmissionTrust, ptr, 0x84, 0, 0))
            }

            // function receiveReferenceRequest() public onlyPlatform
            function receiveReferenceRequest() {
                onlyPlatform()
                sstore(add(trustData_slot,3), add(sload(trustData_slot),1))
            }

            // function cancelReferenceRequest() public onlyPlatform
            function cancelReferenceRequest(offset) {
                onlyPlatform()
                sstore(add(trustData_slot,3), sub(sload(trustData_slot),1))
            }

            // function approveReference(address _reference) public onlyPeer
            function approveReference(offset) {
                onlyPeer(offset)

                let ptr := mload(0x40)
                //LibSubmissionTrust.approveReference(LibSubmission.TrustData storage,address)
                mstore(ptr, mul(0xed357c94, offset))
                mstore(add(ptr, 0x04), sload(trustData_slot))
                mstore(add(ptr, 0x24), arg(0)) // _reference

                require(delegatecall(gas(), LibSubmissionTrust, ptr, 0x44, 0, 0))
            }

            // function removeReferenceApproval(address _reference) public onlyPeer
            function removeReferenceApproval(offset) {
                onlyPeer(offset)

                let ptr := mload(0x40)
                // LibSubmissionTrust.removeReferenceApproval(LibSubmission.TrustData storage,address)
                mstore(ptr, mul(0xf5d78738,offset))
                mstore(add(ptr, 0x04), sload(trustData_slot))
                mstore(add(ptr, 0x24), arg(0)) // _reference
                require(delegatecall(gas(), LibSubmissionTrust, ptr, 0x44, 0, 0))
            }

            //  function flagMissingReference(address _reference) public onlyPeer
            function flagMissingReference(offset) {
                onlyPeer(offset)

                let ptr := mload(0x40)
                // LibSubmissionTrust.flagMissingReference(LibSubmission.TrustData storage,address)
                mstore(ptr, mul(0x35974e8f, offset))
                mstore(add(ptr,0x04), sload(trustData_slot))
                mstore(add(ptr,0x24), arg(0))
                require(delegatecall(gas(), LibSubmissionTrust, ptr, 0x44, 0, 0))
            }

            //  function removeMissingReferenceFlag(address _reference) public onlyPeer
            function removeMissingReferenceFlag(offset) {
                onlyPeer(offset)
                let ptr := mload(0x40)
                // LibSubmissionTrust.flagMissingReference(LibSubmission.TrustData storage,address)
                mstore(ptr, mul(0xb0bba0ff, offset))
                mstore(add(ptr,0x04), sload(trustData_slot))
                mstore(add(ptr,0x24), arg(0))
                require(delegatecall(gas(), LibSubmissionTrust, ptr, 0x44, 0, 0))
            }

            //  function setContributorsAndReferences(LibConstruction.ContributorsAndReferences _contribsAndRefs) public // onlyOwner? add appropriate modifier
            function setContributorsAndReferences(offset) {
                let ptr := mload(0x40)
                // LibSubmissionTrust.flagMissingReference(LibSubmission.TrustData storage,address)
                mstore(ptr, mul(0xb376fecb, offset))
                mstore(add(ptr,0x04), sload(contribsAndRefs_slot))
                mstore(add(ptr,0x24), sload(rewardData_slot))
                mstore(add(ptr,0x44), sload(trustData_slot))
                calldatacopy(add(ptr,0x64), 0x04, 0x60)
                require(delegatecall(gas(), LibSubmission, ptr, 0xc4, 0, 0))
            }

            //  function addContributor(address _contributor, uint128 _bountyAllocation) public onlyOwner
            function addContributor(offset) {
                onlyOwner()
                let ptr := mload(0x40)

                //contributorsAndReferences.contributors.push(_contributor);
                mstore(0, contribsAndRefs_slot)
                let s_subs := keccak256(0, 0x20)
                let len := sload(contribsAndRefs_slot)
                sstore(contribsAndRefs_slot, add(len, 1)) // increment num submissions
                sstore(add(s_subs, len), arg(0))

                //rewardData.contributorToBountyDividend[_contributor] = _bountyAllocation;
                mstore(0x0, arg(0))
                mstore(0x20, add(rewardData_slot,3))
                sstore(keccak256(0x0,0x40), arg(1))

                //rewardData.contributorBountyDivisor = rewardData.contributorBountyDivisor.add(_bountyAllocation);
                mstore(0x0, add(rewardData_slot,2))
                sstore(add(rewardData_slot, 2), add(sload(add(rewardData_slot, 2)), 1))
            }

            // function addContributors(address[] _contributorsToAdd, uint128[] _distribution) public onlyOwner
            function addContributors(offset) {
                onlyOwner()
                let ptr := mload(0x40)
                mstore(ptr, mul(0x06121c69,offset))
                mstore(add(ptr,0x04), arg(0))
                mstore(add(ptr,0x24), arg(1))
                require(delegatecall(gas(), LibSubmission, ptr, 0x44, 0, 0))
            }

            //function removeContributor(uint256 _contributorIndex) public onlyOwner {
            function removeContributor(offset) {
                onlyOwner()

                mstore(0x0, arg(0))
                mstore(0x20, contribsAndRefs_slot)
                let s_contrib := keccak256(0x0, 0x40)
                let contrib := sload(s_contrib) // contributor at index
                mstore(0x0, contrib)
                mstore(0x20, add(rewardData_slot, 3)) // RewardData.contributorToBountyDividend
                let s_dividend := keccak256(0x0, 0x40)
                let dividend := sload(s_dividend)
                sstore(add(rewardData_slot, 2), sub(sload(add(rewardData_slot, 2)), dividend)) // RewardData.contributorToBountyDivisor

                sstore(s_dividend, 0)
                sstore(s_contrib, 0)
            }

            //function removeContributors(address[] _contributorsToRemove) public onlyOwner
            function removeContributors(offset) {
                onlyOwner()

                let len:= arg(1) //array length
                for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                    let contrib := calldataload(add(0x04, add(arg(0), mul(0x20, i)))) // arg(0) is offset of _contribs... in bytes
                    mstore(0x0, contrib)
                    mstore(0x20, add(rewardData_slot, 3)) // RewardData.contributorToBountyDividend
                    let s_dividend := keccak256(0x0, 0x40)
                    let dividend := sload(s_dividend)
                    sstore(add(rewardData_slot, 2), sub(sload(add(rewardData_slot, 2)), dividend)) // RewardData.contributorToBountyDivisor

                    sstore(s_dividend, 0)
                }
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
                mstore(add(ptr,0x24), sload(contribsAndRefs_slot))
                mstore(add(ptr,0x44), sload(rewardData_slot))
                mstore(add(ptr,0x64), sload(trustData_slot))

                require(delegatecall(gas(), LibSubmission, ptr, 0x84, 0, 0))
            }

            // function myReward() public view returns (uint256)
            function myReward(offset) {
                let ptr := mload(0x40)

                // LibSubmisison.getTransferAmount(address,LibSubmission.RewardData storage,LibSubmission.TrustData storage)
                mstore(ptr, mul(0x223c8136, offset))
                mstore(add(ptr,0x04), sload(platform_slot))
                mstore(add(ptr,0x24), sload(rewardData_slot))
                mstore(add(ptr,0x44), sload(trustData_slot))

                require(delegatecall(gas(), LibSubmission, ptr, 0x64, 0, 0x20))
                let amount := mload(0)

                // LibSubmisison._myReward(LibConstruction.ContributorsAndReferences storage,LibSubmission.RewardData storage,address,uint256)
                mstore(ptr, mul(0xbf1053e2, offset))
                mstore(add(ptr,0x04), sload(contribsAndRefs_slot))
                mstore(add(ptr,0x24), sload(rewardData_slot))
                mstore(add(ptr,0x24), caller())
                mstore(add(ptr,0x64), amount)

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
                let _newOwner := arg(0)
                require(eq(sload(owner_slot), caller()))
                require(_newOwner)
                sstore(owner_slot, _newOwner)
            }
        }
    }
}


interface IJMatryxSubmission {
    function getTournament() public view returns (address);
    function getRound() public view returns (address);
    function isAccessible(address _requester) public view returns (bool);
    function getData() public view returns(LibConstruction.SubmissionData _data);
    function getTitle() public view returns(bytes32[3]);
    function getAuthor() public view returns(address);
    function getDescriptionHash() public view returns (bytes32[2]);
    function getFileHash() public view returns (bytes32[2]);
    function getReferences() public view returns(address[]);
    function getContributors() public view returns(address[]);
    function getTimeSubmitted() public view returns(uint256);
    function getTotalWinnings() public view returns(uint256);
    function updateData(LibConstruction.SubmissionModificationData _modificationData) public;
    function updateContributors(LibConstruction.ContributorsModificationData _contributorsModificationData) public;
    function updateReferences(LibConstruction.ReferencesModificationData _referencesModificationData) public;
    function addToWinnings(uint256 _amount) public;
    function addReference(address _reference) public;
    function addReferences(address[] _references) public;
    function removeReference(address _reference) public;
    function receiveReferenceRequest() public;
    function cancelReferenceRequest() public;
    function approveReference(address _reference) public;
    function removeReferenceApproval(address _reference) public;
    function flagMissingReference(address _reference) public;
    function removeMissingReferenceFlag(address _reference) public;
    function setContributorsAndReferences(LibConstruction.ContributorsAndReferences _contribsAndRefs) public;
    function addContributor(address _contributor, uint128 _bountyAllocation) public;
    function addContributors(address[] _contributorsToAdd, uint128[] _distribution) public;
    function removeContributor(uint256 _contributorIndex) public;
    function removeContributors(address[] _contributorsToRemove) public;
    function getBalance() public view returns (uint256);
    function withdrawReward() public;
    function myReward() public view returns (uint256);

    // Ownable stuffs
    function getOwner() public view returns (address _owner);
    function isOwner(address sender) public view returns (bool _isOwner);
    function transferOwnership(address newOwner) public view;
}