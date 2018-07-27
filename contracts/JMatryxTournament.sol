pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "../libraries/LibConstruction.sol";
import "../libraries/tournament/LibTournamentStateManagement.sol";
import "../libraries/tournament/LibTournamentAdminMethods.sol";
import "../libraries/tournament/LibTournamentEntrantMethods.sol";


contract JMatryxTournament {
    address owner;
    address platform;
    address roundFactory;
    LibConstruction.TournamentData data;
    LibTournamentStateManagement.StateData stateData;
    LibTournamentStateManagement.EntryData entryData;

    constructor (address _owner, address _platform, address _roundFactory, LibConstruction.TournamentData tournamentData, LibConstruction.RoundData roundData) public {
        assembly {
            if iszero(mload(0xc0)) { revert(0, 0) }         // require(_roundFactory != 0x0)
            if iszero(mload(0x80)) { revert(0, 0) }         // require(owner != 0x0)
            if iszero(mload(0x100)) { revert(0, 0) }        // require(tournamentData.title[0] != 0x0)
            if iszero(gt(mload(0x1e0), 0)) { revert(0, 0) } // require(tournamentData.initialBounty > 0)

            sstore(owner_slot, mload(0x80))                 // _owner
            sstore(platform_slot, mload(0xa0))              // _platform
            sstore(roundFactory_slot, mload(0xc0))          // _roundFactory
            sstore(data_slot, mload(0xe0))                  // tournamentData.category
            sstore(add(data_slot, 1), mload(0x100))         // tournamentData.title[0]
            sstore(add(data_slot, 2), mload(0x120))         // tournamentData.title[1]
            sstore(add(data_slot, 3), mload(0x140))         // tournamentData.title[2]
            sstore(add(data_slot, 4), mload(0x160))         // tournamentData.descriptionHash[0]
            sstore(add(data_slot, 5), mload(0x180))         // tournamentData.descriptionHash[1]
            sstore(add(data_slot, 6), mload(0x1a0))         // tournamentData.fileHash[0]
            sstore(add(data_slot, 7), mload(0x1c0))         // tournamentData.fileHash[1]
            sstore(add(data_slot, 8), mload(0x1e0))         // tournamentData.initialBounty
            sstore(add(data_slot, 9), mload(0x200))         // tournamentData.entryFee

            // create round

            // getTokenAddress first
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let sig := mul(0x10fe9ae8, offset) // getTokenAddress()
            let ptr := mload(0x40)
            mstore(ptr, sig)

            // call platform getTokenAddress() and put in ptr
            let res := call(gas(), mload(0xa0), 0, ptr, 0x04, ptr, 0x20)
            if iszero(res) { revert (0, 0) }

            let token := mload(ptr)
            sig := mul(0xcfa037dc, offset)        // createRound(LibTournamentStateManagement.StateData storage,address,address,address,LibConstruction.RoundData,bool)
            mstore(ptr, sig)
            mstore(add(ptr, 0x04), stateData_slot)
            mstore(add(ptr, 0x24), mload(0xa0))   // platform
            mstore(add(ptr, 0x44), token)
            mstore(add(ptr, 0x64), mload(0xc0))   // roundFactory
            mstore(add(ptr, 0x84), mload(0x220))  // roundData.start
            mstore(add(ptr, 0xa4), mload(0x240))  // roundData.end
            mstore(add(ptr, 0xc4), mload(0x260))  // roundData.reviewPeriodDuration
            mstore(add(ptr, 0xe4), mload(0x280))  // roundData.bounty
            mstore(add(ptr, 0x104), mload(0x2a0)) // roundData.closed
            mstore(add(ptr, 0x124), 0)

            // call createRound
            res := delegatecall(gas(), LibTournamentAdminMethods, ptr, 0x144, ptr, 0x20)
            if iszero(res) { revert(0, 0) }
        }
    }

// Modifiers
// -------------
    // modifier onlyOwner() {
    //     assembly {
    //         require(eq(sload(owner_slot), caller()))
    //     }
    //     _;
    // }

    // modifier onlyPlatform() {
    //     assembly {
    //         require(eq(sload(platform_slot), caller()))
    //     }
    //     _;
    // }

    // modifier platformOrOwner() {
    //     assembly {
    //         require(or(eq(sload(platform_slot), caller()), eq(sload(owner_slot), caller())))
    //     }
    //     _;
    // }

    // onlyRound()
    // onlyPeerLinked(address _sender)
    // onlyEntrant()
    // whileTournamentOpen()
    // ifRoundHasFunds()

// -------------

    function() public {
        assembly {
            let sigOffset := 0x100000000000000000000000000000000000000000000000000000000
            switch div(calldataload(0), sigOffset)

            // Tournament stuffs
            case 0x7eba7ba6 { getSlot() }                             // getSlot(uint256)
            case 0x2fc1f190 { getPlatform() }                         // getPlatform()
            case 0x10fe9ae8 { return32(getTokenAddress(sigOffset)) }  // getTokenAddress()

            case 0x4644c51b {} // TODO invokeSubmissionCreatedEvent

            // Tournament data
            case 0x52c01fab { return32(isEntrant()) }                 // isEntrant(address)
            case 0x8c1fc0bb { return32(isRound()) }                   // getData()
            case 0x8a19c8bc { return(currentRound(sigOffset), 0x40) } // currentRound()
            case 0x80258e47 { getCategory() }                         // getCategory()
            case 0xff3c1a8f { getTitle() }                            // getTitle()
            case 0x245edf06 { getDescriptionHash() }                  // getDescriptionHash()
            case 0x8493f71f { getFileHash() }                         // getFileHash()
            case 0xf49bff7b { return32(getBounty(sigOffset)) }        // getBounty()
            case 0x12065fe0 { return32(getBalance(sigOffset)) }       // getBalance()
            case 0xe586a4f0 { getEntryFee() }                         // getEntryFee()

            // Tournament stateData
            case 0x6ec02be9 { submissionCount() }                     // submissionCount()
            case 0x89f3beb6 { entrantCount() }                        // entrantCount()
            case 0xd60561ce { update(sigOffset) }                     // isRound(address)
            case 0x6984d070 { getRounds() }                           // getRounds()
            case 0x1865c57d { return32(getState(sigOffset)) }         // getState()
            case 0x3bc5de30 { getData() }                             // update((bytes32,bytes32[3],bytes32[2],bytes32[2],uint256,bool)))
            case 0xbe999705 { addFunds(sigOffset) }                   // addFunds(uint256)
            case 0xc2f897bf { jumpToNextRound(sigOffset) }            // jumpToNextRound()
            case 0x9baec207 { stopTournament(sigOffset) }             // stopTournament()
            case 0xe42b8c0a { createSubmission(sigOffset) }           // createSubmission((bytes32[3],bytes32[2],bytes32[2],uint256,uint256),(address[],uint128[],address[])

            // Ownable stuffs
            case 0x893d20e8 { getOwner() }                            // getOwner()
            case 0x2f54bf6e { isOwner() }                             // isOwner(address)
            case 0xf2fde38b { transferOwnership() }                   // transferOwnership(address)

            // Bro why you tryna call a function that doesn't exist?  // ¯\_(ツ)_/¯
            default {                                                 // (╯°□°）╯︵ ┻━┻
                let ptr := mload(0x40)
                let sig := or(mul(div(calldataload(0), sigOffset), sigOffset), 0xdead)
                mstore(ptr, sig)
                log0(ptr, 0x20)
                // let size := calldatasize()
                // calldatacopy(ptr, 0, size)
                // log0(ptr, size)
                return(ptr, 0x20)
            }

            // helper methods
            // --------------------------------
            function arg(n) -> a {
                a := calldataload(add(0x04, mul(n, 0x20)))
            }

            function return32(v) {
                mstore(0, v)
                return(0, 0x20)
            }

            function require(v) {
                if iszero(v) { revert(0, 0) }
            }

            /// @dev getSlot
            /// @param uint256 slot
            function getSlot() {
                let slot := arg(0)
                return32(sload(slot))
            }

            // --------------------------------
            function getPlatform() {
                return32(sload(platform_slot))
            }

            function getTokenAddress(offset) -> token {
                let ptr := 0x0
                mstore(ptr, mul(0x10fe9ae8, offset)) // getTokenAddress()

                // call platform.getTokenAddress and put in ptr
                require(call(gas(), sload(platform_slot), 0, ptr, 0x04, ptr, 0x20))

                token := mload(ptr)
            }

            // Tournament data
            /// @dev Returns bool of if address is entrant of tournament
            function isEntrant() -> isEnt {
                let _address := arg(0)
                mstore(0, _address)
                // entryData.addressToEntryFeePaid
                mstore(0x20, add(entryData_slot, 4))
                isEnt := sload(keccak256(0, 0x40))
            }

            /// @dev Returns bool indicating whether _address corresponds to an existing round or not
            function isRound() -> isRnd {
                let _address := arg(0)
                mstore(0, _address)
                // stateData.isRound
                mstore(0x20, add(stateData_slot, 1))
                isRnd := sload(keccak256(0, 0x40))
            }

            /// @dev Returns list of round addresses in the tournament
            function getRounds() {
                // first stateData item is rounds
                mstore(0, stateData_slot)
                let rounds := keccak256(0, 0x20)

                // len of dyn arrays stored in slot
                let len := sload(stateData_slot)
                let ptr := mload(0x40)
                let ret := ptr

                // sizeof array elements
                mstore(ptr, 0x20)
                ptr := add(ptr, 0x20)

                // number elements
                mstore(ptr, len)

                // loop through arr and put elems in mem
                for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                    ptr := add(ptr, 0x20)
                    mstore(ptr, sload(add(rounds, i)))
                }

                // 0x40 for elem size + len
                return(ret, add(0x40, mul(len, 0x20)))
            }

            function getState(offset) -> state {
                let ptr := 0x0

                // getState(LibTournamentStateManagement.StateData storage)
                mstore(ptr, mul(0x5726b16f, offset))
                mstore(add(ptr, 0x04), stateData_slot)

                // call LibTournamentStateManagement.getState
                require(delegatecall(gas(), LibTournamentStateManagement, ptr, 0x24, ptr, 0x20))

                state := mload(ptr)
            }

            function getData() {
                let data := mload(0x40)
                mstore(data, data_slot)                            // tournamentData.category
                mstore(add(data, 0x20), sload(add(data_slot, 1)))  // tournamentData.title[0]
                mstore(add(data, 0x40), sload(add(data_slot, 2)))  // tournamentData.title[1]
                mstore(add(data, 0x60), sload(add(data_slot, 3)))  // tournamentData.title[2]
                mstore(add(data, 0x80), sload(add(data_slot, 4)))  // tournamentData.descriptionHash[0]
                mstore(add(data, 0xa0), sload(add(data_slot, 5)))  // tournamentData.descriptionHash[1]
                mstore(add(data, 0xc0), sload(add(data_slot, 6)))  // tournamentData.fileHash[0]
                mstore(add(data, 0xe0), sload(add(data_slot, 7)))  // tournamentData.fileHash[1]
                mstore(add(data, 0x100), sload(add(data_slot, 8))) // tournamentData.initialBounty
                mstore(add(data, 0x120), sload(add(data_slot, 9))) // tournamentData.entryFee
                return(data, 0x140)
            }

            function getCategory() {
                // first data item is category
                return32(sload(data_slot))
            }

            /// @dev getTitle: returns title in a byte array of size 3
            function getTitle() {
                let title := mload(0x40)
                mstore(title, sload(add(data_slot, 1)))            // data.title[0]
                mstore(add(title, 0x20), sload(add(data_slot, 2))) // data.title[1]
                mstore(add(title, 0x40), sload(add(data_slot, 3))) // data.title[2]
                return(title, 0x60)
            }

            /// @dev getTitle: returns description in a byte array of size 2
            function getDescriptionHash() {
                let desc := mload(0x40)
                mstore(desc, sload(7))              // data.descriptionHash[0]
                mstore(add(desc, 0x20), sload(8))   // data.descriptionHash[1]
                return(desc, 0x40)
            }

            /// @dev getTitle: returns files in a byte array of size 2
            function getFileHash() {
                let file := mload(0x40)
                mstore(file, sload(9))              // data.fileHash[0]
                mstore(add(file, 0x20), sload(10))  // data.fileHash[1]
                return(file, 0x40)
            }

            /// @dev getBounty: returns the current tournament bounty
            function getBounty(offset) -> bounty {
                // .add(stateData.roundBountyAllocation)
                bounty := add(getBalance(offset), sload(add(stateData_slot, 3)))
            }

            /// @dev getBalance: returns the current tournament balance
            function getBalance(offset) -> bal {
                let tokenAddress := getTokenAddress(offset)
                let ptr := 0x0

                mstore(ptr, mul(0x70a08231, offset)) // balanceOf(address)
                mstore(add(ptr, 0x04), address())

                // call token balanceOf(this) and put in ptr
                require(call(gas(), tokenAddress, 0, ptr, 0x24, ptr, 0x20))

                // .sub(stateData.entryFeesTotal)
                bal := sub(mload(ptr), sload(add(stateData_slot, 2)))
            }

            function getEntryFee() {
                return32(sload(12))
            }

            function currentRound(offset) -> m_currentRound {
                let ptr := 0x0

                // currentRound(LibTournamentStateManagement.StateData storage)
                mstore(ptr, mul(0x0386922b, offset))
                mstore(add(ptr, 0x04), stateData_slot)

                require(delegatecall(gas(), LibTournamentStateManagement, ptr, 0x24, ptr, 0x40))

                m_currentRound := ptr
            }

            // function mySubmissions() {}

            function submissionCount() {
                return32(sload(add(entryData_slot, 1))) //entryData.numberOfSubmissions
            }

            function entrantCount() {
                return32(sload(add(entryData_slot, 5))) //entryData.numberOfEntrants
            }

            function update(offset) {
                let ptr := mload(0x40)
                let mem := ptr

                // update(LibConstruction.TournamentData storage,LibConstruction.TournamentModificationData,address)
                mstore(ptr, mul(0xb43475ff, offset))
                mstore(add(ptr, 0x04), data_slot)
                ptr := add(ptr, 0x24)

                for { let i := 0 } lt(i, 10) { i := add(i, 1) } {
                    mstore(ptr, arg(i))
                    ptr := add(ptr, 0x20)
                }

                ptr := add(ptr, 0x140)

                mstore(ptr, sload(platform_slot))
                require(delegatecall(gas(), LibTournamentAdminMethods, mem, 0x184, 0x0, 0x20))
            }

            function addFunds(offset) {
                let fundsToAdd := arg(0)
                let state := getState(offset)
                // LibEnums.TournamentState state 0 NotYetOpen, 1 Open, 2 OnHold
                require(or(or(eq(state, 0), eq(state, 1)), eq(state, 2)))

                let ptr := mload(0x40)
                mstore(ptr, mul(0x23b872dd, offset)) // transferFrom(address,address,uint256)
                mstore(add(ptr, 0x04), origin())
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), fundsToAdd)
                let token := getTokenAddress(offset)
                require(call(gas(), token, 0, ptr, 0x64, 0, 0x20))
            }

            // function selectWinners
            // function editGhostRound
            // function allocateMoreToRound

            function jumpToNextRound(offset) {
                let ptr := mload(0x40)

                // jumpToNextRound(LibTournamentStateManagement.StateData storage
                mstore(ptr, mul(0xaf410949, offset))
                mstore(add(ptr, 0x04), stateData_slot)
                require(delegatecall(gas(), LibTournamentAdminMethods, ptr, 0x24, 0, 0x20))
            }

            function stopTournament(offset)
            {
                let ptr := mload(0x40)
                let token := getTokenAddress(offset)

                // stopTournament(LibTournamentStateManagement.StateData storage,address,address)
                mstore(ptr, mul(0xa91d59d6, offset))
                mstore(add(ptr, 0x04), data_slot)
                mstore(add(ptr, 0x24), sload(platform_slot))
                mstore(add(ptr, 0x44), token)

                require(delegatecall(gas(), LibTournamentAdminMethods, ptr, 0x64, 0, 0))
            }

            function createRound(_roundData, _automaticCreation, offset) -> round {
                let token := getTokenAddress(offset)
                let ptr := mload(0x40)

                // createRound(LibTournamentStateManagement.StateData storage,address,address,address,LibConstruction.RoundData,bool)
                mstore(ptr, mul(0xcfa037dc, offset))
                mstore(add(ptr, 0x04), stateData_slot)
                mstore(add(ptr, 0x24), sload(platform_slot))
                mstore(add(ptr, 0x44), token)
                mstore(add(ptr, 0x64), sload(roundFactory_slot))
                mstore(add(ptr, 0x84), _roundData)
                mstore(add(ptr, 0xa4), _automaticCreation)

                require(delegatecall(gas(), LibTournamentAdminMethods, ptr, 0xc4, ptr, 0x20))

                round := mload(ptr)
            }

            // function sendBountyToRound(_roundIndex, _bountyMTX)
            // function enterUserInTournament(_entrantAddress)
            // function collectMyEntryFee()

            // function createSubmission(LibConstruction.SubmissionData submissionData, LibConstruction.ContributorsAndReferences contribsAndRefs)
            function createSubmission(offset) {
                // get currentRound address
                let round := mload(add(currentRound(offset), 0x20))

                let ptr := mload(0x40)
                let ret := ptr

                // createSubmission(address,address,LibTournamentStateManagement.EntryData storage,LibConstruction.SubmissionData)
                mstore(ptr, mul(0x09d1ebd0, offset))
                mstore(add(ptr, 0x04), sload(platform_slot))
                mstore(add(ptr, 0x24), round)
                mstore(add(ptr, 0x44), entryData_slot)

                // load in submissionData struct
                calldatacopy(add(ptr, 0x064), 0x04, 0x120)

                // call LibTournamentEntrantMethods.createSubmission and get new submission address
                require(delegatecall(gas(), LibTournamentEntrantMethods, ptr, 0x184, ret, 0x20))

                // add contributors and references
                let car_ptr := add(0x04, arg(9))                    // contribsAndRefs position in calldata
                let clen_offset := calldataload(car_ptr)            // offset of contributors.length
                let dlen_offset := calldataload(add(car_ptr, 0x20)) // offset of contributorRewardDist.length
                let rlen_offset := calldataload(add(car_ptr, 0x40)) // offset of references.length

                let clen := calldataload(add(car_ptr, clen_offset)) // contribsAndRefs.contributors
                let dlen := calldataload(add(car_ptr, dlen_offset)) // contribsAndRefs.contributorRewardDistribution
                let rlen := calldataload(add(car_ptr, rlen_offset)) // contribsAndRefs.references

                // if contribs or refs, call setContributorsAndReferences(contribsAndRefs)
                if or(gt(clen, 0), gt(rlen, 0)) {
                    require(eq(clen, dlen))

                    ptr := add(ptr, 0x20)                                     // free mem for arguments

                    // setContributorsAndReferences((address[],uint128[],address[]))
                    mstore(ptr, mul(0xb288e0c1, offset))
                    ptr := add(ptr, 0x04)

                    // struct pos in mem for call
                    mstore(ptr, 0x20)

                    // 6 below is from offset and len for each of cons, dist, and refs
                    let size := mul(add(add(add(clen, dlen), rlen), 6), 0x20) // size of struct
                    calldatacopy(add(ptr, 0x20), car_ptr, size)               // copy car struct from calldata to mem

                    size := add(0x24, size)

                    // call MatryxSubmission(subAddress).setContributorsAndReferences(contribsAndRefs)
                    require(call(gas(), mload(ret), 0, sub(ptr, 0x04), size, 0, 0))
                }

                return(ret, 0x20)
            }

            // function withdrawFromAbandoned() {}


            // Ownable stuffs
            function getOwner() {
                return32(sload(0))
            }

            function isOwner() {
                let _sender := arg(0)
                return32(eq(sload(0), _sender))
            }

            /// @dev transferOwnership: transfers ownership to newOwner
            /// @param address newOwner
            function transferOwnership() {
                let _newOwner := arg(0)
                require(eq(sload(0), caller()))
                require(_newOwner)
                sstore(0, _newOwner)
            }
        }
    }
}

