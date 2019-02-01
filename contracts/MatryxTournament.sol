pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./LibGlobals.sol";

import "./MatryxSystem.sol";
import "./MatryxPlatform.sol";
import "./MatryxForwarder.sol";
import "./MatryxRound.sol";
import "./IToken.sol";
import "./MatryxCommit.sol";

contract MatryxTournament is MatryxForwarder {
    constructor (uint256 _version, address _system) MatryxForwarder(_version, _system) public {}
}

interface IMatryxTournament {
    function getVersion() external view returns (uint256);
    function getOwner() external view returns (address);

    function getTitle() external view returns (bytes32[3] memory);
    function getDescriptionHash() external view returns (bytes32[2] memory);
    function getBounty() external view returns (uint256);
    function getEntryFee() external view returns (uint256);
    function getRounds() external view returns (address[] memory);
    function getDetails() external view returns (LibTournament.TournamentDetails memory);

    function getBalance() external view returns (uint256);
    function getState() external view returns (uint256);
    function getCurrentRound() external view returns (uint256, address);

    function getSubmissionCount() external view returns (uint256);
    function getEntrantCount() external view returns (uint256);
    function getEntryFeePaid(address) external view returns (uint256);
    function isEntrant(address) external view returns (bool);

    function enter() external;
    function exit() external;
    function createSubmission(bytes32[3] calldata title, bytes32[2] calldata descHash, bytes32 commitHash) external;

    function updateDetails(LibTournament.TournamentDetails calldata) external;
    function addFunds(uint256) external;
    function transferToRound(uint256) external;

    function selectWinners(LibRound.WinnersData calldata, LibRound.RoundDetails calldata) external;
    function updateNextRound(LibRound.RoundDetails calldata) external;
    function startNextRound() external;
    function closeTournament() external;

    function withdrawFromAbandoned() external;
    function recoverFunds() external;
}

