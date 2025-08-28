// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './interfaces/IERC20.sol';
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RewardsDistributor is ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => uint256)) public accrued; // token => user => amount
    address public router;

    event Accrued(address indexed token, address indexed recipient, uint256 amount, address indexed trader, uint8 level);
    event Claimed(address indexed token, address indexed recipient, uint256 amount, address to);
    event RouterSet(address router);

    error NotRouter();

    constructor(address _router) {
        router = _router;
        emit RouterSet(_router);
    }

    function setRouter(address _router) external {
        // make ownable if needed; omitted here for brevity
        router = _router;
        emit RouterSet(_router);
    }

    function accrue(
        address token,
        address trader,
        address[5] memory upline,
        uint256 grossOut
    ) external {
        if (msg.sender != router) revert NotRouter();
        // 10 bps per level present
        for (uint8 i = 0; i < 5; i++) {
            address r = upline[i];
            if (r == address(0)) break;
            uint256 cut = (grossOut * 10) / 10_000; // 0.1%
            accrued[token][r] += cut;
            emit Accrued(token, r, cut, trader, i + 1);
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
