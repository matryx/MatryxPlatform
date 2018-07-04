pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

import "../../libraries/LibConstruction.sol";

interface IMatryxRoundFactory
{
	function createRound(address _platform, address _tournament, address _owner, uint256 _roundIndex, LibConstruction.RoundData roundData) public returns (address _roundAddress);
    function setContractAddress(bytes32 _nameHash, address _contractAddress) public;
    function getContractAddress(bytes32 _nameHash) public returns (address contractAddress);
}