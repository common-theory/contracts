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

  /**
   * Always settle payments forward in time, keep track of the last settled to
   * reduce gas (loop iterations) as more payments are receieved.
   **/
  uint256 public lastSettledPayment = 0;

  struct Payment {
    address sender;
    address receiver;
    uint256 timestamp;
    uint256 timeLength;
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
    payments.push(Payment({
      sender: msg.sender,
      receiver: address(this),
      timestamp: block.timestamp,
      timeLength: 0,
      weiValue: msg.value,
      weiPaid: 0
    }));
    paymentSettle(paymentCount() - 1);
  }

  /**
   * Pay from sender to receiver a certain amount over a certain amount of time.
   **/
  function pay(address _receiver, uint256 _weiValue, uint256 _timeLength, address _sender) public {
    uint256 balance = balances[_sender];
    // Verify that the balance is there
    require(_weiValue <= balance);
    payments.push(Payment({
      sender: address(this),
      receiver: _receiver,
      timestamp: block.timestamp,
      timeLength: _timeLength,
      weiValue: _weiValue,
      weiPaid: 0
    }));
    // Update the balance value of the sender to effectively lock the funds in place
    balances[_sender] -= _weiValue;
    // Attempt instant payment settlement
    paymentSettle(paymentCount() - 1);
  }

  /**
   * Overloaded pay function with current contract as default sender.
   **/
  function pay(address _receiver, uint256 _weiValue, uint256 _timeLength) public {
    pay(_receiver, _weiValue, _timeLength, address(this));
  }

  /**
   * Settle an individual payment at the current point in time.
   *
   * Can be called multiple times for payments
   * over time.
   **/
  function paymentSettle(uint256 index) public {
    if (paymentWeiOwed(index) <= 0) return;
    uint256 owedWei = paymentWeiOwed(index);
    balances[payments[index].receiver] += owedWei;
  }

  /**
   * Return the wei owed on a payment at the current block timestamp.
   **/
  function paymentWeiOwed(uint256 index) public view returns (uint256) {
    // Ensure index is in range
    require(index >= 0);
    require(index < paymentCount());
    Payment memory payment = payments[index];

    // If the payment timeLength is 0 just return the amount owed
    if (payment.timeLength == 0) return payment.weiValue - payment.weiPaid;

    // Calculate owed wei based on current time and total wei owed/paid
    uint256 weiPerSecond = payment.weiValue / payment.timeLength;
    uint256 owedSeconds = min(block.timestamp - payment.timestamp, payment.timeLength);
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
   * Withdraw balance from address to address.
   **/
  function withdraw(address payable from, address payable to) public {
    // Only allow sender to do custom withdrawals for self
    require(msg.sender == from);
    if (balances[from] == 0) return;
    to.transfer(balances[from]);
    balances[from] = 0;
  }

  /**
   * Single argument, withdraws to address from sender
   **/
  function withdraw(address payable to) public {
    withdraw(msg.sender, to);
  }

  /**
   * No arguments, withdraws to sender from sender
   **/
  function withdraw() public {
    withdraw(msg.sender, msg.sender);
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
