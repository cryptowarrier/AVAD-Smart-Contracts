//SPDX-License-Identifier: Unlicense
pragma solidity ^0.4.25;

interface BEP20Basic {
  function totalSupply() external view returns (uint256);

  function balanceOf(address who) external view returns (uint256);

  function transfer(address to, uint256 value) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
}