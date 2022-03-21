//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

interface ITokenMint {

  function mint(address beneficiary, uint256 tokenAmount) external returns (uint256);

  function estimateMint(uint256 _amount) external returns (uint256);

  function remainingMintableSupply() external returns (uint256);
}