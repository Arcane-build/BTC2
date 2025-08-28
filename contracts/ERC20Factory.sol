pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CustomERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint256 _initialSupply, address _owner) ERC20(name, symbol) {
        _mint(_owner, _initialSupply);
    }
}

contract ERC20Factory {

    uint256 public totalDeployedContract;

    mapping(uint256 => address) public deployedIDToTokenAddress;

    event TokenDeployed(uint256 indexed id, address indexed tokenAddress, address indexed owner);

    function deployToken(string memory name, string memory symbol, uint256 _initialSupply, address _owner) public returns (ERC20) {
        uint256 count = totalDeployedContract++;
        CustomERC20 token = new CustomERC20(name, symbol, _initialSupply, _owner);
        deployedIDToTokenAddress[count] = address(token);
        emit TokenDeployed(count, address(token), _owner);
        return token;
    }
}