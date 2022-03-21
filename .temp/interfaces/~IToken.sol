//SPDX-License-Identifier: Unlicense
pragma solidity >=0.4.25;

interface IToken {
  function remainingMintableSupply() external view returns (uint256);

  function calculateTransferTaxes(address _from, uint256 _value) external view returns (uint256 adjustedValue, uint256 taxAmount);

  function transferFrom(
      address from,
      address to,
      uint256 value
  ) external returns (bool);

  function transfer(address to, uint256 value) external returns (bool);

  function balanceOf(address who) external view returns (uint256);

  function mintedSupply() external returns (uint256);

  function allowance(address owner, address spender)
  external
  view
  returns (uint256);

  function approve(address spender, uint256 value) external returns (bool);
}