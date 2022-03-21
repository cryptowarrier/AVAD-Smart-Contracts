//SPDX-License-Identifier: Unlicense
pragma solidity ^0.4.25;

import "./interfaces/IToken.sol";
import "./Whitelist.sol";

contract Vault is Whitelist{

  IToken internal token; // address of the BEP20 token traded on this contract

  //We receive Drip token on this vault
  constructor(address token_addr) public{
      token = IToken(token_addr);
  }

  function withdraw(uint256 _amount) public onlyWhitelisted {
      require(token.transfer(msg.sender, _amount));
  }
}