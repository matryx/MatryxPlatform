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

    constructor (address _owner, address _platform, address _roundFactory, LibConstruction.TournamentData _tournamentData, LibConstruction.RoundData _roundData) public {
        assembly {
            if iszero(mload(0xc0)) { revert(0, 0) }         // require(_roundFactory != 0x0)
            if iszero(mload(0x80)) { revert(0, 0) }         // require(owner != 0x0)
            if iszero(mload(0x100)) { revert(0, 0) }        // require(tournamentData.title[0] != 0x0)
            if iszero(gt(mload(0x1e0), 0)) { revert(0, 0) } // require(tournamentData.initialBounty > 0)

            sstore(owner_slot, _owner)                      // _owner
            sstore(platform_slot, _platform)                // _platform
            sstore(roundFactory_slot, _roundFactory)        // _roundFactory

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


            // this is dumb. _tournamentData points to mem that holds arg number of _tournamentData
            // actual struct data is at 0x80 + arg number - 1
            // let m_tdata := add(0x80, mul(0x20, sub(mload(_tournamentData), 1)))

            // copy tournamentData struct to data
            // for { let i := 0 } lt(i, 10) { i := add(i, 1) } {
            //     sstore(add(data_slot, i), mload(add(m_tdata, mul(0x20, i))))
            // }

            // Create Round
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
            mstore(add(ptr, 0x124), 1)            // _automaticCreation

            // call createRound
            res := delegatecall(gas(), LibTournamentAdminMethods, ptr, 0x144, ptr, 0x20)
            if iszero(res) { revert(0, 0) }
        }
    }

    function() public {
        assembly {
            let sigOffset := 0x100000000000000000000000000000000000000000000000000000000
            switch div(calldataload(0), sigOffset)

            // Tournament stuff
            case 0x2fc1f190 { getPlatform() }                         // getPlatform()
            case 0x10fe9ae8 { return32(getTokenAddress(sigOffset)) }  // getTokenAddress()

            case 0x4644c51b {} // TODO invokeSubmissionCreatedEvent

            // Tournament data
            case 0x52c01fab { return32(isEntrant(arg(0))) }           // isEntrant(address)
            case 0x8c1fc0bb { return32(isRound(arg(0))) }             // getData()
            case 0x8a19c8bc { return(currentRound(sigOffset), 0x40) } // currentRound()
            case 0x80258e47 { getCategory() }                         // getCategory()
            case 0xff3c1a8f { getTitle() }                            // getTitle()
            case 0x245edf06 { getDescriptionHash() }                  // getDescriptionHash()
            case 0x8493f71f { getFileHash() }                         // getFileHash()
            case 0xf49bff7b { return32(getBounty(sigOffset)) }        // getBounty()
            case 0x12065fe0 { return32(getBalance(sigOffset)) }       // getBalance()
            case 0xe586a4f0 { getEntryFee() }                         // getEntryFee()
            case 0x45df1945 { collectMyEntryFee(sigOffset) }

            case 0xe139a20c { mySubmissions() }                       // mySubmissions()

            // Tournament stateData
            case 0x6ec02be9 { submissionCount() }                     // submissionCount()
            case 0x89f3beb6 { entrantCount() }                        // entrantCount()
            case 0xd60561ce { update(sigOffset) }                     // update((bytes32,bytes32[3],bytes32[2],bytes32[2],uint256,bool))
            case 0x6984d070 { getRounds() }                           // getRounds()
            case 0x1865c57d { return32(getState(sigOffset)) }         // getState()
            case 0x3bc5de30 { getData() }                             // getData()

            case 0x583c3a92 { selectWinners(sigOffset) }              // selectWinners((address[],uint256[],uint256,uint256),(uint256,uint256,uint256,uint256,bool))
            case 0xd6830846 { editGhostRound(sigOffset) }             // editGhostRound(uint256,uint256,uint256,uint256,bool)
            case 0x072a4560 { allocateMoreToRound(sigOffset) }        // allocateMoreToRound(uint256 )
            case 0xc2f897bf { jumpToNextRound(sigOffset) }            // jumpToNextRound()
            case 0x9baec207 { stopTournament(sigOffset) }             // stopTournament()
            case 0x67f69ab1 { createRound(sigOffset) }                // createRound((uint256,uint256,uint256,uint256,bool),bool)
            case 0x23721e24 { sendBountyToRound(sigOffset) }          // sendBountyToRound(uint256,uint256)
            case 0x28d576d7 { enterUserInTournament(sigOffset) }      // enterUserInTournament(address)
            case 0xfa8f3ac5 { createSubmission(sigOffset) }           // createSubmission((bytes32[3],bytes32[2],bytes32[2],uint256,uint256),(address[],uint256[],address[]))
            case 0x542fe6c2 { withdrawFromAbandoned(sigOffset) }      // withdrawFromAbandoned()

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

            // --------------------------------
            //            Modifiers
            // --------------------------------
            function onlyOwner() {
                require(eq(sload(owner_slot), caller()))
            }

            function onlyPlatform() {
                require(eq(sload(platform_slot), caller()))
            }

            function onlyRound() {
                require(isRound(caller()))
            }

            function onlyPeerLinked(_sender, offset) {
                let platform := sload(platform_slot)
                mstore(0, mul(0x7a348ab3, offset)) // hasEnteredMatryx(address)
                mstore(0x04, caller())

                // call platform.hasEnteredMatryx(msg.sender), revert if result false
                require(call(gas(), platform, 0, 0, 0x44, 0, 0x20))
                require(mload(0))
            }

            function onlyEntrant() {
                require(isEntrant(caller()))
            }

            function whileTournamentOpen(offset) {
                let s := getState(offset)
                require(eq(s, 2)) // LibEnum.TournamentState.Open
            }

            function ifRoundHasFunds(offset) {
                let round := mload(add(currentRound(offset), 0x20))
                mstore(0, mul(0x1865c57d, offset)) // getState()
                require(call(gas(), round, 0, 0, 0x04, 0, 0x20))
                require(iszero(eq(mload(0), 1)))   // LibEnums.RoundState.Unfunded
            }

            // --------------------------------

            // getPlatform() public view returns (address _platformAddress)
            function getPlatform() {
                return32(sload(platform_slot))
            }

            // getTokenAddress() public view returns (address _matryxTokenAddress)
            function getTokenAddress(offset) -> token {
                let ptr := 0x0
                mstore(ptr, mul(0x10fe9ae8, offset)) // getTokenAddress()

                // call platform.getTokenAddress and put in ptr
                require(call(gas(), sload(platform_slot), 0, ptr, 0x04, ptr, 0x20))

                token := mload(ptr)
            }

            // Tournament data
            // isEntrant(address _sender) public view returns (bool)
            function isEntrant(_address) -> isEnt {
                mstore(0, _address)
                // entryData.addressToEntryFeePaid
                mstore(0x20, add(entryData_slot, 4))
                isEnt := sload(keccak256(0, 0x40))
            }

            // isRound(address _roundAddress) public view returns (bool _isRound)
            function isRound(_address) -> isRnd {
                mstore(0, _address)
                // stateData.isRound
                mstore(0x20, add(stateData_slot, 1))
                isRnd := sload(keccak256(0, 0x40))
            }

            // getRounds() public view returns (address[] _rounds)
            function getRounds() {
                // first stateData item is rounds
                mstore(0, stateData_slot)
                let rounds := keccak256(0, 0x20)

                // length of dyn arrays stored in slot
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

            // getState() public view returns (uint256)
            function getState(offset) -> state {
                let ptr := 0x0

                // getState(LibTournamentStateManagement.StateData storage)
                mstore(ptr, mul(0x5726b16f, offset))
                mstore(add(ptr, 0x04), stateData_slot)

                // call LibTournamentStateManagement.getState
                require(delegatecall(gas(), LibTournamentStateManagement, ptr, 0x24, ptr, 0x20))

                state := mload(ptr)
            }

            // getData() public view returns (LibConstruction.TournamentData _data)
            function getData() {
                let data := mload(0x40)
                mstore(data, sload(data_slot))                     // tournamentData.category
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

            // getCategory() public view returns (bytes32 _category)
            function getCategory() {
                return32(sload(data_slot)) // data.category
            }

            // getTitle() public view returns (bytes32[3] _title)
            function getTitle() {
                let title := mload(0x40)
                mstore(title, sload(add(data_slot, 1)))            // data.title[0]
                mstore(add(title, 0x20), sload(add(data_slot, 2))) // data.title[1]
                mstore(add(title, 0x40), sload(add(data_slot, 3))) // data.title[2]
                return(title, 0x60)
            }

            // getDescriptionHash() public view returns (bytes32[2] _descriptionHash)
            function getDescriptionHash() {
                let desc := mload(0x40)
                mstore(desc, sload(add(data_slot, 4)))             // data.descriptionHash[0]
                mstore(add(desc, 0x20), sload(add(data_slot, 5)))  // data.descriptionHash[1]
                return(desc, 0x40)
            }

            // getFileHash() public view returns (bytes32[2] _fileHash)
            function getFileHash() {
                let file := mload(0x40)
                mstore(file, sload(add(data_slot, 6)))             // data.fileHash[0]
                mstore(add(file, 0x20), sload(add(data_slot, 7)))  // data.fileHash[1]
                return(file, 0x40)
            }

            // getBounty() public view returns (uint256 _tournamentBounty)
            function getBounty(offset) -> bounty {
                // .add(stateData.roundBountyAllocation)
                bounty := safeadd(getBalance(offset), sload(add(stateData_slot, 3)))
            }

            // getBalance() public view returns (uint256 _tournamentBalance)
            function getBalance(offset) -> bal {
                let tokenAddress := getTokenAddress(offset)
                let ptr := 0x0

                mstore(ptr, mul(0x70a08231, offset)) // balanceOf(address)
                mstore(add(ptr, 0x04), address())

                // call token balanceOf(this) and put in ptr
                require(call(gas(), tokenAddress, 0, ptr, 0x24, ptr, 0x20))

                // .sub(stateData.entryFeesTotal)
                bal := safesub(mload(ptr), sload(add(stateData_slot, 2)))
            }


            // getEntryFee() public view returns (uint256)
            function getEntryFee() {
                return32(sload(add(data_slot, 9)))  // data.entryFee
            }

            // currentRound() public view returns (uint256 _currentRound, address _currentRoundAddress)
            function currentRound(offset) -> m_currentRound {
                let ptr := 0x0

                // currentRound(LibTournamentStateManagement.StateData storage)
                mstore(ptr, mul(0x0386922b, offset))
                mstore(add(ptr, 0x04), stateData_slot)

                require(delegatecall(gas(), LibTournamentStateManagement, ptr, 0x24, ptr, 0x40))

                m_currentRound := ptr
            }

            // mySubmissions() public view returns (address[])
            function mySubmissions() {
                // entryData.entrantToSubmissions[msg.sender]
                mstore(0, caller())
                mstore(0x20, add(entryData_slot, 2))
                let subs_len_pos := keccak256(0, 0x40)

                // get subs storage pos
                mstore(0, subs_len_pos)
                let subs_pos := keccak256(0, 0x20)

                // get number of subs
                let subs_len := sload(subs_len_pos)
                let size := mul(add(2, subs_len), 0x20)

                let ptr := mload(0x40)
                let ret := ptr

                // store array element size and array length
                mstore(ptr, 0x20)
                ptr := add(ptr, 0x20)
                mstore(ptr, subs_len)

                // store array items
                for { let i := 0 } lt(i, subs_len) { i := add(i, 1) } {
                    ptr := add(ptr, 0x20)
                    mstore(ptr, sload(add(subs_pos, i)))
                }

                return(ret, size)
            }

            // submissionCount() public view returns (uint256 _submissionCount)
            function submissionCount() {
                return32(sload(add(entryData_slot, 1))) // entryData.numberOfSubmissions
            }

            // entrantCount() public view returns (uint256 _entrantCount)
            function entrantCount() {
                return32(sload(add(entryData_slot, 5))) // entryData.numberOfEntrants
            }

            // update(LibConstruction.TournamentModificationData tournamentData) public onlyOwner
            function update(offset) {
                onlyOwner()

                let ptr := mload(0x40)
                let mem := ptr

                // update(LibConstruction.TournamentData storage,LibConstruction.TournamentModificationData,address)
                mstore(ptr, mul(0xb43475ff, offset))
                mstore(add(ptr, 0x04), data_slot)
                ptr := add(ptr, 0x24)

                // copy tournamentData to mem
                calldatacopy(ptr, 0x04, 0x140)
                ptr := add(ptr, 0x140)

                mstore(ptr, sload(platform_slot))
                require(delegatecall(gas(), LibTournamentAdminMethods, mem, 0x184, 0x0, 0x20))
            }

            // selectWinners(LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData)
            function selectWinners (offset) {
                onlyOwner()

                let ptr := mload(0x40)

                // selectWinners(LibTournamentStateManagement.StateData storage,address,address,LibRound.SelectWinnersData,LibConstruction.RoundData)
                mstore(ptr, mul(0xd06b5924, offset))

                mstore(add(ptr, 0x04), stateData_slot)
                mstore(add(ptr, 0x24), sload(platform_slot))
                mstore(add(ptr, 0x44), getTokenAddress(offset))

                // copy selectWinnersData and roundData
                let size := sub(calldatasize(), 0x04)
                calldatacopy(add(ptr, 0x64), 0x04, size)

                // update selectWinnersData location
                let m_swd := add(ptr, 0x64)
                mstore(m_swd, add(mload(m_swd), 0x60))

                size := add(size, 0x64)

                require(delegatecall(gas(), LibTournamentAdminMethods, ptr, size, 0, 0x20))
            }

            // editGhostRound(LibConstruction.RoundData _roundData)
            function editGhostRound(offset) {
                onlyOwner()

                let token := getTokenAddress(offset)
                let ptr := mload(0x40)

                // editGhostRound(LibTournamentStateManagement.StateData storage,LibConstruction.RoundData,address)
                mstore(ptr, mul(0x672ec623, offset))

                // copy roundData
                calldatacopy(add(ptr, 0x04), 0, calldatasize())

                // sizeof RoundData 5 words (0xa0) + sizeof stateData_slot (0x20) = 0xc0
                mstore(add(ptr, 0xc4), token)
                require(delegatecall(gas(), LibTournamentAdminMethods, ptr, 0xe4, 0, 0))
            }

            // allocateMoreToRound(uint256 _mtxAllocation)
            function allocateMoreToRound(offset) {
                onlyOwner()

                let token := getTokenAddress(offset)    // token address

                let ptr := mload(0x40)

                mstore(ptr, mul(0x072a4560, offset))    // allocateMoreToRound(uint256)
                mstore(add(ptr, 0x04), stateData_slot)  // stateData (slot)
                mstore(add(ptr, 0x24), arg(0))          // _mtxAllocation
                mstore(add(ptr, 0x44), token)           // token address

                require(delegatecall(gas(), LibTournamentAdminMethods, ptr, 0x64, 0x0, 0))
            }

            // jumpToNextRound()
            function jumpToNextRound(offset) {
                onlyOwner()

                let ptr := mload(0x40)

                // jumpToNextRound(LibTournamentStateManagement.StateData storage
                mstore(ptr, mul(0xaf410949, offset))
                mstore(add(ptr, 0x04), stateData_slot)
                require(delegatecall(gas(), LibTournamentAdminMethods, ptr, 0x24, 0, 0x20))
            }

            // stopTournament()
            function stopTournament(offset) {
                onlyOwner()

                let ptr := mload(0x40)
                let token := getTokenAddress(offset)

                // stopTournament(LibTournamentStateManagement.StateData storage,address,address)
                mstore(ptr, mul(0xa91d59d6, offset))
                mstore(add(ptr, 0x04), data_slot)
                mstore(add(ptr, 0x24), sload(platform_slot))
                mstore(add(ptr, 0x44), token)

                require(delegatecall(gas(), LibTournamentAdminMethods, ptr, 0x64, 0, 0))
            }

            // createRound(roundData, automaticCreation)
            function createRound(offset) {
                onlyRound()

                let ptr := mload(0x40)
                let token := getTokenAddress(offset)

                // createRound(LibTournamentStateManagement.StateData storage,address,address,address,LibConstruction.RoundData,bool)
                mstore(ptr, mul(0xcfa037dc, offset))

                mstore(add(ptr, 0x04), stateData_slot)
                mstore(add(ptr, 0x24), sload(platform_slot))
                mstore(add(ptr, 0x44), token)
                mstore(add(ptr, 0x64), sload(roundFactory_slot))

                // copy roundData and automaticCreation
                calldatacopy(add(ptr, 0x84), 0x04, sub(calldatasize(), 0x04))

                // call createRound
                require(delegatecall(gas(), LibTournamentAdminMethods, ptr, 0x144, ptr, 0x20))
                return(ptr, 0x20)
            }

            // sendBountyToRound(uint256 _roundIndex, uint256 _bountyMTX)
            function sendBountyToRound(offset) {
                onlyPlatform()

                let round_i := arg(0)
                let mtx := arg(1)

                // stateData.roundBountyAllocation += mtx
                let rba_pos := add(stateData_slot, 3)
                sstore(rba_pos, safeadd(sload(rba_pos), mtx))

                mstore(0, stateData_slot)                         // stateData.rounds
                let rounds_pos := keccak256(0, 0x20)              // rounds storage slot
                let round := sload(safeadd(rounds_pos, round_i))  // get rounds[i]

                let token := getTokenAddress(offset)
                let ptr := mload(0x40)

                mstore(ptr, mul(0xa9059cbb, offset))              // transfer(address,uint256)
                mstore(add(ptr, 0x04), round)                     // round address
                mstore(add(ptr, 0x24), mtx)                       // mtx amount

                // call Token.transfer(_roundIndex, _bountyMtx)
                require(call(gas(), token, 0, ptr, 0x44, 0, 0))
            }

            // enterUserInTournament(address _entrantAddress)
            function enterUserInTournament(offset) {
                onlyPlatform()
                whileTournamentOpen(offset)

                let ent_address := arg(0)
                let ptr := mload(0x40)

                // enterUserInTournament(LibConstruction.TournamentData storage,LibTournamentStateManagement.StateData storage,LibTournamentStateManagement.EntryData storage,address)
                mstore(ptr, mul(0xa09c5c99, offset))
                mstore(add(ptr, 0x04), data_slot)
                mstore(add(ptr, 0x24), stateData_slot)
                mstore(add(ptr, 0x44), entryData_slot)
                mstore(add(ptr, 0x64), ent_address)

                require(delegatecall(gas(), LibTournamentEntrantMethods, ptr, 0x84, 0, 0x20))
                return(0, 0x20)
            }

            function collectMyEntryFee(offset) {
                let token := getTokenAddress(offset)    // token address

                let ptr := mload(0x40)

                // collectMyEntryFee(LibTournamentStateData.StateData storage,LibTournamentStateData.EntryData storage,address)
                mstore(ptr, mul(0xff4fef08, offset))
                mstore(add(ptr, 0x04), stateData_slot)
                mstore(add(ptr, 0x24), entryData_slot)
                mstore(add(ptr, 0x44), token)

                require(delegatecall(gas(), LibTournamentEntrantMethods, ptr, 0x64, 0, 0))
            }

            // createSubmission(LibConstruction.SubmissionData submissionData, LibConstruction.ContributorsAndReferences contribsAndRefs)
            function createSubmission(offset) {
                onlyEntrant()
                onlyPeerLinked(caller(), offset)
                ifRoundHasFunds(offset)
                whileTournamentOpen(offset)

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
                calldatacopy(add(ptr, 0x64), 0x04, 0x120)

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

                    ptr := add(ptr, 0x20) // free mem for arguments

                    // setContributorsAndReferences((address[],uint256[],address[]))
                    mstore(ptr, mul(0x0a181f52, offset))
                    ptr := add(ptr, 0x04)

                    // struct pos in mem for call
                    mstore(ptr, 0x20)

                    // 6 below is from offset and len for each of cons, dist, and refs
                    let size := mul(add(add(add(clen, dlen), rlen), 6), 0x20) // size of struct
                    calldatacopy(add(ptr, 0x20), car_ptr, size)               // copy car struct from calldata to mem

                    size := add(size, 0x24)

                    // call MatryxSubmission(subAddress).setContributorsAndReferences(contribsAndRefs)
                    require(call(gas(), mload(ret), 0, sub(ptr, 0x04), size, 0, 0))
                }

                return(ret, 0x20)
            }

            function withdrawFromAbandoned(offset) {
                onlyEntrant()

                let token := getTokenAddress(offset)
                let ptr := mload(0x40)

                // withdrawFromAbandoned(LibTournamentStateManagement.StateData storage,LibTournamentStateManagement.EntryData storage,address)
                mstore(ptr, mul(0xddc23bd0, offset))
                mstore(add(ptr, 0x04), stateData_slot)
                mstore(add(ptr, 0x24), entryData_slot)
                mstore(add(ptr, 0x44), token)

                require(delegatecall(gas(), LibTournamentEntrantMethods, ptr, 0x64, 0x0, 0))
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

interface IJMatryxTournament {
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
    function collectMyEntryFee() public;

    function mySubmissions() public view returns (address[]);

    function submissionCount() public view returns (uint256);
    function entrantCount() public view returns (uint256);
    function update(LibConstruction.TournamentModificationData tournamentData) public;

    function selectWinners(LibRound.SelectWinnersData _selectWinnersData, LibConstruction.RoundData _roundData) public;
    function editGhostRound(LibConstruction.RoundData _roundData) public;
    function allocateMoreToRound(uint256 _mtxAllocation) public;

    function jumpToNextRound() public;
    function stopTournament() public;
    function createRound(LibConstruction.RoundData roundData, bool _automaticCreation) public returns (address _roundAddress);
    function sendBountyToRound(uint256 _roundIndex, uint256 _bountyMTX) public;
    function enterUserInTournament(address _entrantAddress) public returns (bool _success);
    function createSubmission(LibConstruction.SubmissionData submissionData, LibConstruction.ContributorsAndReferences contribsAndRefs) public returns(bytes32 _v);
    function withdrawFromAbandoned() public;

    // Ownable stuffs
    function getOwner() public view returns (address _owner);
    function isOwner(address sender) public view returns (bool _isOwner);
    function transferOwnership(address newOwner) public view;
}