interface IJMatryxTournament {
    function getSlot(uint256 slot) public view returns (bytes32 _val);
    function getPlatform() public view returns (address _platformAddress);
    function getTokenAddress() public view returns (address _matryxTokenAddress);

    function isEntrant(address _address) public view returns (bool _isEntrant);
    function isRound(address _address) public view returns (bool _isRound);

    function getRounds() public view returns (address[] _rounds);
    function getState() public view returns (uint256 state);
    function getData() public view returns (LibConstruction.TournamentData _data);
    function currentRound() public view returns (uint256 _currentRound, address _currentRoundAddress);
    function getCategory() public view returns (bytes32 _category);
    function getTitle() public view returns (bytes32[3] _title);
    function getDescriptionHash() public view returns (bytes32[2] _descriptionHash);
    function getFileHash() public view returns (bytes32[2] _fileHash);
    function getBounty() public view returns (uint256);
    function getBalance() public view returns (uint256);
    function getEntryFee() public view returns (uint256);

    function submissionCount() public view returns (uint256);
    function entrantCount() public view returns (uint256);
    function update(LibConstruction.TournamentModificationData tournamentData) public;
    function addFunds(uint256 _fundsToAdd) public;
    function jumpToNextRound() public;
    function stopTournament() public;
    function createSubmission(LibConstruction.SubmissionData submissionData, LibConstruction.ContributorsAndReferences contribsAndRefs) public returns(bytes32 _v);