library LibTournament {
    using SafeMath for uint256;

    // TODO: change to 1 hours
    uint256 constant MIN_ROUND_LENGTH = 1 seconds;
    uint256 constant MAX_ROUND_LENGTH = 365 days;

    event RoundCreated(address roundAddress);
    event SubmissionCreated(address roundAddress, bytes32 commitHash);

    struct TournamentInfo {
        uint256 version;
        address owner;
        address[] rounds;
        uint256 entrantCount;
    }

    // All information needed for creation of Tournament
    struct TournamentDetails {
        bytes32[3] title;
        bytes32[2] descHash;
        bytes32[2] fileHash;
        uint256 bounty;
        uint256 entryFee;
    }

    // All state data and details of Tournament
    struct TournamentData {
        LibTournament.TournamentInfo info;
        LibTournament.TournamentDetails details;

        mapping(address=>LibGlobals.o_uint256) entryFeePaid;
        address[] allEntrants;
        uint256 totalEntryFees;

        mapping(address=>bool) hasWithdrawn;
        bool hasBeenWithdrawnFrom;
    }

    struct SubmissionData {
        bytes32[3] title;
        bytes32[2] descHash;
        uint256 reward;
        uint256 timeSubmitted;
    }

    /// @dev Returns the Version of this Tournament
    function getVersion(address self, address, MatryxPlatform.Data storage data) external view returns (uint256) {
        return data.tournaments[self].info.version;
    }

    /// @dev Returns the owner of this Tournament
    function getOwner(address self, address, MatryxPlatform.Data storage data) public view returns (address) {
        return data.tournaments[self].info.owner;
    }

    /// @dev Returns the title of this Tournament
    function getTitle(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[3] memory) {
        return data.tournaments[self].details.title;
    }

    /// @dev Returns the description hash of this Tournament
    function getDescriptionHash(address self, address, MatryxPlatform.Data storage data) public view returns (bytes32[2] memory) {
        return data.tournaments[self].details.descHash;
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
    function getRounds(address self, address, MatryxPlatform.Data storage data) public view returns (address[] memory) {
        return data.tournaments[self].info.rounds;
    }

    /// @dev Returns the data struct of this Tournament
    function getDetails(address self, address, MatryxPlatform.Data storage data) public view returns (LibTournament.TournamentDetails memory) {
        return data.tournaments[self].details;
    }

    /// @dev Returns the MTX balance of the Tournament
    function getBalance(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.balanceOf[self];
    }

    /// @dev Returns the state of this Tournament
    function getState(address self, address sender, MatryxPlatform.Data storage data) public view returns (uint256) {
        return LibTournamentHelper.getState(self, sender, data);
    }

    /// @dev Returns the current round number and address of this Tournament
    function getCurrentRound(address self, address sender, MatryxPlatform.Data storage data) public view returns (uint256, address) {
        return LibTournamentHelper.getCurrentRound(self, sender, data);
    }

    /// @dev Returns the total number of Submissions made in all rounds of this Tournament
    /// @param self  Address of this Tournament
    /// @param data  Data struct on Platform
    /// @return      Number of all Submissions in this Tournament
    function getSubmissionCount(address self, address sender, MatryxPlatform.Data storage data) public view returns (uint256) {
        return LibTournamentHelper.getSubmissionCount(self, sender, data);
    }

    /// @dev Returns the number of entrants in this Tournament
    /// @param self  Address of this Tournament
    /// @param data  Data struct on Platform
    /// @return      Number of entrants
    function getEntrantCount(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.tournaments[self].info.entrantCount;
    }

    /// @dev Returns the entry fee that an entrant has paid
    /// @param self      Address of this Tournament
    /// @param data      Data struct on Platform
    /// @param uAddress  Address of the tournament entrant
    /// @return          Entry fee uAddress has paid
    function getEntryFeePaid(address self, address, MatryxPlatform.Data storage data, address uAddress) public view returns (uint256) {
        return data.tournaments[self].entryFeePaid[uAddress].value;
    }

    /// @dev Returns true if address passed has entered the Tournament
    /// @param self     Address of this Tournament
    /// @param data     Data struct on Platform
    /// @param uAddress Address of some user
    function isEntrant(address self, address, MatryxPlatform.Data storage data, address uAddress) public view returns (bool) {
        return data.tournaments[self].entryFeePaid[uAddress].exists;
    }

    /// @dev Enter Tournament and pay entry fee
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    function enter(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibTournamentHelper.enter(self, sender, info, data);
    }

    /// @dev Exit Tournament and recover entry fee
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    function exit(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibTournamentHelper.exit(self, sender, info, data);
    }

    /// @dev Creates a new Round on this Tournament
    /// @param self      Address of this Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param rDetails  Details of the Round being created
    /// @return          Address of the created Round
    function createRound(address self, address, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibRound.RoundDetails memory rDetails) public returns (address) {
        LibTournament.TournamentData storage tournament = data.tournaments[self];

        uint256 version = IMatryxSystem(info.system).getVersion();
        address platform = IMatryxSystem(info.system).getContract(version, "MatryxPlatform");
        require(address(this) == platform, "Must be platform");
        require(data.balanceOf[self] >= rDetails.bounty, "Insufficient funds for Round");

        uint256 duration = rDetails.end.sub(rDetails.start);
        require(duration >= MIN_ROUND_LENGTH, "Round too short");
        require(duration <= MAX_ROUND_LENGTH, "Round too long");

        // TODO: add review time restrictions or auto review?

        address rAddress = address(new MatryxRound(tournament.info.version, info.system));

        IMatryxSystem(info.system).setContractType(rAddress, uint256(LibSystem.ContractType.Round));
        tournament.info.rounds.push(rAddress);
        data.allRounds.push(rAddress);

        data.balanceOf[self] = data.balanceOf[self].sub(rDetails.bounty);
        data.balanceOf[rAddress] = rDetails.bounty;

        LibRound.RoundData storage round = data.rounds[rAddress];
        round.info.version = tournament.info.version;
        round.info.tournament = self;
        round.details = rDetails;

        // if round started in past, shift end date to preserve duration
        if (rDetails.start < now) {
            round.details.start = now;
            round.details.end = now.add(round.details.end.sub(round.details.start));
        }

        emit RoundCreated(rAddress);
        return rAddress;
    }

    /// @dev Creates a new Submission
    /// @param self        Address of this Tournament
    /// @param sender      msg.sender to the Tournament
    /// @param data        Data struct on Platform
    /// @param title       Title of submission
    /// @param descHash    IPFS hash for description of submission
    /// @param commitHash  Commit hash to submit
    /// @return            Address of the created Submission
    function createSubmission(address self, address sender, MatryxPlatform.Data storage data, bytes32[3] memory title, bytes32[2] memory descHash, bytes32 commitHash) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        LibCommit.Commit storage commit = data.commits[commitHash];

        require(tournament.entryFeePaid[sender].exists, "Must have paid entry fee");
        require(commit.owner == sender, "Must be owner of commit");
        
        (,address rAddress) = getCurrentRound(self, sender, data);
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.Open), "Round must be Open");

        LibRound.RoundData storage round = data.rounds[rAddress];

        data.users[sender].submissions.push(commitHash);
        data.commitToRounds[commitHash].push(rAddress);

        LibTournament.SubmissionData storage submission = round.submissions[commitHash];
        submission.title = title;
        submission.descHash = descHash;
        submission.timeSubmitted = now;

        round.info.allSubmissions.push(commitHash);
        round.isSubmission[commitHash] = true;

        emit SubmissionCreated(rAddress, commitHash);
    }

    /// @dev Updates the details of this tournament
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to the Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param tDetails  New tournament details
    function updateDetails(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibTournament.TournamentDetails memory tDetails) public {
        LibTournamentHelper.updateDetails(self, sender, info, data, tDetails);
    }

    /// @dev Adds funds to the Tournament
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to the Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param amount    Amount of MTX to add
    function addFunds(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, uint256 amount) public {
        require(IToken(info.token).allowance(sender, address(this)) >= amount, "Must approve funds first");
        require(getState(self, sender, data) < uint256(LibGlobals.TournamentState.Closed), "Tournament must be active");

        data.totalBalance = data.totalBalance.add(amount);
        data.balanceOf[self] = data.balanceOf[self].add(amount);
        data.users[sender].totalSpent = data.users[sender].totalSpent.add(amount);
        require(IToken(info.token).transferFrom(sender, address(this), amount), "Transfer failed");
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
        require(amount <= data.balanceOf[self], "Tournament does not have the funds");

        (,address rAddress) = getCurrentRound(self, sender, data);
        uint256 rState = IMatryxRound(rAddress).getState();
        require(rState <= uint256(LibGlobals.RoundState.InReview), "Cannot transfer after winners selected");

        data.rounds[rAddress].details.bounty = data.rounds[rAddress].details.bounty.add(amount);

        data.balanceOf[self] = data.balanceOf[self].sub(amount);
        data.balanceOf[rAddress] = data.balanceOf[rAddress].add(amount);
    }

    /// @dev Transfers the round reward to its winning submissions during the winner selection process
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param rAddress  Address of the current round
    function transferToWinners(MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, address rAddress) internal {
        LibRound.RoundData storage round = data.rounds[rAddress];
        LibRound.WinnersData storage wData = round.info.winners;

        uint256 distTotal = 0;
        for (uint256 i = 0; i < wData.submissions.length; i++) {
            distTotal = distTotal.add(wData.distribution[i]);
        }

        uint256 bounty = data.balanceOf[rAddress];
        for (uint256 i = 0; i < wData.submissions.length; i++) {
            bytes32 winner = wData.submissions[i];
            uint256 reward = wData.distribution[i].mul(bounty).div(distTotal);

            data.balanceOf[rAddress] = data.balanceOf[rAddress].sub(reward);
            data.commitBalance[winner] = data.commitBalance[winner].add(reward);

            reward = reward.add(round.submissions[winner].reward);
            round.submissions[winner].reward = reward;
        }
    }

    /// @dev Select winners of the current round
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to the Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param wData     Winners data struct
    /// @param rDetails  New round details struct
    function selectWinners(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibRound.WinnersData memory wData, LibRound.RoundDetails memory rDetails) public {
        require(wData.submissions.length > 0, "Must specify winners");
        require(wData.submissions.length == wData.distribution.length, "Must include distribution for each winner");

        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");

        (,address rAddress) = getCurrentRound(self, sender, data);
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.InReview), "Must be in review");

        for (uint256 i = 0; i < wData.submissions.length; i++) {
            require(data.rounds[rAddress].isSubmission[wData.submissions[i]], "Must select winners from current round");
        }

        LibRound.RoundData storage round = data.rounds[rAddress];
        LibRound.RoundDetails memory newRound;

        round.info.winners = wData;

        uint256 bounty = data.balanceOf[self];

        if (wData.action == uint256(LibGlobals.SelectWinnerAction.DoNothing)) {
            // create new round but don't start
            bounty = bounty < round.details.bounty ? bounty : round.details.bounty;

            newRound.start = round.details.end.add(round.details.review);
            newRound.end = newRound.start.add(round.details.end.sub(round.details.start));
            newRound.review = round.details.review;
            newRound.bounty = bounty;

            createRound(self, sender, info, data, newRound);
        }

        else if (wData.action == uint256(LibGlobals.SelectWinnerAction.StartNextRound)) {
            // create new round and start immediately
            round.info.closed = true;

            newRound.start = now;
            newRound.end = rDetails.end;
            newRound.review = rDetails.review;
            newRound.bounty = rDetails.bounty;

            if (newRound.end.sub(newRound.start) < MIN_ROUND_LENGTH) {
                newRound.end = newRound.start.add(MIN_ROUND_LENGTH);
            }

            createRound(self, sender, info, data, newRound);
        }

        else if (wData.action == uint256(LibGlobals.SelectWinnerAction.CloseTournament)) {
            // transfer rest of tournament balance to round and close tournament
            round.info.closed = true;

            data.balanceOf[self] = 0;
            data.balanceOf[rAddress] = data.balanceOf[rAddress].add(bounty);
        }

        transferToWinners(info, data, rAddress);
    }

    /// @dev Updates the details of an upcoming round that has not yet started
    /// @param self      Address of this Tournament
    /// @param sender    msg.sender to the Tournament
    /// @param info      Info struct on Platform
    /// @param data      Data struct on Platform
    /// @param rDetails  New round details
    function updateNextRound(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibRound.RoundDetails memory rDetails) public {
        LibTournamentHelper.updateNextRound(self, sender, info, data, rDetails);

        // if either start or end modified, ensure duration is valid
        if (rDetails.start > 0 || rDetails.end > 0) {
            LibTournament.TournamentData storage tournament = data.tournaments[self];
            address rAddress = tournament.info.rounds[tournament.info.rounds.length - 1];
            LibRound.RoundDetails storage details = data.rounds[rAddress].details;

            uint256 duration = details.end.sub(details.start);
            require(duration >= MIN_ROUND_LENGTH, "Round too short");
            require(duration <= MAX_ROUND_LENGTH, "Round too long");
        }
    }

    /// @dev Starts the next Round after a SelectWinnersAction.DoNothing
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param data    Data struct on Platform
    function startNextRound(address self, address sender, MatryxPlatform.Data storage data) public {
        LibTournamentHelper.startNextRound(self, sender, data);
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
            (,address rAddress) = getCurrentRound(self, sender, data);
            uint256 rBalance = data.balanceOf[rAddress];

            tournament.hasBeenWithdrawnFrom = true;
            data.rounds[rAddress].info.closed = true;

            data.balanceOf[rAddress] = 0;
            data.balanceOf[self] = data.balanceOf[self].add(rBalance);
        }

        uint256 tBalance = data.balanceOf[self];
        uint256 entrantCount = tournament.info.entrantCount;
        uint256 share = tBalance.mul(10**18).div(entrantCount).div(10**18);

        tournament.hasWithdrawn[sender] = true;
        
        data.totalBalance = data.totalBalance.sub(share);
        data.balanceOf[self] = data.balanceOf[self].sub(share);
        IToken(info.token).transfer(sender, share);

        exit(self, sender, info, data);
    }

    /// @dev Closes Tournament after a SelectWinnersAction.DoNothing and transfers all funds to winners
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    function closeTournament(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");
        require(tournament.info.rounds.length > 1, "Must be in Round limbo");

        (,address rAddress) = getCurrentRound(self, sender, data);
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.HasWinners), "Must have selected winners");

        // close round
        data.rounds[rAddress].info.closed = true;

        // transfer from ghost into HasWinners Round
        address ghost = tournament.info.rounds[tournament.info.rounds.length - 1];
        data.balanceOf[rAddress] = data.balanceOf[rAddress].add(data.balanceOf[ghost]);
        data.balanceOf[ghost] = 0;

        // transfer remaining Tournament balance into HasWinners Round
        data.balanceOf[rAddress] = data.balanceOf[rAddress].add(data.balanceOf[self]);
        data.balanceOf[self] = 0;

        // then transfer all to winners of that Round
        transferToWinners(info, data, rAddress);

        // delete ghost round
        tournament.info.rounds.length = tournament.info.rounds.length - 1;
        delete data.rounds[ghost];
    }

    /// @dev Tournament owner can recover tournament funds if the round ends with no submissions
    /// @param self    Address of this Tournament
    /// @param sender  msg.sender to the Tournament
    /// @param info    Info struct on Platform
    /// @param data    Data struct on Platform
    function recoverFunds(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibTournamentHelper.recoverFunds(self, sender, info, data);
    }
}

