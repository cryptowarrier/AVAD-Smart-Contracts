//SPDX-License-Identifier: Unlicense
pragma solidity ^0.4.25;

import "./interfaces/BEP20Basic.sol";

contract BEP20 is BEP20Basic {
  function allowance(address owner, address spender) public view returns (uint256);

  function transferFrom(address from, address to, uint256 value) public returns (bool);

  function approve(address spender, uint256 value) public returns (bool);

  event Approval(address indexed owner, address indexed spender, uint256 value);
}