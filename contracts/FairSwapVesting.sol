pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title VestingVault
 * @notice Immutable vault that releases exactly 1 token (in whole-token units) per day to each user
 *         until their vested allocation is fully claimed. Only the paired CustomV2Pair can create vesting.
 *         No owner/admin; no upgradability; no backdoors.
 */
contract VestingVault {
    IERC20Metadata public immutable token;       // token0 (e.g., BTC2)
    address public immutable depositor;          // the CustomV2Pair that calls vest()
    uint8   public immutable tokenDecimals;
    uint256 public immutable ONE_TOKEN;          // 10 ** tokenDecimals
    uint256 public constant SECONDS_PER_DAY = 1 days;

    struct Vest {
        uint256 totalAllocated;  // total tokens allocated for user (in token units)
        uint256 claimed;         // total tokens claimed so far (in token units)
        uint256 startTime;       // when vesting started (first allocation time)
    }

    mapping(address => Vest) public vestings;

    event Vested(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);

    modifier onlyDepositor() {
        require(msg.sender == depositor, "Vault: not authorized");
        _;
    }

    constructor(IERC20Metadata _token, address _depositor) {
        require(address(_token) != address(0), "Vault: token zero");
        require(_depositor != address(0), "Vault: depositor zero");
        token = _token;
        depositor = _depositor;
        tokenDecimals = _token.decimals();
        ONE_TOKEN = 10 ** uint256(tokenDecimals);
    }

    /**
     * @notice Record a vesting allocation for `user`. Must be called by the pair
     *         *after* it has transferred `amount` token0 into this vault.
     */
    function vest(address user, uint256 amount) external onlyDepositor {
        require(user != address(0), "Vault: user zero");
        require(amount > 0, "Vault: amount zero");

        Vest storage v = vestings[user];
        if (v.startTime == 0) v.startTime = block.timestamp;
        v.totalAllocated += amount;

        emit Vested(user, amount);
    }

    /**
     * @notice Claim vested tokens (1 token per day schedule).
     *         If user has less than N whole tokens remaining, they can still claim the remainder.
     */
    function claim() external {
        uint256 claimableAmt = claimable(msg.sender);
        require(claimableAmt > 0, "Vault: nothing to claim");

        Vest storage v = vestings[msg.sender];
        v.claimed += claimableAmt;

        require(token.transfer(msg.sender, claimableAmt), "Vault: transfer failed");
        emit Claimed(msg.sender, claimableAmt);
    }

    /**
     * @notice View how many tokens are currently claimable for `user`.
     *         Schedule: 1 whole token per day since startTime, capped by totalAllocated.
     */
    function claimable(address user) public view returns (uint256) {
        Vest memory v = vestings[user];
        if (v.totalAllocated == 0 || v.startTime == 0) return 0;

        // whole tokens unlocked so far
        uint256 daysPassed = (block.timestamp - v.startTime) / SECONDS_PER_DAY;
        uint256 unlocked = daysPassed * ONE_TOKEN;

        if (unlocked > v.totalAllocated) unlocked = v.totalAllocated;
        if (unlocked <= v.claimed) return 0;

        return unlocked - v.claimed;
    }
}
