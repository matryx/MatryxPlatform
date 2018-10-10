pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./IMatryxToken.sol";
import "./LibGlobals.sol";

import "./MatryxSystem.sol";
import "./MatryxPlatform.sol";
import "./MatryxTrinity.sol";
import "./MatryxRound.sol";
import "./MatryxSubmission.sol";

contract MatryxTournament is MatryxTrinity {
    constructor (uint256 _version, address _system) MatryxTrinity(_version, _system) public {}
}

interface IMatryxTournament {
    function transferFrom(address, address, uint256) external;
    function transferTo(address, address, uint256) external;
    function setInfo(MatryxTrinity.Info) external;

    function getOwner() external view returns (address);
    function getTitle() external view returns (bytes32[3]);
    function getCategory() external view returns (bytes32);
    function getDescriptionHash() external view returns (bytes32[2]);
    function getFileHash() external view returns (bytes32[2]);
    function getBounty() external view returns (uint256);
    function getEntryFee() external view returns (uint256);
    function getRounds() external view returns (address[]);
    function getDetails() external view returns (LibTournament.TournamentDetails);

    function getBalance() external view returns (uint256);
    function getState() external view returns (uint256);
    function getCurrentRound() external view returns (uint256, address);

    function getSubmissionCount() external view returns (uint256);
    function getMySubmissions() external view returns (address[]);

    function getEntrantCount() external view returns (uint256);
    function isEntrant(address) external view returns (bool);

    function enter() external;
    function exit() external;
    function createSubmission(LibSubmission.SubmissionDetails) external returns (address);

    function updateDetails(LibTournament.TournamentDetails) external;
    function transferToRound(uint256) external;

    function selectWinners(LibRound.WinnersData, LibRound.RoundDetails) external;
    function updateNextRound(LibRound.RoundDetails) external;
    function startNextRound() external;
    function closeTournament() external;

    function withdrawFromAbandoned() external;
    function recoverFunds() external;
}

