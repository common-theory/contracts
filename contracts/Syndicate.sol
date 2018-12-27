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

  bool public contractUpdated = false;

  struct Payment {
    address sender;
    address receiver;
    uint256 timestamp;
    uint256 seconds;
    uint256 weiValue;
    uint256 weiPaid;
  }

  Payment[] public payments;

  /**
   * Default payment function. Adds an unsettled payment entry, or forwards the
   * payment to the updated contract (if an update proposal has passed).
   **/
  function() external payable {
    // revert the transaction, don't let ether be sent here if we've updated
    if (contractUpdated) require(false);
    balances[msg.sender] += msg.value;
  }

  /**
   * Pay from sender to receiver a certain amount over a certain amount of time.
   **/
  function pay(address _receiver, uint256 _weiValue, uint256 _seconds, address _sender) public {
    uint256 balance = balances[_sender];
    // Verify that the balance is there
    require(_weiValue <= balance);
    payments.push(Payment({
      sender: address(this),
      receiver: _receiver,
      timestamp: block.timestamp,
      seconds: _seconds,
      weiValue: _weiValue,
      weiPaid: 0
    }));
    // Update the balance value of the sender to effectively lock the funds in place
    balances[_sender] -= _weiValue;
    // Attempt instant payment settlement
    paymentSettle(paymentCount() - 1);
  }

  /**
   * Overloaded pay function with msg.sender as default sender.
   **/
  function pay(address _receiver, uint256 _weiValue, uint256 _seconds) public {
    pay(_receiver, _weiValue, _seconds, msg.sender);
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
  }

  /**
   * Return the wei owed on a payment at the current block timestamp.
   **/
  function paymentWeiOwed(uint256 index) public view returns (uint256) {
    // Return 0 if the payment is fully paid out
    if (isPaymentSettled(index)) return 0;
    Payment memory payment = payments[index];

    // If the payment seconds is 0 just return the amount owed
    if (payment.seconds == 0) return payment.weiValue - payment.weiPaid;

    // Calculate owed wei based on current time and total wei owed/paid
    uint256 weiPerSecond = payment.weiValue / payment.seconds;
    uint256 owedSeconds = min(block.timestamp - payment.timestamp, payment.seconds);
    return min(owedSeconds * weiPerSecond, payment.weiValue - payment.weiPaid);
  }

  /**
   * Accessor for determining if a given payment is fully settled.
   **/
  function isPaymentSettled(uint256 index) public view returns (bool) {
    // Ensure index is in range
    require(index >= 0);
    require(index < paymentCount());
    Payment memory payment = payments[index];
    return payment.weiValue == payment.weiPaid;
  }

  /**
   * Withdraw balance from msg.sender to address.
   **/
  function withdraw(uint256 weiValue, address payable to, uint256[] indexesToSettle) public {
    // Settle any supplied payment indexes
    // This allows for lazy balance updates at withdrawal time
    for (uint256 i = 0; i < indexesToSettle.length; i++) paymentSettle(i);

    address from = msg.sender;
    require(balances[from] >= weiValue);
    to.transfer(weiValue);
    balances[from] -= weiValue;
  }

  /**
   * No arguments, withdraws to sender from sender
   **/
  function withdraw() public {
    withdraw(msg.sender);
  }

  /**
   * Accessor for array length
   **/
  function paymentCount() public view returns (uint) {
    return payments.length;
  }

  /**
   * Return the larger of two values.
   **/
  function max(uint a, uint b) private pure returns (uint) {
    return a > b ? a : b;
  }

  /**
   * Return the smaller of two values.
   **/
  function min(uint a, uint b) private pure returns (uint) {
    return a < b ? a : b;
  }
}