library LibTournamentHelper {
    using SafeMath for uint256;

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

    function getSubmissionCount(address self, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        address[] storage rounds = data.tournaments[self].info.rounds;
        uint256 count = 0;

        for (uint256 i = 0; i < rounds.length; i++) {
            count += data.rounds[rounds[i]].info.allSubmissions.length;
        }

        return count;
    }

    function enter(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        uint256 entryFee = tournament.details.entryFee;

        require(data.users[sender].exists, "Must have entered Matryx");
        require(sender != tournament.info.owner, "Cannot enter own Tournament");
        require(!tournament.entryFeePaid[sender].exists, "Cannot enter Tournament more than once");
        require(getState(self, sender, data) < uint256(LibGlobals.TournamentState.Closed), "Cannot enter closed or abandoned Tournament");

        data.totalBalance = data.totalBalance.add(entryFee);
        IToken(info.token).transferFrom(sender, address(this), entryFee);

        tournament.entryFeePaid[sender].exists = true;
        tournament.entryFeePaid[sender].value = entryFee;
        tournament.totalEntryFees = tournament.totalEntryFees.add(entryFee);
        tournament.allEntrants.push(sender);
        tournament.info.entrantCount = tournament.info.entrantCount.add(1);
        data.users[sender].tournamentsEntered.push(self);
    }

    function exit(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(tournament.entryFeePaid[sender].exists, "Must be entrant");
        uint256 entryFeePaid = tournament.entryFeePaid[sender].value;

        if (entryFeePaid > 0) {
            tournament.totalEntryFees = tournament.totalEntryFees.sub(entryFeePaid);

            data.totalBalance = data.totalBalance.sub(entryFeePaid);
            IToken(info.token).transfer(sender, entryFeePaid);
        }

        tournament.entryFeePaid[sender].exists = false;
        tournament.info.entrantCount = tournament.info.entrantCount.sub(1);
    }

    function updateDetails(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibTournament.TournamentDetails memory tDetails) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");

        if (tDetails.title[0] != 0x0) {
            tournament.details.title = tDetails.title;
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

    function updateNextRound(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibRound.RoundDetails memory rDetails) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");

        address rAddress = tournament.info.rounds[tournament.info.rounds.length - 1];
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.NotYetOpen), "Cannot edit open Round");

        LibRound.RoundDetails storage details = data.rounds[rAddress].details;

        if (rDetails.start > 0) {
            if (tournament.info.rounds.length > 1) {
                (,address currentRound) = getCurrentRound(self, sender, data);
                LibRound.RoundDetails storage currentDetails = data.rounds[currentRound].details;
                require(rDetails.start >= currentDetails.end.add(currentDetails.review), "Round cannot start before end of review");
            }

            details.start = rDetails.start;
        }

        if (rDetails.end > 0) {
            details.end = rDetails.end;
        }

        if (rDetails.review > 0) { // TODO: review length restriction
            details.review = rDetails.review;
        }

        if (rDetails.bounty > 0) {
            uint256 diff;

            if (rDetails.bounty > details.bounty) {
                diff = rDetails.bounty.sub(details.bounty);
                data.balanceOf[self] = data.balanceOf[self].sub(diff);
                data.balanceOf[rAddress] = data.balanceOf[rAddress].add(diff);
            } else {
                diff = details.bounty.sub(rDetails.bounty);
                data.balanceOf[rAddress] = data.balanceOf[rAddress].sub(diff);
                data.balanceOf[self] = data.balanceOf[self].add(diff);
            }

            details.bounty = rDetails.bounty;
        }
    }

    function startNextRound(address self, address sender, MatryxPlatform.Data storage data) public {
        LibTournament.TournamentData storage tournament = data.tournaments[self];
        require(sender == tournament.info.owner, "Must be owner");
        require(tournament.info.rounds.length > 1, "No round to start");

        (,address rAddress) = getCurrentRound(self, sender, data);
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.HasWinners), "Must have selected winners");

        data.rounds[rAddress].info.closed = true;

        rAddress = tournament.info.rounds[tournament.info.rounds.length - 1];
        data.rounds[rAddress].details.start = now;
    }

    function recoverFunds(address self, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data) public {
        require(sender == data.tournaments[self].info.owner, "Must be owner");

        LibTournament.TournamentData storage tournament = data.tournaments[self];
        (,address rAddress) = getCurrentRound(self, sender, data);
        require(IMatryxRound(rAddress).getState() == uint256(LibGlobals.RoundState.Abandoned), "Tournament must be abandoned");
        require(data.rounds[rAddress].info.allSubmissions.length == 0, "Must have 0 submissions");
        require(!tournament.hasWithdrawn[sender], "Already withdrawn");

        uint256 funds = data.balanceOf[self].add(data.balanceOf[rAddress]);

        // close round
        data.rounds[rAddress].info.closed = true;
        // update data
        tournament.hasWithdrawn[sender] = true;

        data.users[sender].totalSpent = data.users[sender].totalSpent.sub(funds);

        // recover remaining tournament and round funds
        data.totalBalance = data.totalBalance.sub(funds);
        data.balanceOf[self] = 0;
        data.balanceOf[rAddress] = 0;
        IToken(info.token).transfer(sender, funds);
    }
}
