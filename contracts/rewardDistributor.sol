// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RewardsDistributor is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // token => user => amount
    mapping(address => mapping(address => uint256)) public accrued;

    address public router;
    address public treasury;

    event Accrued(address indexed token, address indexed recipient, uint256 amount, address indexed trader, uint8 level);
    event Claimed(address indexed token, address indexed recipient, uint256 amount, address to);
    event RouterSet(address router);
    event TreasurySet(address treasury);

    error NotRouter();
    error ZeroAddress();

    constructor(address _router, address _treasury) {
        if (_router == address(0) || _treasury == address(0)) revert ZeroAddress();
        router = _router;
        treasury = _treasury;
        emit RouterSet(_router);
        emit TreasurySet(_treasury);
    }

    function setRouter(address _router) external onlyOwner {
        if (_router == address(0)) revert ZeroAddress();
        router = _router;
        emit RouterSet(_router);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    /// @notice Allocate 5 × 0.1% = 0.5% total. Empty upline slots backfill to treasury.
    function accrue(
        address token,
        address trader,
        address[5] memory upline,
        uint256 grossOut
    ) external {
        if (msg.sender != router) revert NotRouter();

        // Per-slot cut: 0.1%
        uint256 perSlot = (grossOut * 10) / 10_000; // 10 bps
        // Credit 5 slots (levels 1..5). Empty slot -> treasury.
        for (uint8 i = 0; i < 5; i++) {
            address r = upline[i];
            if (r == address(0)) r = treasury;
            accrued[token][r] += perSlot;
            emit Accrued(token, r, perSlot, trader, i + 1);
        }
    }

    function claim(address token, address to) external nonReentrant {
        uint256 amt = accrued[token][msg.sender];
        if (amt == 0) return;
        accrued[token][msg.sender] = 0;
        IERC20(token).safeTransfer(to, amt);
        emit Claimed(token, msg.sender, amt, to);
    }
}