    // Ownable stuffs
    function getOwner() public view returns (address _owner);
    function isOwner(address sender) public view returns (bool _isOwner);
    function transferOwnership(address newOwner) public view;
}

/**
struct Thing {
    uint256 t;
    uint256[] a;
    uint256[] b;
}

library function (Thing t)

[1,[7],[7]]

calldata
8f9992a1
0000000000000000000000000000000000000000000000000000000000000020
0000000000000000000000000000000000000000000000000000000000000001
0000000000000000000000000000000000000000000000000000000000000060
00000000000000000000000000000000000000000000000000000000000000a0
0000000000000000000000000000000000000000000000000000000000000001
0000000000000000000000000000000000000000000000000000000000000007
0000000000000000000000000000000000000000000000000000000000000001
0000000000000000000000000000000000000000000000000000000000000007

memory
  "0x0": "0000000000000000000000000000000000000000000000000000000000000000",
 "0x20": "0000000000000000000000000000000000000000000000000000000000000000",
 "0x40": "0000000000000000000000000000000000000000000000000000000000000120",
 "0x60": "0000000000000000000000000000000000000000000000000000000000000000",
 "0x80": "0000000000000000000000000000000000000000000000000000000000000001",
 "0xa0": "00000000000000000000000000000000000000000000000000000000000000e0",
 "0xc0": "0000000000000000000000000000000000000000000000000000000000000000",
 "0xe0": "0000000000000000000000000000000000000000000000000000000000000001",
"0x100": "0000000000000000000000000000000000000000000000000000000000000007"

function createSubmission(LibConstruction.SubmissionData submissionData, LibConstruction.ContributorsAndReferences contribsAndRefs) public constant returns (bool) -->
[["0xa","0xb","0xc"] , ["0xd","0xe"] , ["0xf","0xaa"] , 5, 5], [["0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db","0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db","0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db"],[0,1,2],["0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db","0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db","0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db","0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db"]]
function doSomethingWithSomeStructs(LibConstruction.SubmissionData _submissionData, LibConstruction.ContributorsAndReferences contribsAndRefs) public constant returns (bool)
memory:
0x400: 05527cf90a000000000000000000000000000000000000000000000000000000
0x420: 000000000b000000000000000000000000000000000000000000000000000000
0x440: 000000000c000000000000000000000000000000000000000000000000000000
0x460: 000000000d000000000000000000000000000000000000000000000000000000
0x480: 000000000e000000000000000000000000000000000000000000000000000000
0x4a0: 000000000f000000000000000000000000000000000000000000000000000000
0x4c0: 00000000aa000000000000000000000000000000000000000000000000000000
0x4e0: 0000000000000000000000000000000000000000000000000000000000000000
0x500: 0000000500000000000000000000000000000000000000000000000000000000
0x520: 0000000500000000000000000000000000000000000000000000000000000000
0x540: 0000014000000000000000000000000000000000000000000000000000000000
0x560: 0000006000000000000000000000000000000000000000000000000000000000
0x580: 000000e000000000000000000000000000000000000000000000000000000000
0x5a0: 0000016000000000000000000000000000000000000000000000000000000000
0x5c0: 000000030000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e
0x5e0: 5364d2db0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e
0x600: 5364d2db0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e
0x620: 5364d2db00000000000000000000000000000000000000000000000000000000
0x640: 0000000300000000000000000000000000000000000000000000000000000000
0x660: 0000000000000000000000000000000000000000000000000000000000000000
0x680: 0000000100000000000000000000000000000000000000000000000000000000
0x6a0: 0000000200000000000000000000000000000000000000000000000000000000
0x6c0: 000000040000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e
0x6e0: 5364d2db0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e
0x700: 5364d2db0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e
0x720: 5364d2db0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e
0x740: 5364d2db

05527cf9
0x000 0a00000000000000000000000000000000000000000000000000000000000000 // title[0]
0x020 0b00000000000000000000000000000000000000000000000000000000000000 // title[1]
0x040 0c00000000000000000000000000000000000000000000000000000000000000 // title[2]
0x060 0d00000000000000000000000000000000000000000000000000000000000000 // descriptionHash[0]
0x080 0e00000000000000000000000000000000000000000000000000000000000000 // descriptionHash[1]
0x0a0 0f00000000000000000000000000000000000000000000000000000000000000 // fileHash[0]
0x0c0 aa00000000000000000000000000000000000000000000000000000000000000 // fileHash[1]
0x0e0 0000000000000000000000000000000000000000000000000000000000000005 // timeSubmitted
0x100 0000000000000000000000000000000000000000000000000000000000000005 // timeUpdated

0x120 0000000000000000000000000000000000000000000000000000000000000140 // pos of car
0x140 0000000000000000000000000000000000000000000000000000000000000060 // con offset
0x160 00000000000000000000000000000000000000000000000000000000000000e0 // conRew offset
0x180 0000000000000000000000000000000000000000000000000000000000000160 // ref offset
0x1a0 0000000000000000000000000000000000000000000000000000000000000003 // con len
      0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e5364d2db
      0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e5364d2db
      0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e5364d2db
      0000000000000000000000000000000000000000000000000000000000000003 // conRew len
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000001
      0000000000000000000000000000000000000000000000000000000000000002
      0000000000000000000000000000000000000000000000000000000000000004 // ref len
      0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e5364d2db
      0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e5364d2db
      0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e5364d2db
      0000000000000000000000004b0897b0513fdc7c541b6d9d7e929c4e5364d2db


contract function (Thing t)

[1,[2],[2]]

inside call mem

  "0x0": "0000000000000000000000000000000000000000000000000000000000000000
 "0x20": "0000000000000000000000000000000000000000000000000000000000000000
 "0x40": "0000000000000000000000000000000000000000000000000000000000000160
 "0x60": "0000000000000000000000000000000000000000000000000000000000000000
 "0x80": "0000000000000000000000000000000000000000000000000000000000000001 // t
 "0xa0": "00000000000000000000000000000000000000000000000000000000000000e0 // a pos
 "0xc0": "0000000000000000000000000000000000000000000000000000000000000120 // b pos
 "0xe0": "0000000000000000000000000000000000000000000000000000000000000001 // a len
"0x100": "0000000000000000000000000000000000000000000000000000000000000002
"0x120": "0000000000000000000000000000000000000000000000000000000000000001 // b len
"0x140": "0000000000000000000000000000000000000000000000000000000000000003

[1,[7],[7]]
inside calldata

dc6ef131
     0000000000000000000000000000000000000000000000000000000000000020 // Thing pos
0x00 0000000000000000000000000000000000000000000000000000000000000001 // t
0x20 0000000000000000000000000000000000000000000000000000000000000060 // a offset
0x40 00000000000000000000000000000000000000000000000000000000000000a0 // b offset
0x60 0000000000000000000000000000000000000000000000000000000000000001 // a len
0x80 0000000000000000000000000000000000000000000000000000000000000007
0xa0 0000000000000000000000000000000000000000000000000000000000000001 // b len
0xc0 0000000000000000000000000000000000000000000000000000000000000007

{
	"0x80": "0000000000000000000000000000000000000000000000000000000000000001",
	"0xa0": "00000000000000000000000000000000000000000000000000000000000000e0",
	"0xc0": "0000000000000000000000000000000000000000000000000000000000000120",
	"0xe0": "0000000000000000000000000000000000000000000000000000000000000001",
	"0x100": "0000000000000000000000000000000000000000000000000000000000000007",
	"0x120": "0000000000000000000000000000000000000000000000000000000000000001",
	"0x140": "0000000000000000000000000000000000000000000000000000000000000007",
}
 */
