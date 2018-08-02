pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "../Ownable.sol";
import "../MatryxRound.sol";
import "../../interfaces/IMatryxPlatform.sol";
import "../../libraries/LibConstruction.sol";

contract MatryxRoundFactory is Ownable {
    address public matryxSubmissionFactoryAddress;

    mapping(bytes32=>address) contracts;

    constructor(address _matryxSubmissionFactoryAddress) public {
        matryxSubmissionFactoryAddress = _matryxSubmissionFactoryAddress;
    }

    function createRound(address _owner, address _platformAddress, address _tournamentAddress, LibConstruction.RoundData roundData) public returns (address _roundAddress) {
        MatryxRound newRound = new MatryxRound(_owner, _platformAddress, _tournamentAddress, matryxSubmissionFactoryAddress, roundData);
        return newRound;
    }

    /// @dev Sets an address for a contract the platform should know about.
    /// @param _nameHash Keccak256 hash of the name of the contract to give an address to.
    /// @param _contractAddress Address to be assigned for the given contract name.
    function setContractAddress(bytes32 _nameHash, address _contractAddress) public onlyOwner
    {
        contracts[_nameHash] = _contractAddress;
    }

    /// @dev Gets the address of a contract the platform knows about.
    /// @param _nameHash Keccak256 hash of the name of the contract to look for.
    /// @return Address of the contract with the designated name.
    function getContractAddress(bytes32 _nameHash) public view returns (address contractAddress)
    {
        return contracts[_nameHash];
    }
}
