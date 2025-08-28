pragma solidity >=0.5.0;

interface IVestingVault {
    function vest(address user, uint256 amount) external;
    function claim() external;
    function claimable(address user) external view returns (uint256);
}