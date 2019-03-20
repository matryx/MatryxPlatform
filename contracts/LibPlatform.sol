pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./LibGlobals.sol";
import "./IToken.sol";

import "./MatryxSystem.sol";
import "./MatryxCommit.sol";
import "./MatryxTournament.sol";

library LibPlatform {
    using SafeMath for uint256;

    event TournamentCreated(address tournament, address creator);
    event TournamentBountyAdded(address tournament, address donor, uint256 amount);

    function _canUseMatryx(MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, address user) internal returns (bool) {
        if (data.blacklist[user]) return false;
        if (data.whitelist[user]) return true;

        if (IToken(info.token).balanceOf(user) > 0) {
            data.whitelist[user] = true;
            return true;
        }

        return false;
    }

    /// @dev Gets information about the Platform
    /// @param info    Platform info struct
    /// @return  Info Struct that contains system, token, and owner
    function getInfo(address, address, MatryxPlatform.Info storage info) public view returns (MatryxPlatform.Info memory) {
        return info;
    }

    /// @dev Return if a Tournament exists
    /// @param data      Platform data struct
    /// @param tAddress  Tournament address
    /// @return          true if Tournament exists
    function isTournament(address, address, MatryxPlatform.Data storage data, address tAddress) public view returns (bool) {
        return data.tournaments[tAddress].info.owner != address(0);
    }

    /// @dev Return if a Commit exists
    /// @param data      Platform data struct
    /// @param cHash     Commit hash
    /// @return          true if Commit exists
    function isCommit(address, address, MatryxPlatform.Data storage data, bytes32 cHash) public view returns (bool){
        return data.commits[cHash].owner != address(0);
    }

    /// @dev Return if a Submission exists
    /// @param data      Platform data struct
    /// @param sHash     Submission hash
    /// @return          true if Submission exists
    function isSubmission(address, address, MatryxPlatform.Data storage data, bytes32 sHash) public view returns (bool){
        return data.submissions[sHash].tournament != address(0);
    }

    /// @dev Return total allocated MTX in Platform
    /// @param data  Platform data struct
    /// @return      Total allocated MTX in Platform
    function getTotalBalance(address, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.totalBalance;
    }

    /// @dev Return total number of Tournaments
    /// @param data  Platform data struct
    /// @return      Number of Tournaments on Platform
    function getTournamentCount(address, address, MatryxPlatform.Data storage data) public view returns (uint256) {
        return data.allTournaments.length;
    }

    /// @dev Return all Tournaments addresses
    /// @param data  Platform data struct
    /// @return      Array of Tournament addresses
    function getTournaments(address, address, MatryxPlatform.Data storage data) public view returns (address[] memory) {
        return data.allTournaments;
    }

    /// @dev Returns a Submission by its hash
    /// @param data            Platform data struct
    /// @param submissionHash  Submission hash
    /// @return                The submission details
    function getSubmission(address, address, MatryxPlatform.Data storage data, bytes32 submissionHash) external view returns (LibTournament.SubmissionData memory) {
        return data.submissions[submissionHash];
    }

    /// @dev Blacklists a user address
    /// @param info  Platform info struct
    /// @param data  Platform data struct
    /// @param user  User address
    function blacklist(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, address user) public {
        require(sender == info.owner, "Must be Platform owner");
        data.blacklist[user] = true;
    }

    /// @dev Creates a Tournament
    /// @param sender    msg.sender to Platform
    /// @param info      Platform info struct
    /// @param data      Platform data struct
    /// @param tDetails  Tournament details (content, bounty, entryFee)
    /// @param rDetails  Round details (start, end, review, bounty)
    /// @return          Address of the created Tournament
    function createTournament(address, address sender, MatryxPlatform.Info storage info, MatryxPlatform.Data storage data, LibTournament.TournamentDetails memory tDetails, LibTournament.RoundDetails memory rDetails) public returns (address) {
        require(_canUseMatryx(info, data, sender), "Must be allowed to use Matryx");

        require(tDetails.bounty > 0, "Tournament bounty must be greater than 0");
        require(rDetails.bounty <= tDetails.bounty, "Round bounty cannot exceed Tournament bounty");
        require(IToken(info.token).allowance(sender, address(this)) >= tDetails.bounty, "Insufficient MTX");

        uint256 version = IMatryxSystem(info.system).getVersion();
        address tAddress = address(new MatryxTournament(version, info.system));

        IMatryxSystem(info.system).setContractType(tAddress, uint256(LibSystem.ContractType.Tournament));
        data.allTournaments.push(tAddress);

        LibTournament.TournamentData storage tournament = data.tournaments[tAddress];
        tournament.info.version = version;
        tournament.info.owner = sender;
        tournament.details = tDetails;

        data.totalBalance = data.totalBalance.add(tDetails.bounty);
        data.tournamentBalance[tAddress] = tDetails.bounty;
        require(IToken(info.token).transferFrom(sender, address(this), tDetails.bounty), "Transfer failed");

        LibTournament.createRound(tAddress, address(this), info, data, rDetails);

        emit TournamentCreated(tAddress, sender);
        emit TournamentBountyAdded(tAddress, sender, tDetails.bounty);

        return tAddress;
    }
}
