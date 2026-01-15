// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract veMTK is ERC20, Ownable {
    constructor() ERC20("Vote Escrow MTK", "veMTK") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    // make veMTK non-transferable
    function transfer(address, uint256) public pure override returns (bool) {
        revert("veMTK is non-transferable");
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert("veMTK is non-transferable");
    }
}

