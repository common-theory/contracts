pragma solidity ^0.5.0;

/**
 * The Syndicate contract
 *
 * A way for distributed groups of people to work together and come to consensus
 * on use of funds.
 *
 * syndicate - noun
 * a group of individuals or syndicates combined to promote some common interest
 **/

contract Syndicate {

  mapping (address => uint256) public balances;

  struct Payment {
    address sender;
    address receiver;
    uint256 timestamp;
    uint256 time;
    uint256 weiValue;
    uint256 weiPaid;
  }

  Payment[] public payments;

  event PaymentUpdated(uint256 index);

  /**
   * Deposit to a given address over a certain amount of time.
   *
   * If the _time is 0 the value is deposited immediately.
   *
   * Otherwise a payment is created from msg.sender to _receiver.
   **/
  function deposit(address payable _receiver, uint256 _time) external payable {
    balances[msg.sender] += msg.value;
    pay(_receiver, msg.value, _time);
  }

  /**
   * Deposits money into address balance.
   **/
  function() external payable {
    balances[msg.sender] += msg.value;
  }

  /**
   * Pay from sender to receiver a certain amount over a certain amount of time.
   **/
  function pay(address _receiver, uint256 _weiValue, uint256 _time) public {
    // Verify that the balance is there and value is non-zero
    require(_weiValue <= balances[msg.sender] && _weiValue > 0);
    payments.push(Payment({
      sender: msg.sender,
      receiver: _receiver,
      timestamp: block.timestamp,
      time: _time,
      weiValue: _weiValue,
      weiPaid: 0
    }));
    // Update the balance value of the sender to effectively lock the funds in place
    balances[msg.sender] -= _weiValue;
    // Attempt instant payment settlement
    paymentSettle(payments.length - 1);
  }

  /**
   * Settle an individual payment at the current point in time.
   *
   * Can be called idempotently.
   **/
  function paymentSettle(uint256 index) public {
    uint256 owedWei = paymentWeiOwed(index);
    balances[payments[index].receiver] += owedWei;
    payments[index].weiPaid += owedWei;
    emit PaymentUpdated(index);
  }

  /**
   * Return the wei owed on a payment at the current block timestamp.
   **/
  function paymentWeiOwed(uint256 index) public view returns (uint256) {
    assertPaymentIndexInRange(index);
    Payment memory payment = payments[index];
    // If the payment time is 0 just return the amount owed
    if (payment.time == 0) return payment.weiValue - payment.weiPaid;
    // Calculate owed wei based on current time and total wei owed/paid
    return payment.weiValue * min(block.timestamp - payment.timestamp, payment.time) / payment.time - payment.weiPaid;
  }

  /**
   * Accessor for determining if a given payment is fully settled.
   **/
  function isPaymentSettled(uint256 index) public view returns (bool) {
    assertPaymentIndexInRange(index);
    Payment memory payment = payments[index];
    return payment.weiValue == payment.weiPaid;
  }

  /**
   * Reverts if the supplied payment index is out of range
   **/
  function assertPaymentIndexInRange(uint256 index) public view {
    require(index >= 0);
    require(index < payments.length);
  }

  /**
   * Withdraw target address balance from Syndicate to ether.
   **/
  function withdraw(address payable target, uint256 weiValue, uint256[] memory indexesToSettle) public {
    // Settle any supplied payment indexes
    // This allows for lazy balance updates at withdrawal time
    for (uint256 i = 0; i < indexesToSettle.length; i++) paymentSettle(indexesToSettle[i]);

    require(balances[target] >= weiValue);
    balances[target] -= weiValue;
    target.transfer(weiValue);
  }

  /**
   * Two arguments, target address and weiValue.
   **/
  function withdraw(address payable target, uint256 weiValue) public {
    uint256[] memory indexesToSettle;
    withdraw(target, weiValue, indexesToSettle);
  }

  /**
   * One argument, target address.
   **/
  function withdraw(address payable target) public {
    uint256[] memory indexesToSettle;
    withdraw(target, balances[target], indexesToSettle);
  }

  /**
   * No arguments, withdraws full balance to sender from sender balance.
   **/
  function withdraw() public {
    uint256[] memory indexesToSettle;
    withdraw(msg.sender, balances[msg.sender], indexesToSettle);
  }

  /**
   * Accessor for array length
   **/
  function paymentCount() public view returns (uint) {
    return payments.length;
  }

  /**
   * Return the smaller of two values.
   **/
  function min(uint a, uint b) private pure returns (uint) {
    return a < b ? a : b;
  }
}
