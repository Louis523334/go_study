// SPDX-License-Identifier: MIT
import "./interface/IDebtToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity ^0.8;

contract DebtToken is ERC20 {

    address owner;

    constructor (address _owner, string memory _name, string memory _symbol) public ERC20(_name, _symbol) {
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only minter can mint");
        _;
    }
    
    function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    /**
      * @notice burn the token
      * @dev function to burn token for an asset
      * @param _from means destory address
      * @param _amount means destory amount
      # @return true is success
      */
    function burn(address _from,uint256 _amount) public onlyOwner returns (bool) {
        _burn(_from, _amount);
        return true;
    }
    
}