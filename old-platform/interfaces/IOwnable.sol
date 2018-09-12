pragma solidity ^0.4.18;
pragma experimental ABIEncoderV2;

interface IOwnable
{
    function getOwner() public view returns (address _owner);
    function isOwner(address _sender) public view returns (bool _isOwner);
    function transferOwnership(address newOwner) public;
}
