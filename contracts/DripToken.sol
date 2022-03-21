//SPDX-License-Identifier: Unlicense
pragma solidity ^0.4.25;

import "./MintableToken.sol";
import "./libraries/SafeMath.sol";

contract DripToken is MintableToken {


  struct Stats {
      uint256 txs;
      uint256 minted;
  }

  string public constant name = "AVAD TOKEN";
  string public constant symbol = "AVAD";
  uint8 public constant decimals = 18;
  uint256 public constant MAX_INT = 2**256 - 1;
  uint256 public constant targetSupply = MAX_INT;
  uint256 public totalTxs;
  uint256 public players;
  uint256 private mintedSupply_;

  mapping(address => Stats) private stats;

  address public vaultAddress;
  uint8 constant internal taxDefault = 10; // 10% tax on transfers

  mapping (address => uint8) private _customTaxRate;
  mapping (address => bool) private _hasCustomTax;

  mapping (address => bool) private _isExcluded;
  address[] private _excluded;

  event TaxPayed(address from, address vault, uint256 amount);
  /**
   * @dev default constructor
   */
  constructor(uint256 _initialMint) Ownable() public {
      addAddressToWhitelist(owner);
      mint(owner, _initialMint * 1e18);
      removeAddressFromWhitelist(owner);
  }

  function setVaultAddress(address _newVaultAddress) public onlyOwner {
      vaultAddress = _newVaultAddress;
  }

  /**
   * @dev Function to mint tokens (onlyOwner)
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) public returns (bool) {

      //Never fail, just don't mint if over
      if (_amount == 0 || mintedSupply_.add(_amount) > targetSupply) {
          return false;
      }

      //Mint
      super.mint(_to, _amount);
      mintedSupply_ = mintedSupply_.add(_amount);

      if (mintedSupply_ == targetSupply) {
          mintingFinished = true;
          emit MintFinished();
      }

      /* Members */
      if (stats[_to].txs == 0) {
          players += 1;
      }

      stats[_to].txs += 1;
      stats[_to].minted += _amount;

      totalTxs += 1;

      return true;

  }

  /**
   * @dev Override so that minting cannot be accidentally terminated
   */
  function finishMinting() onlyOwner canMint public returns (bool) {
      return false;
  }

  function calculateTransactionTax(uint256 _value, uint8 _tax) internal returns (uint256 adjustedValue, uint256 taxAmount){
      taxAmount = _value.mul(_tax).div(100);
      adjustedValue = _value.mul(SafeMath.sub(100, _tax)).div(100);
      return (adjustedValue, taxAmount);
  }

  /** @dev Transfers (using transferFrom) */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {

      (uint256 adjustedValue, uint256 taxAmount) = calculateTransferTaxes(_from, _value);

      if (taxAmount > 0){
          require(super.transferFrom(_from, vaultAddress, taxAmount));
          emit TaxPayed(_from, vaultAddress, taxAmount);
      }
      require(super.transferFrom(_from, _to, adjustedValue));

      /* Members */
      if (stats[_to].txs == 0) {
          players += 1;
      }

      stats[_to].txs += 1;
      stats[_from].txs += 1;

      totalTxs += 1;

      return true;


  }

  /** @dev Transfers */
  function transfer(address _to, uint256 _value) public returns (bool) {

      (uint256 adjustedValue, uint256 taxAmount) = calculateTransferTaxes(msg.sender, _value);
      if (taxAmount > 0){
          require(super.transfer(vaultAddress, taxAmount));
          emit TaxPayed(msg.sender, vaultAddress, taxAmount);
      }
      require(super.transfer(_to, adjustedValue), "Transfer Failed!");
      /* Members */
      if (stats[_to].txs == 0) {
          players += 1;
      }

      stats[_to].txs += 1;
      stats[msg.sender].txs += 1;

      totalTxs += 1;

      return true;
  }

  function calculateTransferTaxes(address _from, uint256 _value) public view returns (uint256 adjustedValue, uint256 taxAmount){
      adjustedValue = _value;
      taxAmount = 0;

      if (!_isExcluded[_from]) {
          uint8 taxPercent = taxDefault; // set to default tax 10%

          // set custom tax rate if applicable
          if (_hasCustomTax[_from]){
              taxPercent = _customTaxRate[_from];
          }

          (adjustedValue, taxAmount) = calculateTransactionTax(_value, taxPercent);
      }
      return (adjustedValue, taxAmount);
  }

  /** @dev Returns the supply still available to mint */
  function remainingMintableSupply() public view returns (uint256) {
      return targetSupply.sub(mintedSupply_);
  }

  /**
   * @dev Returns the cap for the token minting.
   */
  function cap() public view returns (uint256) {
      return targetSupply;
  }

  /**
  * @dev total number of minted tokens
  */
  function mintedSupply() public view returns (uint256) {
      return mintedSupply_;
  }

  /** @dev stats of player, (txs, minted) */
  function statsOf(address player) public view returns (uint256, uint256, uint256){
      return (balanceOf(player), stats[player].txs, stats[player].minted);
  }

  ///** @dev Returns the number of tokens minted by the player */
  function mintedBy(address player) public view returns (uint256){
      return stats[player].minted;
  }

  function setAccountCustomTax(address account, uint8 taxRate) external onlyOwner() {
      require(taxRate >= 0 && taxRate <= 100, "Invalid tax amount");
      _hasCustomTax[account] = true;
      _customTaxRate[account] = taxRate;
  }

  function removeAccountCustomTax(address account) external onlyOwner() {
      _hasCustomTax[account] = false;
  }

  function excludeAccount(address account) external onlyOwner() {
      require(!_isExcluded[account], "Account is already excluded");
      _isExcluded[account] = true;
      _excluded.push(account);
  }

  function includeAccount(address account) external onlyOwner() {
      require(_isExcluded[account], "Account is already excluded");
      for (uint256 i = 0; i < _excluded.length; i++) {
          if (_excluded[i] == account) {
              _excluded[i] = _excluded[_excluded.length - 1];
              _isExcluded[account] = false;
              delete _excluded[_excluded.length - 1];
              break;
          }
      }
  }

  function isExcluded(address account) public view returns (bool) {
      return _isExcluded[account];
  }
}