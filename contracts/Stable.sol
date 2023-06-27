// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// 0x7Ede7E4d692C0FCD1145d623846eB877aE28307D USD
// 0x7a68691FfCdEB24de655bcF227a3211F6B3E28c9 HTG
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Stable is ERC20, ERC20Burnable, Pausable, Ownable {

    address public  manager;

    constructor(string memory name ) ERC20(name, name) {
        manager = msg.sender;
    }

  
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
    
    function changeManager(address manager_) public onlyOwner returns (bool) {
        require(manager_ != address(0) , "Manager can't be null");
        manager = manager_;
        return true;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "unauthorized: not manager");
        _;
    }

    modifier onlyManagerOrOwner() {
        require(msg.sender == manager||msg.sender == owner(), "unauthorized: not owner or manager");
        _;
    }

    function mint(address to, uint256 amount) public onlyManagerOrOwner {
        _mint(to, amount);
    }
    
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}
