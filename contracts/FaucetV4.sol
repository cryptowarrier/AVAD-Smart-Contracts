//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISwap.sol";
import "./interfaces/IToken.sol";
import "./interfaces/ITokenMint.sol";
import "./interfaces/IDripVault.sol";
import "./libraries/SafeMath.sol";

contract FaucetV4 is Ownable {

  using SafeMath for uint256;

  struct User {
      //Referral Info
      address upline;
      uint256 referrals;
      uint256 total_structure;

      //Long-term Referral Accounting
      uint256 direct_bonus;
      uint256 match_bonus;

      //Deposit Accounting
      uint256 deposits;
      uint256 deposit_time;

      //Payout and Roll Accounting
      uint256 payouts;
      uint256 rolls;

      //Upline Round Robin tracking
      uint256 ref_claim_pos;

      uint256 accumulatedDiv;
  }

  struct Airdrop {
      //Airdrop tracking
      uint256 airdrops;
      uint256 airdrops_received;
      uint256 last_airdrop;
  }

  struct Custody {
      address manager;
      address beneficiary;
      uint256 last_heartbeat;
      uint256 last_checkin;
      uint256 heartbeat_interval;
  }

  address public dripVaultAddress;
  address public devAddr;
  uint256 public devFee = 20; // percentage

  ITokenMint private tokenMint;
  IToken private br34pToken;
  IToken private dripToken;
  IDripVault private dripVault;

  mapping(address => User) public users;
  mapping(address => Airdrop) public airdrops;
  mapping(address => Custody) public custody;
  mapping(address => bool) public testClaim;

  uint256 public CompoundTax;
  uint256 public ExitTax = 10;

  uint256 private payoutRate;
  uint256 private ref_depth;
  uint256 private ref_bonus;

  uint256 private minimumInitial;
  uint256 public minimumAmount;

  uint256 public deposit_bracket_size = 5;     // @BB 5% increase whale tax per 10000 tokens... 10 below cuts it at 50% since 5 * 10
  uint256 public max_payout_cap;           // 100k DRIP or 10% of supply
  uint256 private deposit_bracket_max = 5;     // sustainability fee is (bracket * 5)
  uint256 public testAmount = 100;

  uint256[] public ref_balances;

  uint256 public total_airdrops;
  uint256 public total_users;
  uint256 public total_deposited;
  uint256 public total_withdraw;
  uint256 public total_bnb;
  uint256 public total_txs;

  uint256 public constant MAX_UINT = 2**256 - 1;

  event Upline(address indexed addr, address indexed upline);
  event NewDeposit(address indexed addr, uint256 amount);
  event Leaderboard(address indexed addr, uint256 referrals, uint256 total_deposits, uint256 total_payouts, uint256 total_structure);
  event MatchPayout(address indexed addr, address indexed from, uint256 amount);
  event BalanceTransfer(address indexed _src, address indexed _dest, uint256 _deposits, uint256 _payouts);
  event Withdraw(address indexed addr, uint256 amount);
  event LimitReached(address indexed addr, uint256 amount);
  event NewAirdrop(address indexed from, address indexed to, uint256 amount, uint256 timestamp);
  event ManagerUpdate(address indexed addr, address indexed manager, uint256 timestamp);
  event BeneficiaryUpdate(address indexed addr, address indexed beneficiary);
  event HeartBeatIntervalUpdate(address indexed addr, uint256 interval);
  event HeartBeat(address indexed addr, uint256 timestamp);
  event Checkin(address indexed addr, uint256 timestamp);

  constructor(address _dripToken, address _dripVault, address _devAddr) {
    dripToken = IToken(_dripToken);
    dripVaultAddress = _dripVault;
    tokenMint = ITokenMint(_dripToken);
    dripVault = IDripVault(_dripVault);
    devAddr = _devAddr;
  }

  /* ========== INITIALIZER ========== */

//   function initialize() external initializer {
//       __Ownable_init();
//   }

  //@dev Default payable is empty since Faucet executes trades and recieves BNB
  fallback() external payable {
      //Do nothing, BNB will be sent to contract when selling tokens
  }

  /****** Administrative Functions *******/
  function updatePayoutRate(uint256 _newPayoutRate) public onlyOwner {
      payoutRate = _newPayoutRate;
  }

  function setDevFee(uint256 _devFee) public onlyOwner {
      devFee = _devFee;
  }

  function setDevAddr(address _devAddr) public {
      require(msg.sender == devAddr, "You are not dev!");
      devAddr = _devAddr;
  }

  function updateRefDepth(uint256 _newRefDepth) public onlyOwner {
      ref_depth = _newRefDepth;
  }

  function updateRefBonus(uint256 _newRefBonus) public onlyOwner {
      ref_bonus = _newRefBonus;
  }

  function updateInitialDeposit(uint256 _newInitialDeposit) public onlyOwner {
      minimumInitial = _newInitialDeposit;
  }

  function updateCompoundTax(uint256 _newCompoundTax) public onlyOwner {
      require(_newCompoundTax >= 0 && _newCompoundTax <= 20);
      CompoundTax = _newCompoundTax;
  }

  function updateExitTax(uint256 _newExitTax) public onlyOwner {
      require(_newExitTax >= 0 && _newExitTax <= 20);
      ExitTax = _newExitTax;
  }

  function updateDepositBracketSize(uint256 _newBracketSize) public onlyOwner {
      deposit_bracket_size = _newBracketSize;
  }

  function updateMaxPayoutCap(uint256 _newPayoutCap) public onlyOwner {
      max_payout_cap = _newPayoutCap;
  }

  function updateHoldRequirements(uint256[] memory _newRefBalances) public onlyOwner {
      require(_newRefBalances.length == ref_depth);
      delete ref_balances;
      for(uint8 i = 0; i < ref_depth; i++) {
          ref_balances.push(_newRefBalances[i]);
      }
  }

  function setMinAmount(uint256 _amount) public onlyOwner {
    minimumAmount = _amount;
  }

  /********** User Fuctions **************************************************/
  
  //@dev Deposit specified DRIP amount supplying an upline referral
  function deposit(uint256 _amount) external {

      address _addr = msg.sender;

      (uint256 realizedDeposit, uint256 _taxAmount) = dripToken.calculateTransferTaxes(_addr, _amount);
      uint256 _total_amount = realizedDeposit;

      require(_amount >= minimumAmount, "Minimum deposit");


      //If fresh account require a minimal amount of DRIP
      if (users[_addr].deposits == 0){
          require(_amount >= minimumInitial, "Initial deposit too low");
      }

      uint256 taxedDivs;
      // Claim if divs are greater than 1% of the deposit
      if (claimsAvailable(_addr) > _amount / 100){
          uint256 claimedDivs = _claim(_addr, true);
          taxedDivs = claimedDivs.mul(SafeMath.sub(100, CompoundTax)).div(100); // 5% tax on compounding
          _total_amount += taxedDivs;
          taxedDivs = taxedDivs / 2;
      }
      // Transfer Drip to the dev wallet
      dripToken.transferFrom(
        _addr,
        devAddr,
        _taxAmount * devFee / 100
      );

      //Transfer DRIP to the contract
      require(
          dripToken.transferFrom(
              _addr,
              address(dripVaultAddress),
              realizedDeposit + _taxAmount * (100 - devFee) / 100
          ),
          "DRIP token transfer failed"
      );
      /*
      User deposits 10;
      1 goes for tax, 9 are realized deposit
      */

      _deposit(_addr, _total_amount);

      emit Leaderboard(_addr, users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure);
      total_txs++;

  }

  //@dev Claim, transfer, withdraw from vault
  function claim() external {
      require(block.timestamp - users[msg.sender].deposit_time >= 1 days, "You can't calim befor 1 day!");

      //Checkin for custody management.  If a user rolls for themselves they are active
      address _addr = msg.sender;

      _claim_out(_addr);
  }

  //@dev Claim and deposit;
  function roll() public {

      //Checkin for custody management.  If a user rolls for themselves they are active

      address _addr = msg.sender;

      _roll(_addr);
  }

  /********** Internal Fuctions **************************************************/


  //@dev Deposit
  function _deposit(address _addr, uint256 _amount) internal {
      //Can't maintain upline referrals without this being set

    //   require(users[_addr].upline != address(0) || _addr == owner(), "No upline");

      //stats
      users[_addr].deposits += _amount;
      users[_addr].deposit_time = block.timestamp;

      total_deposited += _amount;

      //events
      emit NewDeposit(_addr, _amount);

  }

  //@dev General purpose heartbeat in the system used for custody/management planning
  function _heart(address _addr) internal {
      custody[_addr].last_heartbeat = block.timestamp;
      emit HeartBeat(_addr, custody[_addr].last_heartbeat);
  }

  //@dev Claim and deposit;
  function _roll(address _addr) internal {

      uint256 to_payout = _claim(_addr, false);

      uint256 payout_taxed = to_payout.mul(SafeMath.sub(100, CompoundTax)).div(100); // 5% tax on compounding

      //Recycle baby!
      _deposit(_addr, payout_taxed);

      //track rolls for net positive
      users[_addr].rolls += payout_taxed;

      emit Leaderboard(_addr, users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure);
      total_txs++;

  }


  //@dev Claim, transfer, and topoff
  function _claim_out(address _addr) internal {
    
      uint256 to_payout = _claim(_addr, true);

      uint256 vaultBalance = dripToken.balanceOf(dripVaultAddress);
      if (vaultBalance < to_payout) {
          uint256 differenceToMint = to_payout.sub(vaultBalance);
          tokenMint.mint(dripVaultAddress, differenceToMint);
      }
      dripVault.withdraw(to_payout);
      uint256 realizedPayout = to_payout.mul(SafeMath.sub(100, ExitTax)).div(100); // 10% tax on withdraw
      require(
        dripToken.transfer(
          _addr,
          realizedPayout
        ),
        "DRIP token transfer failed"
      );
      emit Leaderboard(_addr, users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure);
      total_txs++;

  }

  function claimForTest() public {
      require(!testClaim[msg.sender], 'You already claimed!');
      uint256 to_payout = testAmount * 1e18;

      uint256 vaultBalance = dripToken.balanceOf(dripVaultAddress);
      if (vaultBalance < to_payout) {
          tokenMint.mint(dripVaultAddress, to_payout);
      }
 
      dripVault.withdraw(to_payout);
      testClaim[msg.sender] = true;
      require(
        dripToken.transfer(
          msg.sender,
          to_payout
        ),
        "DRIP token transfer failed"
      );
      total_txs++;

  }

  //@dev Claim current payouts
  function _claim(address _addr, bool isClaimedOut) internal returns (uint256) {
      (uint256 _gross_payout, uint256 _max_payout, uint256 _to_payout, uint256 _sustainability_fee) = payoutOf(_addr);
      require(users[_addr].payouts < _max_payout, "Full payouts");

      // Deposit payout
      if(_to_payout > 0) {

          // payout remaining allowable divs if exceeds
          if(users[_addr].payouts + _to_payout > _max_payout) {
              _to_payout = _max_payout.safeSub(users[_addr].payouts);
          }

          users[_addr].payouts += _gross_payout;

      }

      require(_to_payout > 0, "Zero payout");

      //Update the payouts
      total_withdraw += _to_payout;

      //Update time!
      users[_addr].deposit_time = block.timestamp;
      users[_addr].accumulatedDiv = 0;

      emit Withdraw(_addr, _to_payout);

      if(users[_addr].payouts >= _max_payout) {
          emit LimitReached(_addr, users[_addr].payouts);
      }

      return _to_payout;
  }

  /********* Views ***************************************/

  //@dev Returns true if the address is net positive
  function isNetPositive(address _addr) public view returns (bool) {

      (uint256 _credits, uint256 _debits) = creditsAndDebits(_addr);

      return _credits > _debits;

  }

  //@dev Returns the total credits and debits for a given address
  function creditsAndDebits(address _addr) public view returns (uint256 _credits, uint256 _debits) {
      User memory _user = users[_addr];
      Airdrop memory _airdrop = airdrops[_addr];

      _credits = _airdrop.airdrops + _user.rolls + _user.deposits;
      _debits = _user.payouts;

  }

  
  //@dev Returns custody info of _addr
  function getCustody(address _addr) public view returns (address _beneficiary, uint256 _heartbeat_interval, address _manager) {
      return (custody[_addr].beneficiary, custody[_addr].heartbeat_interval, custody[_addr].manager);
  }

  //@dev Returns account activity timestamps
  function lastActivity(address _addr) public view returns (uint256 _heartbeat, uint256 _lapsed_heartbeat, uint256 _checkin, uint256 _lapsed_checkin) {
      _heartbeat = custody[_addr].last_heartbeat;
      _lapsed_heartbeat = block.timestamp.safeSub(_heartbeat);
      _checkin = custody[_addr].last_checkin;
      _lapsed_checkin = block.timestamp.safeSub(_checkin);
  }

  //@dev Returns amount of claims available for sender
  function claimsAvailable(address _addr) public view returns (uint256) {
      (uint256 _gross_payout, uint256 _max_payout, uint256 _to_payout, uint256 _sustainability_fee) = payoutOf(_addr);
      return _to_payout;
  }

  //@dev Maxpayout of 3.65 of deposit
  function maxPayoutOf(uint256 _amount) public pure returns(uint256) {
      return _amount * 365 / 100;
  }

  function sustainabilityFeeV2(address _addr, uint256 _pendingDiv) public view returns (uint256) {
      uint256 _bracket = users[_addr].payouts.add(_pendingDiv).div(deposit_bracket_size);
      _bracket = SafeMath.min(_bracket, deposit_bracket_max);
      return _bracket * 5;
  }

  //@dev Calculate the current payout and maxpayout of a given address
  function payoutOf(address _addr) public view returns(uint256 payout, uint256 max_payout, uint256 net_payout, uint256 sustainability_fee) {
      //The max_payout is capped so that we can also cap available rewards daily
      max_payout = maxPayoutOf(users[_addr].deposits).min(max_payout_cap);

      uint256 share;

      if(users[_addr].payouts < max_payout) {

          //Using 1e18 we capture all significant digits when calculating available divs
          share = users[_addr].deposits.mul(payoutRate * 1e18).div(100e18).div(24 hours); //divide the profit by payout rate and seconds in the day

          payout = share * block.timestamp.safeSub(users[_addr].deposit_time);

          payout += users[_addr].accumulatedDiv;

          // payout remaining allowable divs if exceeds
          if(users[_addr].payouts + payout > max_payout) {
              payout = max_payout.safeSub(users[_addr].payouts);
          }

          uint256 _fee = sustainabilityFeeV2(_addr, payout);

          sustainability_fee = payout * _fee / 100;

          net_payout = payout.safeSub(sustainability_fee);

      }
  }

  //@dev Get current user snapshot
  function userInfo(address _addr) external view returns(address upline, uint256 deposit_time, uint256 deposits, uint256 payouts, uint256 direct_bonus, uint256 match_bonus, uint256 last_airdrop) {
      return (users[_addr].upline, users[_addr].deposit_time, users[_addr].deposits, users[_addr].payouts, users[_addr].direct_bonus, users[_addr].match_bonus, airdrops[_addr].last_airdrop);
  }

  //@dev Get user totals
  function userInfoTotals(address _addr) external view returns(uint256 referrals, uint256 total_deposits, uint256 total_payouts, uint256 total_structure, uint256 airdrops_total, uint256 airdrops_received) {
      return (users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure, airdrops[_addr].airdrops, airdrops[_addr].airdrops_received);
  }

  //@dev Get contract snapshot
  function contractInfo() external view returns(uint256 _total_users, uint256 _total_deposited, uint256 _total_withdraw, uint256 _total_bnb, uint256 _total_txs, uint256 _total_airdrops) {
      return (total_users, total_deposited, total_withdraw, total_bnb, total_txs, total_airdrops);
  }

  /////// Airdrops ///////

  //@dev Send specified DRIP amount supplying an upline referral
  function airdrop(address _to, uint256 _amount) external {

      address _addr = msg.sender;

      (uint256 _realizedAmount, uint256 taxAmount) = dripToken.calculateTransferTaxes(_addr, _amount);
      //This can only fail if the balance is insufficient
      require(
          dripToken.transferFrom(
              _addr,
              address(dripVaultAddress),
              _amount
          ),
          "DRIP to contract transfer failed; check balance and allowance, airdrop"
      );

      //Make sure _to exists in the system; we increase
      require(users[_to].upline != address(0), "_to not found");

      (uint256 gross_payout,,,) = payoutOf(_to);

      users[_to].accumulatedDiv = gross_payout;

      //Fund to deposits (not a transfer)
      users[_to].deposits += _realizedAmount;
      users[_to].deposit_time = block.timestamp;

      //User stats
      airdrops[_addr].airdrops += _realizedAmount;
      airdrops[_addr].last_airdrop = block.timestamp;
      airdrops[_to].airdrops_received += _realizedAmount;

      //Keep track of overall stats
      total_airdrops += _realizedAmount;
      total_txs += 1;


      //Let em know!
      emit NewAirdrop(_addr, _to, _realizedAmount, block.timestamp);
      emit NewDeposit(_to, _realizedAmount);
  }
}