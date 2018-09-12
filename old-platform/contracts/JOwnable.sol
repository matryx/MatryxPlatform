pragma solidity ^0.4.18;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract JOwnable {
    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
        assembly {
            sstore(0, caller())
        }
    }

    function () public {
        assembly {
            switch div(calldataload(0), 0x0000000100000000000000000000000000000000000000000000000000000000)
            case 0x893d20e8 { // getOwner()
                return32(getOwner())
            }
            case 0x2f54bf6e { // isOwner(address)
                return32(isOwner(calldataload(0x04)))
            }
            case 0xf2fde38b { // transferOwnership(address)
                transferOwnership(calldataload(0x04))
            }
            default {
                revert(0, 0)
            }

            function return32(v) {
                mstore(0, v)
                return(0, 0x20)
            }

            function getOwner() -> o {
                o := sload(0)
            }

            function isOwner(sender) -> io {
                io := eq(sload(0), sender)
            }

            function transferOwnership(newOwner) {
                if iszero(eq(sload(0), caller())) { revert(0, 0) }
                if iszero(newOwner) { revert(0, 0) }
                sstore(0, newOwner)
            }
        }
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        assembly {
            if iszero(eq(sload(0), caller())) { revert(0, 0) }
        }
        _;
    }
}

interface IJOwnable {
    function getOwner() public view returns (address owner);
    function isOwner(address sender) public view returns (bool isOwner);
    function transferOwnership(address newOwner) public view;
}
