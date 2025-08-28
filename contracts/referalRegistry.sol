// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ReferralRegistry {
    struct Chain {
        address[5] upline;
        bool locked;
    }

    mapping(bytes32 => address) public codeOwner;     // broker code -> owner
    mapping(address => Chain) public chainOf;         // trader -> upline snapshot

    event CodeCreated(address indexed owner, bytes32 indexed codeHash, string code);
    event ReferrerSet(
        address indexed trader,
        address indexed inviter,
        bytes32 indexed codeHash,
        address[5] upline
    );

    error CodeTaken();
    error InvalidCode();
    error AlreadyLocked();
    error SelfReferral();

    function createCode(string calldata code) external {
        bytes32 h = keccak256(abi.encodePacked(code));
        if (codeOwner[h] != address(0)) revert CodeTaken();
        codeOwner[h] = msg.sender;
        emit CodeCreated(msg.sender, h, code);
    }

    function setReferrerWithCode(bytes32 codeHash) external {
        Chain storage c = chainOf[msg.sender];
        if (c.locked) revert AlreadyLocked();

        address inviter = codeOwner[codeHash];
        if (inviter == address(0)) revert InvalidCode();
        if (inviter == msg.sender) revert SelfReferral();

        // Build upline snapshot from inviter
        Chain storage pi = chainOf[inviter];
        c.upline[0] = inviter;
        for (uint i = 1; i < 5; i++) {
            c.upline[i] = pi.upline[i-1];
        }
        c.locked = true;
        emit ReferrerSet(msg.sender, inviter, codeHash, c.upline);
    }

    function getUpline(address trader) external view returns (address[5] memory) {
        return chainOf[trader].upline;
    }

    function isLocked(address trader) external view returns (bool) {
        return chainOf[trader].locked;
    }
}
