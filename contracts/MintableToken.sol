//SPDX-License-Identifier: Unlicense
pragma solidity ^0.4.25;

import "./StandardToken.sol";
import "./Whitelist.sol";
import "./libraries/SafeMath.sol";

contract MintableToken is StandardToken, Whitelist {
  using SafeMath for uint256;
  event Mint(address indexed to, uint256 amount);
  event MintFinished();

  bool public mintingFinished = false;

  modifier canMint() {
      require(!mintingFinished);
      _;
  }

  /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) onlyWhitelisted canMint public returns (bool) {
      require(_to != address(0));
      totalSupply_ = totalSupply_.add(_amount);
      balances[_to] = balances[_to].add(_amount);
      emit Mint(_to, _amount);
      emit Transfer(address(0), _to, _amount);
      return true;
  }

  /**
   * @dev Function to stop minting new tokens.
   * @return True if the operation was successful.
   */
  function finishMinting() onlyWhitelisted canMint public returns (bool) {
      mintingFinished = true;
      emit MintFinished();
      return true;
  }
}