// dependents: LibPlatform
library LibTournament {
    using SafeMath for uint256;

    event RoundCreated(address roundAddress);
    event SubmissionCreated(address submissionAddress);

    struct TournamentInfo {
        address owner;
        address[] rounds;
        uint256 entrantCount;
    }

    // All information needed for creation of Tournament
    struct TournamentDetails {
        bytes32[3] title;
        bytes32 category;
        bytes32[2] descHash;
        bytes32[2] fileHash;
        uint256 bounty;
        uint256 entryFee;
    }
    // bytes32[2] publicKey;
    // bytes32 privateKey;

    // All state data and details of Tournament
    struct TournamentData {
        TournamentInfo info;
        TournamentDetails details;

        mapping(address=>LibGlobals.o_uint256) entryFeePaid;
        address[] allEntrants;
        uint256 totalEntryFees;

        mapping(address=>bool) hasWithdrawn;
        bool hasBeenWithdrawnFrom;
    }

    /// @dev Returns the owner of this Tournament
    function getOwner(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        return data.tournaments[self].info.owner;
    }

    /// @dev Returns the title of this Tournament
    function getTitle(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[3]) {
        return data.tournaments[self].details.title;
    }

    /// @dev Returns the category of this Tournament
    function getCategory(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32) {
        return data.tournaments[self].details.category;
    }

    /// @dev Returns the description hash of this Tournament
    function getDescriptionHash(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        return data.tournaments[self].details.descHash;
    }

    /// @dev Returns the file hash of this Tournament
    function getFileHash(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[2]) {
        return data.tournaments[self].details.fileHash;
    }

    /// @dev Returns the bounty of this Tournament
    function getBounty(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.tournaments[self].details.bounty;
    }

    /// @dev Returns the current entry fee of this Tournament
    function getEntryFee(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.tournaments[self].details.entryFee;
    }

    /// @dev Returns all Round addresses of this Tournament
    function getRounds(address self, address, MatryxPlatform.Data storage data) public view returns (address[]) {
        return data.tournaments[self].info.rounds;
    }

    /// @dev Returns the data struct of this Tournament
    function getDetails(address self, address, MatryxPlatform.Data storage data) public view returns (LibTournament.TournamentDetails) {
        return data.tournaments[self].details;
    }

    /// @dev Returns the MTX balance of the Tournament
    function getBalance(address self, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public view returns (uint256) {
        return IMatryxToken(info.token).balanceOf(self).sub(data.tournaments[self].totalEntryFees);
    }

    /// @dev Returns the state of this Tournament
    function getState(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        (uint256 numRounds, address roundAddress) = getCurrentRound(self, self, data);

        uint256 roundState = IMatryxRound(roundAddress).getState();

        if (roundState >= uint256(LibGlobals.RoundState.Unfunded) &&
            roundState <= uint256(LibGlobals.RoundState.HasWinners)
        ) {
            return uint256(LibGlobals.TournamentState.Open);
        }
        else if (roundState == uint256(LibGlobals.RoundState.NotYetOpen)) {
            if (numRounds != 1) {
                return uint256(LibGlobals.TournamentState.OnHold);
            }
            return uint256(LibGlobals.TournamentState.NotYetOpen);
        }
        else if (roundState == uint256(LibGlobals.RoundState.Closed)) {
            return uint256(LibGlobals.TournamentState.Closed);
        }
        return uint256(LibGlobals.TournamentState.Abandoned);
    }

    /// @dev Returns the current round number and address of this Tournament
    function getCurrentRound(address self, address, MatryxPlatform.Data storage data) public view returns (uint256, address) {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        address[] storage rounds = tournament.info.rounds;
        uint256 numRounds = rounds.length;

        if (numRounds > 1 &&
           IMatryxRound(rounds[numRounds-2]).getState() == uint256(LibGlobals.RoundState.HasWinners)
        ) {
            return (numRounds-1, rounds[numRounds-2]);
        } else {
            return (numRounds, rounds[numRounds-1]);
        }
    }

    /// @dev Returns the total number of submissions made in all rounds of this tournament
    function getSubmissionCount(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        address[] storage rounds = data.tournaments[self].info.rounds;
        uint256 count = 0;

        for (uint256 i = 0; i < rounds.length; i++) {
            count += data.rounds[rounds[i]].info.submissions.length;
        }

        return count;
    }

    /// @dev Returns the addresses of all the submissions the caller made in this tournament
    function getMySubmissions(address self, address sender, MatryxPlatform.Data storage data) public view returns (address[]) {
        address[] storage submissions = data.users[sender].submissions;
        uint256 length = submissions.length;

        assembly {
            let offset := 0x100000000000000000000000000000000000000000000000000000000
            let ptr := mload(0x40)
            let size := 0

            mstore(0, submissions_slot)                                         // store submissions slot
            let s_subs := keccak256(0, 0x20)                                    // get start of submissions array

            mstore(ptr, 0x20)                                                   // store sizeof address

            mstore(0, mul(0xe76c293e, offset))                                  // getTournament()
            for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                let subm := sload(add(s_subs, i))                               // get Submission address
                let ret := call(gas, subm, 0, 0, 0x04, 0x20, 0x20)              // call Submission.getTournament
                if iszero(ret) { revert(0, 0) }                                 // safety check

                if eq(mload(0x20), self) {                                      // if tournament == this tournament
                    size := add(size, 1)                                        // increment array size
                    mstore(add(ptr, mul(add(size, 1), 0x20)), subm)             // add Submission to array
                }
            }

            mstore(add(ptr, 0x20), size)                                        // store array size
            return(ptr, add(0x40, mul(size, 0x20)))                             // return array
        }
    }

    function getEntrantCount(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.tournaments[self].info.entrantCount;
    }

    /// @dev Returns true if address passed has entered the Tournament
    /// @param uAddress    Address of some user
    function isEntrant(address self, address, MatryxPlatform.Data storage data, address uAddress) public view returns (bool) {
        return data.tournaments[self].entryFeePaid[uAddress].exists;
    }

    /// @dev Enter Tournament
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param data    Data struct on Platform
    function enter(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        uint256 entryFee = tournament.details.entryFee;

        require(data.users[sender].exists, "Must have entered Matryx");
        require(sender != tournament.info.owner, "Cannot enter own Tournament");
        require(getState(self, sender, data) < uint256(LibGlobals.TournamentState.Closed), "Cannot enter closed or abandoned Tournament");
        IMatryxTournament(self).transferFrom(info.token, sender, entryFee);

        tournament.entryFeePaid[sender].exists = true;
        tournament.entryFeePaid[sender].value = entryFee;
        tournament.totalEntryFees = tournament.totalEntryFees.add(entryFee);
        tournament.allEntrants.push(sender);
        tournament.info.entrantCount = tournament.info.entrantCount.add(1);
        data.users[sender].tournamentsEntered.push(self);
    }

    /// @dev Exit Tournament and recover entry fee
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    function exit(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(tournament.entryFeePaid[sender].exists, "Must be entrant");
        uint256 entryFeePaid = tournament.entryFeePaid[sender].value;

        if (entryFeePaid > 0) {
            IMatryxTournament(self).transferTo(info.token, sender, entryFeePaid);
            tournament.totalEntryFees = tournament.totalEntryFees.sub(entryFeePaid);
        }

        tournament.entryFeePaid[sender].exists = false;
        tournament.info.entrantCount = tournament.info.entrantCount.sub(1);
    }

    /// @dev Creates a new Round on this Tournament
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to the Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param rDetails  Details of the Round being created
    /// @return          Address of the created Round
    function createRound(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibRound.RoundDetails rDetails) internal returns (address) {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");
        require(IMatryxToken(info.token).balanceOf(self) >= rDetails.bounty, "Insufficient funds for Round");

        // TODO: enable min and max round duration
        // uint256 duration = rDetails.end.sub(rDetails.start);
        // require(duration >= 1 hours && duration <= 365 days, "Round must be at least 1 hour and at most 1 year");

        // TODO: add review time restrictions or auto review?

        address rAddress = new MatryxRound(info.version, info.system);

        MatryxSystem(info.system).setContractType(rAddress, uint256(LibSystem.ContractType.Round));
        tournament.info.rounds.push(rAddress);
        data.allRounds.push(rAddress);

        IMatryxTournament(self).transferTo(info.token, rAddress, rDetails.bounty);

        LibRound.RoundData storage round = data.rounds[rAddress];
        round.info.tournament = self;
        round.details = rDetails;

        if (rDetails.start < now) {
            round.details.start = now;
        }

        emit RoundCreated(rAddress);
        return rAddress;
    }

    /// @dev Creates a new Submission
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to the Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param sDetails  Submission details (title, descHash, fileHash)
    /// @return          Address of the created Submission
    function createSubmission(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibSubmission.SubmissionDetails sDetails) public returns (address) {
        require(sDetails.distribution.length == sDetails.contributors.length + 1, "Must include distribution for each contributor and the owner");

        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(tournament.entryFeePaid[sender].exists, "Must have paid entry fee");

        address rAddress = tournament.info.rounds[tournament.info.rounds.length - 1];
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.Open));

        LibRound.RoundData storage round = data.rounds[rAddress];

        address sAddress = new MatryxSubmission(info.version, info.system);

        MatryxSystem(info.system).setContractType(sAddress, uint256(LibSystem.ContractType.Submission));
        data.allSubmissions.push(sAddress);
        data.users[sender].submissions.push(sAddress);

        round.info.submissions.push(sAddress);

        LibSubmission.SubmissionData storage submission = data.submissions[sAddress];
        submission.info.owner = sender;
        submission.info.tournament = self;
        submission.info.round = rAddress;
        submission.info.timeSubmitted = now;
        submission.info.timeUpdated = now;
        submission.details = sDetails;

        // submission creator can view files
        submission.permittedToView[sender] = true;
        submission.allPermittedToView.push(sender);

        // tournament owner can view files
        address tOwner = tournament.info.owner;
        submission.permittedToView[tOwner] = true;
        submission.allPermittedToView.push(tOwner);

        emit SubmissionCreated(sAddress);
        return sAddress;
    }

    /// @dev Updates the details of this tournament
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to the Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param tDetails  New tournament details
    function updateDetails(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibTournament.TournamentDetails tDetails) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");

        if (tDetails.title[0] != 0x0) {
            tournament.details.title = tDetails.title;
        }
        if (tDetails.category != 0x0) {
            // get platform address
            address platform = MatryxSystem(info.system).getContract(info.version, "MatryxPlatform");
            IMatryxPlatform(platform).removeTournamentFromCategory(self);
            IMatryxPlatform(platform).addTournamentToCategory(self, tDetails.category);
        }
        if (tDetails.descHash[0] != 0x0) {
            tournament.details.descHash = tDetails.descHash;
        }
        if (tDetails.fileHash[0] != 0x0) {
            tournament.details.fileHash = tDetails.fileHash;
        }
        if (tDetails.entryFee != 0x0) {
            tournament.details.entryFee = tDetails.entryFee;
        }
    }

    /// @dev Transfers some of Tournament MTX to current Round
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    /// @param amount  Amount of MTX to transfer
    function transferToRound(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, uint256 amount) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");

        (,address rAddress) = getCurrentRound(self, sender, data);

        uint256 rState = IMatryxRound(rAddress).getState();
        require(rState <= uint256(LibGlobals.RoundState.InReview), "Cannot transfer after winners selected");

        uint256 balance = getBalance(self, sender, info, data);
        require(amount <= balance, "Tournament does not have the funds");

        IMatryxTournament(self).transferTo(info.token, rAddress, amount);
        data.rounds[rAddress].details.bounty = data.rounds[rAddress].details.bounty.add(amount);
    }

    /// @dev Transfers the round reward to its winning submissions during the winner selection process
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param rAddress  Address of the current round
    function transferToWinners(MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, address rAddress) internal {
        LibRound.WinnersData storage wData = data.rounds[rAddress].info.winners;

        uint256 distTotal = 0;
        for (uint256 i = 0; i < wData.submissions.length; i++) {
            distTotal = distTotal.add(wData.distribution[i]);
        }

        uint256 bounty = IMatryxRound(rAddress).getBalance();
        for (i = 0; i < wData.submissions.length; i++) {
            uint256 reward = wData.distribution[i].mul(bounty).div(distTotal);
            IMatryxRound(rAddress).transferTo(info.token, wData.submissions[i], reward);

            // TODO: revisit - do contributors get totalWinnings updated?
            address owner = data.submissions[wData.submissions[i]].info.owner;

            reward = reward.add(data.submissions[wData.submissions[i]].info.reward);
            data.submissions[wData.submissions[i]].info.reward = reward;
        }
    }

    /// @dev Select winners of the current round
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to the Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param wData     Winners data struct
    /// @param rDetails  New round details struct
    function selectWinners(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibRound.WinnersData wData, LibRound.RoundDetails rDetails) public {
        require(wData.submissions.length > 0, "Must specify winners");
        require(wData.submissions.length == wData.distribution.length, "Must include distribution for each winner");

        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");

        address rAddress = tournament.info.rounds[tournament.info.rounds.length - 1];
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.InReview), "Must be in review");

        LibRound.RoundData storage round = data.rounds[rAddress];
        LibRound.RoundDetails memory newRound;

        round.info.winners = wData;

        uint256 bounty = getBalance(self, sender, info, data);

        if (wData.action == uint256(LibGlobals.SelectWinnerAction.DoNothing)) {
            // create new round but don't start
            bounty = bounty < round.details.bounty ? bounty : round.details.bounty;

            // newRound.pKHash = rDetails.pKHash;
            newRound.start = round.details.end.add(round.details.review);
            newRound.end = newRound.start.add(round.details.end.sub(round.details.start));
            newRound.review = round.details.review;
            newRound.bounty = bounty;

            createRound(self, sender, info, data, newRound);
        }

        else if (wData.action == uint256(LibGlobals.SelectWinnerAction.StartNextRound)) {
            // create new round and start immediately
            round.info.closed = true;

            // newRound.pKHash = rDetails.pKHash;
            newRound.start = now;
            newRound.end = rDetails.end;
            newRound.review = rDetails.review;
            newRound.bounty = rDetails.bounty;

            createRound(self, sender, info, data, newRound);
        }

        else if (wData.action == uint256(LibGlobals.SelectWinnerAction.CloseTournament)) {
            // transfer rest of tournament balance to round and close tournament
            round.info.closed = true;

            IMatryxTournament(self).transferTo(info.token, rAddress, bounty);
        }

        transferToWinners(info, data, rAddress);
    }

    /// @dev Updates the details of an upcoming round that has not yet started
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to the Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param rDetails  New round details
    function updateNextRound(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibRound.RoundDetails rDetails) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");

        address rAddress = tournament.info.rounds[tournament.info.rounds.length - 1];
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.NotYetOpen), "Cannot edit open Round");

        if (tournament.info.rounds.length > 1 && rDetails.start > 0) {
            address currentRound = tournament.info.rounds[tournament.info.rounds.length - 2];
            LibRound.RoundDetails storage currentDetails = data.rounds[currentRound].details;
            require(rDetails.start >= currentDetails.end.add(currentDetails.review), "Round cannot start before end of review");
        }

        LibRound.RoundDetails storage details = data.rounds[rAddress].details;

        if (rDetails.start > 0) {
            details.start = rDetails.start;
        }
        if (rDetails.end > 0 && rDetails.end.sub(details.start) >= 1 seconds) { // TODO: change to hours
            details.end = rDetails.end;
        }
        if (rDetails.review > 0) { // TODO: review length restriction
            details.review = rDetails.review;
        }
        if (rDetails.bounty > 0) {
            uint256 tBalance = getBalance(self, sender, info, data);
            uint256 diff;

            if (rDetails.bounty > details.bounty) {
                diff = rDetails.bounty.sub(details.bounty);
                IMatryxTournament(self).transferTo(info.token, rAddress, diff);
            } else {
                diff = details.bounty.sub(rDetails.bounty);
                IMatryxRound(rAddress).transferTo(info.token, self, diff);
            }

            details.bounty = rDetails.bounty;
        }
    }

    /// @dev Starts the next Round after a SelectWinnersAction.DoNothing
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param data    Data struct on Platform
    function startNextRound(address self, address sender, MatryxPlatform.Data storage data) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");
        require(tournament.info.rounds.length > 1, "No round to start");

        address rAddress = tournament.info.rounds[tournament.info.rounds.length - 2];
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.HasWinners), "Must have selected winners");

        data.rounds[rAddress].info.closed = true;

        rAddress = tournament.info.rounds[tournament.info.rounds.length - 1];
        data.rounds[rAddress].details.start = now;
    }

    /// @dev Entrant can withdraw an even share of remaining balance from abandoned Tournament
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    function withdrawFromAbandoned(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];

        require(getState(self, sender, data) == uint256(LibGlobals.TournamentState.Abandoned), "Tournament must be abandoned");
        require(tournament.entryFeePaid[sender].exists, "Must be entrant");
        require(!tournament.hasWithdrawn[sender], "Already withdrawn");

        if (!tournament.hasBeenWithdrawnFrom) {
            address rAddress = tournament.info.rounds[tournament.info.rounds.length - 1];
            uint256 rBalance = IMatryxToken(info.token).balanceOf(rAddress);
            IMatryxRound(rAddress).transferTo(info.token, self, rBalance);
            tournament.hasBeenWithdrawnFrom = true;
            data.rounds[rAddress].info.closed = true;
        }

        uint256 tBalance = getBalance(self, sender, info, data);
        uint256 entrantCount = tournament.info.entrantCount;
        uint256 share = tBalance.mul(10**18).div(entrantCount).div(10**18);

        IMatryxTournament(self).transferTo(info.token, sender, share);

        tournament.hasWithdrawn[sender] = true;
        data.users[sender].totalWinnings = data.users[sender].totalWinnings.add(share);

        exit(self, sender, info, data);
    }

    /// @dev Closes Tournament after a SelectWinnersAction.DoNothing and transfers all funds to winners
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param data    Data struct on Platform
    function closeTournament(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");
        require(tournament.info.rounds.length > 1, "Must be in Round limbo");

        address rAddress = tournament.info.rounds[tournament.info.rounds.length - 2];
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.HasWinners), "Must have selected winners");

        // transfer from ghost into HasWinners Round
        address ghost = tournament.info.rounds[tournament.info.rounds.length - 1];
        uint256 ghostBalance = IMatryxToken(info.token).balanceOf(ghost);
        IMatryxRound(ghost).transferTo(info.token, rAddress, ghostBalance);

        // transfer remaining Tournament balance into HasWinners Round
        uint256 tBalance = getBalance(self, sender, info, data);
        IMatryxTournament(self).transferTo(info.token, rAddress, tBalance);

        // then transfer all to winners of that Round
        transferToWinners(info, data, rAddress);
    }

    /// @dev Tournament owner can recover tournament funds if the round ends with no submissions
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    function recoverFunds(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        require(sender == data.tournaments[self].info.owner, "Must be owner");

        LibTournament.TournamentData storage tournament = data.tournaments[self];
        address rAddress = tournament.info.rounds[tournament.info.rounds.length - 1];
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.Abandoned), "Tournament must be abandoned");
        require(data.rounds[rAddress].info.submissions.length == 0, "Must have 0 submissions");
        require(!tournament.hasWithdrawn[sender], "Already withdrawn");

        uint256 tBounty = getBalance(self, sender, info, data);
        uint256 rBounty = IMatryxRound(rAddress).getBalance();

        // recover remaining tournament and round funds
        IMatryxTournament(self).transferTo(info.token, sender, tBounty);
        IMatryxRound(rAddress).transferTo(info.token, sender, rBounty);

        // close round
        data.rounds[rAddress].info.closed = true;
        // update data
        tournament.hasWithdrawn[sender] = true;
        data.users[sender].totalSpent = data.users[sender].totalSpent.sub(tBounty).sub(rBounty);
    }
}
