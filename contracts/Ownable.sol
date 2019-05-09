pragma solidity ^0.5.7;


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;
    address pendingOwner;

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public
    {
        owner = msg.sender;
    }

    function getOwner() public view returns (address _owner)
    {
        return owner;
    }

    function isOwner(address _sender) public view returns (bool _isOwner)
    {
        bool senderIsOwner = (owner == _sender);
        return senderIsOwner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner()
    {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner
    {
        require(newOwner != address(0));
        pendingOwner = newOwner;
    }

    /**
     * @dev Allows the pending owner to accept ownership transfer
     */
    function acceptOwnership() public
    {
        require(msg.sender == pendingOwner, "Must be the pending owner");
        owner = pendingOwner;
        pendingOwner = address(0);
    }
}
