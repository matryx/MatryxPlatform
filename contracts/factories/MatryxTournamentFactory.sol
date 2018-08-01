pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";
import "../../interfaces/IMatryxPlatform.sol";
import "../JMatryxTournament.sol";
import "../Ownable.sol";

contract MatryxTournamentFactory is Ownable {
    address public platformAddress;
    address public matryxRoundFactoryAddress;

    constructor(address _matryxRoundFactoryAddress) public {
        matryxRoundFactoryAddress = _matryxRoundFactoryAddress;
    }

    function createTournament(LibConstruction.TournamentData tournamentData, LibConstruction.RoundData roundData, address _owner) public returns (address _tournamentAddress) {
        JMatryxTournament newTournament = new JMatryxTournament(_owner, platformAddress, matryxRoundFactoryAddress, tournamentData, roundData);
        return newTournament;
    }

    function setPlatform(address _platformAddress) public onlyOwner
    {
        platformAddress = _platformAddress;
    }
}
