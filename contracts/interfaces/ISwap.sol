//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

interface ISwap {
  /**
   * @dev Pricing function for converting between TRX && Tokens.
 * @param input_amount Amount of TRX or Tokens being sold.
 * @param input_reserve Amount of TRX or Tokens (input type) in exchange reserves.
 * @param output_reserve Amount of TRX or Tokens (output type) in exchange reserves.
 * @return Amount of TRX or Tokens bought.
 */
  function getInputPrice(
      uint256 input_amount,
      uint256 input_reserve,
      uint256 output_reserve
  ) external view returns (uint256);

  /**
   * @dev Pricing function for converting between TRX && Tokens.
 * @param output_amount Amount of TRX or Tokens being bought.
 * @param input_reserve Amount of TRX or Tokens (input type) in exchange reserves.
 * @param output_reserve Amount of TRX or Tokens (output type) in exchange reserves.
 * @return Amount of TRX or Tokens sold.
 */
  function getOutputPrice(
      uint256 output_amount,
      uint256 input_reserve,
      uint256 output_reserve
  ) external view returns (uint256);

  /**
   * @notice Convert TRX to Tokens.
 * @dev User specifies exact input (msg.value) && minimum output.
 * @param min_tokens Minimum Tokens bought.
 * @return Amount of Tokens bought.
 */
  function trxToTokenSwapInput(uint256 min_tokens)
  external
  payable
  returns (uint256);

  /**
   * @notice Convert TRX to Tokens.
 * @dev User specifies maximum input (msg.value) && exact output.
 * @param tokens_bought Amount of tokens bought.
 * @return Amount of TRX sold.
 */
  function trxToTokenSwapOutput(uint256 tokens_bought)
  external
  payable
  returns (uint256);

  /**
   * @notice Convert Tokens to TRX.
 * @dev User specifies exact input && minimum output.
 * @param tokens_sold Amount of Tokens sold.
 * @param min_trx Minimum TRX purchased.
 * @return Amount of TRX bought.
 */
  function tokenToTrxSwapInput(uint256 tokens_sold, uint256 min_trx)
  external
  returns (uint256);

  /**
   * @notice Convert Tokens to TRX.
 * @dev User specifies maximum input && exact output.
 * @param trx_bought Amount of TRX purchased.
 * @param max_tokens Maximum Tokens sold.
 * @return Amount of Tokens sold.
 */
  function tokenToTrxSwapOutput(uint256 trx_bought, uint256 max_tokens)
  external
  returns (uint256);

  /***********************************|
  |         Getter Functions          |
  |__________________________________*/

  /**
   * @notice Public price function for TRX to Token trades with an exact input.
 * @param trx_sold Amount of TRX sold.
 * @return Amount of Tokens that can be bought with input TRX.
 */
  function getTrxToTokenInputPrice(uint256 trx_sold)
  external
  view
  returns (uint256);

  /**
   * @notice Public price function for TRX to Token trades with an exact output.
 * @param tokens_bought Amount of Tokens bought.
 * @return Amount of TRX needed to buy output Tokens.
 */
  function getTrxToTokenOutputPrice(uint256 tokens_bought)
  external
  view
  returns (uint256);

  /**
   * @notice Public price function for Token to TRX trades with an exact input.
 * @param tokens_sold Amount of Tokens sold.
 * @return Amount of TRX that can be bought with input Tokens.
 */
  function getTokenToTrxInputPrice(uint256 tokens_sold)
  external
  view
  returns (uint256);

  /**
   * @notice Public price function for Token to TRX trades with an exact output.
 * @param trx_bought Amount of output TRX.
 * @return Amount of Tokens needed to buy output TRX.
 */
  function getTokenToTrxOutputPrice(uint256 trx_bought)
  external
  view
  returns (uint256);

  /**
   * @return Address of Token that is sold on this exchange.
 */
  function tokenAddress() external view returns (address);

  function tronBalance() external view returns (uint256);

  function tokenBalance() external view returns (uint256);

  function getTrxToLiquidityInputPrice(uint256 trx_sold)
  external
  view
  returns (uint256);

  function getLiquidityToReserveInputPrice(uint256 amount)
  external
  view
  returns (uint256, uint256);

  function txs(address owner) external view returns (uint256);

  /***********************************|
  |        Liquidity Functions        |
  |__________________________________*/

  /**
   * @notice Deposit TRX && Tokens (token) at current ratio to mint SWAP tokens.
 * @dev min_liquidity does nothing when total SWAP supply is 0.
 * @param min_liquidity Minimum number of SWAP sender will mint if total SWAP supply is greater than 0.
 * @param max_tokens Maximum number of tokens deposited. Deposits max amount if total SWAP supply is 0.
 * @return The amount of SWAP minted.
 */
  function addLiquidity(uint256 min_liquidity, uint256 max_tokens)
  external
  payable
  returns (uint256);

  /**
   * @dev Burn SWAP tokens to withdraw TRX && Tokens at current ratio.
 * @param amount Amount of SWAP burned.
 * @param min_trx Minimum TRX withdrawn.
 * @param min_tokens Minimum Tokens withdrawn.
 * @return The amount of TRX && Tokens withdrawn.
 */
  function removeLiquidity(
      uint256 amount,
      uint256 min_trx,
      uint256 min_tokens
  ) external returns (uint256, uint256);
}