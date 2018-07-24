pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "../libraries/LibConstruction.sol";
import "../libraries/tournament/LibTournamentStateManagement.sol";

contract JMatryxTournament {
    address owner;
    address platform;
    address roundFactory;
    LibConstruction.TournamentData data;
    LibTournamentStateManagement.StateData stateData;


    constructor (address _owner, address _platform, address _roundFactory, LibConstruction.TournamentData tournamentData, LibConstruction.RoundData roundData) public {
        assembly {
            if iszero(mload(0xc0)) { revert(0, 0) }         // require(_roundFactory != 0x0)
            if iszero(mload(0x80)) { revert(0, 0) }         // require(owner != 0x0)
            if iszero(mload(0x100)) { revert(0, 0) }        // require(tournamentData.title[0] != 0x0)
            if iszero(gt(mload(0x1e0), 0)) { revert(0, 0) } // require(tournamentData.initialBounty > 0)

            sstore(owner_slot, mload(0x80))         // _owner
            sstore(platform_slot, mload(0xa0))      // _platform
            sstore(roundFactory_slot, mload(0xc0))  // _roundFactory
            sstore(data_slot, mload(0xe0))          // tournamentData.category
            sstore(add(data_slot, 1), mload(0x100)) // tournamentData.title[0]
            sstore(add(data_slot, 2), mload(0x120)) // tournamentData.title[1]
            sstore(add(data_slot, 3), mload(0x140)) // tournamentData.title[2]
            sstore(add(data_slot, 4), mload(0x160)) // tournamentData.descriptionHash[0]
            sstore(add(data_slot, 5), mload(0x180)) // tournamentData.descriptionHash[1]
            sstore(add(data_slot, 6), mload(0x1a0)) // tournamentData.fileHash[0]
            sstore(add(data_slot, 7), mload(0x1c0)) // tournamentData.fileHash[1]
            sstore(add(data_slot, 8), mload(0x1e0)) // tournamentData.initialBounty
            sstore(add(data_slot, 9), mload(0x200)) // tournamentData.entryFee

            // create round
        }
    }

    function() public {
        assembly {
            let sigOffset := 0x100000000000000000000000000000000000000000000000000000000
            switch div(calldataload(0), sigOffset)

            // Tournament stuffs
            case 0x7eba7ba6 { // getSlot(uint256)
                getSlot(arg(0))
            }
            case 0x2fc1f190 { // getPlatform()
                getPlatform()
            }
            case 0x10fe9ae8 { // getTokenAddress()
                return32(getTokenAddress(sigOffset))
            }


            case 0x3bc5de30 { // getData()
                getData()
            }
            case 0x80258e47 { // getCategory()
                getCategory()
            }
            case 0xff3c1a8f { // getTitle()
                getTitle()
            }
            case 0x245edf06 { // getDescriptionHash()
                getDescriptionHash()
            }
            case 0x8493f71f { // getFileHash()
                getFileHash()
            }
            case 0xf49bff7b { // getBounty()
                return32(getBounty(sigOffset))
            }
            case 0x12065fe0 { // getBalance()
                return32(getBalance(sigOffset))
            }
            case 0xe586a4f0 { //getEntryFee()
                getEntryFee()
            }


            // Ownable stuffs
            case 0x893d20e8 { // getOwner()
                getOwner()
            }
            case 0x2f54bf6e { // isOwner(address)
                isOwner(arg(0))
            }
            case 0xf2fde38b { // transferOwnership(address)
                transferOwnership(arg(0))
            }

            // Bro why you tryna call a function that doesn't exist?
            default {
                revert(0, 0)
            }


            function arg(n) -> a {
                a := calldataload(add(0x04, mul(n, 0x20)))
            }

            function return32(v) {
                mstore(0, v)
                return(0, 0x20)
            }

            /// @dev getSlot
            /// @param uint256 slot
            function getSlot(slot){
                return32(sload(slot))
            }

            function getPlatform() {
                return32(sload(1))
            }

            function getTokenAddress(offset) -> token {
                let sig := mul(0x10fe9ae8, offset) // getTokenAddress()
                let ptr := 0x0
                mstore(ptr, sig)

                // call platform getTokenAddress() and put in ptr
                let res := call(gas(), sload(platform_slot), 0, ptr, 0x04, ptr, 0x20)
                if iszero(res) { revert (0, 0) }

                token := mload(ptr)
            }

            function getData() {
                let data := mload(0x40)
                mstore(data, data_slot) // tournamentData.category
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

            // function isRound(roundAddress) -> b {}
            // function getRounds() -> r_ptr {}

            function getCategory() {
                return32(sload(3))
            }

            /// @dev getTitle: returns title in a byte array of size 3
            function getTitle() {
                let title := mload(0x40)
                mstore(title, sload(add(data_slot, 1)))
                mstore(add(title, 0x20), sload(add(data_slot, 2)))
                mstore(add(title, 0x40), sload(add(data_slot, 3)))
                return(title, 0x60)
            }

            function getDescriptionHash() {
                let desc := mload(0x40)
                mstore(desc, sload(7))
                mstore(add(desc, 0x20), sload(8))
                return(desc, 0x40)
            }

            function getFileHash() {
                let file := mload(0x40)
                mstore(file, sload(9))
                mstore(add(file, 0x20), sload(10))
                return(file, 0x40)
            }

            // function currentRound() -> r_index {}

            function getBounty(offset) -> bounty {
                bounty := add(getBalance(offset), sload(add(stateData_slot, 3))) // .add(stateData.roundBountyAllocation)
            }

            function getBalance(offset) -> bal {
                let tokenAddress := getTokenAddress(offset)
                let sig := mul(0x70a08231, offset) // balanceOf(address)
                let ptr := 0x0
                mstore(ptr, sig)
                mstore(add(ptr, 0x04), address())

                // call token balanceOf(this) and put in ptr
                let res := call(gas(), tokenAddress, 0, ptr, 0x24, ptr, 0x20)
                if iszero(res) { revert (0, 0) }

                bal := mload(ptr)
                bal := sub(bal, sload(add(stateData_slot, 2))) // .sub(stateData.entryFeesTotal)
            }

            // function getGhostRound() -> index_address {}
            // function mySubmissions() {}
            // function submissionCount() {}
            // function entrantCount() {}
            // function update(tournamentData) {}
            // function addFunds(_fundsToAdd) {}
            // function selectWinners
            // function editGhostRound
            // function allocateMoreToRound
            // function jumpToNextRound() {}
            // function stopTournament() {}
            // function createRound
            // function sendBountyToRound(_roundIndex, _bountyMTX)
            // function enterUserInTournament(_entrantAddress)
            // function collectMyEntryFee()
            // function createSubmission
            // function withdrawFromAbandoned() {}

            function getEntryFee() {
                return32(sload(12))
            }

            function getOwner() {
                return32(sload(0))
            }

            function isOwner(sender) {
                return32(eq(sload(0), sender))
            }

            /// @dev transferOwnership: transfers ownership to newOwner
            /// @param address newOwner
            function transferOwnership(newOwner) {
                if iszero(eq(sload(0), caller())) { revert(0, 0) }
                if iszero(newOwner) { revert(0, 0) }
                sstore(0, newOwner)
            }
        }
    }
}

interface IJMatryxTournament {
    function getSlot(uint256 slot) public view returns (bytes32 _val);
    function getPlatform() public view returns (address _platformAddress);
    function getTokenAddress() public view returns (address _matryxTokenAddress);

    function getData() public view returns (LibConstruction.TournamentData _data);
    function getCategory() public view returns (bytes32 _category);
    function getTitle() public view returns (bytes32[3] _title);
    function getDescriptionHash() public view returns (bytes32[2] _descriptionHash);
    function getFileHash() public view returns (bytes32[2] _fileHash);
    function getEntryFee() public view returns (uint256);
    function getBounty() public view returns (uint256);
    function getBalance() public view returns (uint256);

    // Ownable stuffs
    function getOwner() public view returns (address _owner);
    function isOwner(address sender) public view returns (bool _isOwner);
    function transferOwnership(address newOwner) public view;
}
