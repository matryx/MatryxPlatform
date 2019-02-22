pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./MatryxForwarder.sol";
import "./LibTournament.sol";

contract MatryxTournament is MatryxForwarder {
    constructor (uint256 _version, address _system) MatryxForwarder(_version, _system) public {}
}

interface IMatryxTournament {
    function getInfo() external view returns (LibTournament.TournamentInfo memory);
    function getDetails() external view returns (LibTournament.TournamentDetails memory);

    function getBalance() external view returns (uint256);
    function getState() external view returns (uint256);
    function getRoundState(uint256 roundIndex) external view returns (uint256);
    function getCurrentRoundIndex() external view returns (uint256);

    function getRoundInfo(uint256 roundIndex) external view returns (LibTournament.RoundInfo memory);
    function getRoundDetails(uint256 roundIndex) external view returns (LibTournament.RoundDetails memory);

    function getSubmissionCount() external view returns (uint256);
    function getEntryFeePaid(address user) external view returns (uint256);
    function isEntrant(address user) external view returns (bool);

    function enter() external;
    function exit() external;
    function createSubmission(string calldata content, bytes32 commitHash) external;

    function updateDetails(LibTournament.TournamentDetails calldata tournamentDetails) external;
    function addToBounty(uint256 amount) external;
    function transferToRound(uint256 amount) external;

    function selectWinners(LibTournament.WinnersData calldata winnersData, LibTournament.RoundDetails calldata roundDetails) external;
    function updateNextRound(LibTournament.RoundDetails calldata roundDetails) external;
    function startNextRound() external;
    function closeTournament() external;

    function withdrawFromAbandoned() external;
    function recoverBounty() external;
}
