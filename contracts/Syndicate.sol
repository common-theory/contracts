pragma solidity ^0.5.0;

/**
 * Syndicate
 *
 * A way to distribute ownership of ether in time
 **/

contract Syndicate {

  struct Payment {
    address sender;
    address payable receiver;
    uint256 timestamp;
    uint256 time;
    uint256 weiValue;
    uint256 weiPaid;
    bool isFork;
    uint256 parentIndex;
    bool isForked;
    uint256 fork1Index;
    uint256 fork2Index;
  }

  Payment[] public payments;

  event PaymentUpdated(uint256 index);
  event PaymentCreated(uint256 index);

  /**
   * Pay from sender to receiver a certain amount over a certain amount of time.
   **/
  function pay(address payable _receiver, uint256 _time) public payable {
    // Verify that value has been sent
    require(msg.value > 0);
    // Verify the time is non-zero
    require(_time > 0);
    payments.push(Payment({
      sender: msg.sender,
      receiver: _receiver,
      timestamp: block.timestamp,
      time: _time,
      weiValue: msg.value,
      weiPaid: 0,
      isFork: false,
      parentIndex: 0,
      isForked: false,
      fork1Index: 0,
      fork2Index: 0
    }));
    emit PaymentCreated(payments.length - 1);
  }

  /**
   * Settle an individual payment at the current point in time.
   *
   * Transfers the owedWei at the current point in time to the receiving
   * address.
   **/
  function paymentSettle(uint256 index) public {
    requirePaymentIndexInRange(index);
    require(msg.sender == payments[index].receiver);
    uint256 owedWei = paymentWeiOwed(index);
    payments[index].weiPaid += owedWei;
    msg.sender.transfer(owedWei);
    emit PaymentUpdated(index);
  }

  /**
   * Return the wei owed on a payment at the current block timestamp.
   **/
  function paymentWeiOwed(uint256 index) public view returns (uint256) {
    requirePaymentIndexInRange(index);
    Payment memory payment = payments[index];
    // Calculate owed wei based on current time and total wei owed/paid
    return max(payment.weiPaid, payment.weiValue * min(block.timestamp - payment.timestamp, payment.time) / payment.time) - payment.weiPaid;
  }

  /**
   * Forks a payment to another address for the duration of a payment. Allows
   * responsibility of funds to be delegated to other addresses by payment
   * recipient.
   *
   * Payment completion time is unaffected by forking, the only thing that
   * changes is recipient(s).
   *
   * Payments can be forked until weiValue is 0, at which point the Payment is
   * settled. Child payments can also be forked.
   *
   * The genealogy of a payment can be represented as a binary tree.
   **/
  function paymentFork(uint256 index, address payable _receiver, uint256 _weiValue) public {
    requirePaymentIndexInRange(index);
    Payment memory payment = payments[index];
    // Make sure the payment owner is operating
    require(msg.sender == payment.receiver);

    uint256 remainingWei = payment.weiValue - payment.weiPaid;
    uint256 remainingTime = max(0, payment.time - (block.timestamp - payment.timestamp));

    // Ensure there is more remainingWei than requested fork wei
    require(remainingWei > _weiValue);
    require(_weiValue > 0);

    // Create a new Payment of _weiValue to _receiver over the remaining time of
    // Payment at index
    payments[index].weiValue = payments[index].weiPaid;
    emit PaymentUpdated(index);

    payments.push(Payment({
      sender: msg.sender,
      receiver: _receiver,
      timestamp: block.timestamp,
      time: remainingTime,
      weiValue: _weiValue,
      weiPaid: 0,
      isFork: true,
      parentIndex: index,
      isForked: false,
      fork1Index: 0,
      fork2Index: 0
    }));
    payments[index].fork1Index = payments.length - 1;
    emit PaymentCreated(payments.length - 1);

    payments.push(Payment({
      sender: payment.receiver,
      receiver: payment.receiver,
      timestamp: block.timestamp,
      time: remainingTime,
      weiValue: remainingWei - _weiValue,
      weiPaid: 0,
      isFork: true,
      parentIndex: index,
      isForked: false,
      fork1Index: 0,
      fork2Index: 0
    }));
    payments[index].fork2Index = payments.length - 1;
    emit PaymentCreated(payments.length - 1);

    payments[index].isForked = true;
  }

  /**
   * Accessor for determining if a given payment is fully settled.
   **/
  function isPaymentSettled(uint256 index) public view returns (bool) {
    requirePaymentIndexInRange(index);
    return payments[index].weiValue == payments[index].weiPaid;
  }

  /**
   * Reverts if the supplied payment index is out of range.
   **/
  function requirePaymentIndexInRange(uint256 index) public view {
    require(index < payments.length);
  }

  /**
   * Accessor for array length.
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

  /**
   * Return the larger of two values.
   **/
  function max(uint a, uint b) private pure returns (uint) {
    return a > b ? a : b;
  }
}
