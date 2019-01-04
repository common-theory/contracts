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
    pay(_receiver, msg.value, _time, msg.sender);
  }

  /**
   * Default payment function. Adds an unsettled payment entry, or forwards the
   * payment to the updated contract (if an update proposal has passed).
   **/
  function() external payable {
    balances[msg.sender] += msg.value;
    this.deposit(msg.sender, uint256(0));
  }

  /**
   * Pay from sender to receiver a certain amount over a certain amount of time.
   **/
  function pay(address _receiver, uint256 _weiValue, uint256 _time, address _sender) public {
    // Verify that the balance is there
    require(_weiValue <= balances[_sender]);
    payments.push(Payment({
      sender: _sender,
      receiver: _receiver,
      timestamp: block.timestamp,
      time: _time,
      weiValue: _weiValue,
      weiPaid: 0
    }));
    // Update the balance value of the sender to effectively lock the funds in place
    balances[_sender] -= _weiValue;
    // Attempt instant payment settlement
    uint256 paymentIndex = payments.length - 1;
    paymentSettle(paymentIndex);
    emit PaymentUpdated(paymentIndex);
  }

  /**
   * Settle an individual payment at the current point in time.
   *
   * Can be called multiple times for payments over time.
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
   * Withdraw to address balance from Syndicate to ether.
   **/
  function withdraw(uint256 weiValue, address payable to, uint256[] memory indexesToSettle) public {
    // Settle any supplied payment indexes
    // This allows for lazy balance updates at withdrawal time
    for (uint256 i = 0; i < indexesToSettle.length; i++) paymentSettle(indexesToSettle[i]);

    require(balances[to] >= weiValue);
    to.transfer(weiValue);
    balances[to] -= weiValue;
  }

  /**
   * Two arguments, weiValue and to address.
   **/
  function withdraw(uint256 weiValue, address payable to) public {
    uint256[] memory indexesToSettle;
    withdraw(weiValue, to, indexesToSettle);
  }

  /**
   * One argument, weiValue.
   **/
  function withdraw(uint256 weiValue) public {
    uint256[] memory indexesToSettle;
    withdraw(weiValue, msg.sender, indexesToSettle);
  }

  /**
   * No arguments, withdraws full balance to sender from sender balance.
   **/
  function withdraw() public {
    uint256[] memory indexesToSettle;
    withdraw(balances[msg.sender], msg.sender, indexesToSettle);
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
