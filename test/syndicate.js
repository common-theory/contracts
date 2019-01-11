const Syndicate = artifacts.require('Syndicate');
const assert = require('assert');
const BN = require('bn.js');

/**
 * Syndicate contract tests
 **/
contract('Syndicate', accounts => {

  /**
   * Tests deposit(address payable _receiver, uint256 _time) with a zero _time
   * argument.
   *
   * - Send Ether to Syndicate via deposit()
   * - Verify same transaction payment settlement
   **/
  it('should fail to deposit instantly', async () => {
    const _contract = await Syndicate.deployed();
    // Get a reference to a normal web3.eth.Contract, not a TruffleContract
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 100;
    const time = 0;
    await assert.rejects(contract.methods.deposit(owner, 0).send({
      from: owner,
      value: weiValue,
      gas: 300000
    }));
  });

  /**
   * Tests deposit(address payable _receiver, uint256 _time) with non-zero _time
   * argument.
   *
   * - Send Ether to Syndicate via deposit()
   * - Verify payment settlement every network block rate (or 1 second) until
   *   30 seconds after payment settlement.
   **/
  it('should deposit over time', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 2491;
    const time = process.env.CI ? 150 : 30;
    // Time past the payment completion time to test
    const overrunTime = 30;
    // Flush the Syndicate balance from the owner address
    await contract.methods.withdraw().send({
      from: owner,
      gas: 300000
    });
    // Deposit from owner address
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    const payment = await contract.methods.payments(paymentIndex).call();

    // Check payment values over time
    while (true) {
      // Wait 1 second between loop iterations
      await new Promise(r => setTimeout(r, 1000));
      // Settle the Payment at the current point in time
      await contract.methods.paymentSettle(paymentIndex).send({
        from: owner,
        gas: 300000
      });
      const _payment = await contract.methods.payments(paymentIndex).call();
      const now = Math.floor(new Date() / 1000);
      const totalWeiOwed = +payment.weiValue * Math.min(now - +payment.timestamp, +payment.time) / +payment.time;
      // Ensure that weiPaid is less than the logically calculated owed wei at
      // the loop timestamp (which should always be >= block.timestamp)
      assert.ok(+_payment.weiPaid <= totalWeiOwed);

      if (now > +payment.timestamp + +payment.time + overrunTime) break;
    }

    const balance = await contract.methods.balances(owner).call();
    // Ensure balance is equal to payment.weiValue
    assert.equal(balance, weiValue);
    // Verify that isPaymentSettled() is operating sanely
    assert.ok(await contract.methods.isPaymentSettled(paymentIndex));
  });

  /**
   * Tests deposit via fallback function, should function same as deposit() with
   * a zero _time value.
   *
   * - Send Ether to Syndicate contract
   * - Verify same transaction payment settlement
   **/
  it('fallback should fail', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[1];
    const weiValue = 100;
    // Flush the Syndicate balance from the owner address
    await contract.methods.withdraw().send({
      from: owner,
      gas: 300000
    });
    await assert.rejects(web3.eth.sendTransaction({
      from: owner,
      to: _contract.address,
      value: weiValue
    }));
  });

  /**
   * Ensures that 0 value payments fail.
   **/
  it('should fail to pay with no value', async () => {
    const _contract = await Syndicate.deployed();
    // Get a reference to a normal web3.eth.Contract, not a TruffleContract
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 100;
    const time = 1;
    // Flush the Syndicate balance from the owner address
    await contract.methods.withdraw().send({
      from: owner,
      gas: 300000
    });
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    await new Promise(r => setTimeout(r, 2000))
    await assert.rejects(contract.methods.pay(accounts[1], 0, 0).send({
      from: owner,
      gas: 300000
    }), '0 value payment should fail');
  });

  /**
   * Tests withdraw() function with no arguments.
   *
   * - Deposit using Syndicate.deposit()
   * - Withdraw balance
   * - Verify network Ether balance
   **/
  it('should withdraw balance with no args', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = new BN('500');
    const time = 1;
    const gasPrice = new BN(web3.eth.gasPrice);
    await contract.methods.withdraw().send({
      from: owner
    });
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000,
      gasPrice
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    await new Promise(r => setTimeout(r, 2000));
    await contract.methods.paymentSettle(paymentIndex).send({
      from: owner
    });
    const ownerWei = new BN(await web3.eth.getBalance(owner));
    const receipt = await contract.methods.withdraw().send({
      from: owner,
      gas: 300000,
      gasPrice
    });
    const balance = await contract.methods.balances(owner).call();
    assert.equal(0, +balance);

    const withdrawalGasUsed = new BN(receipt.cumulativeGasUsed);
    const withdrawalWeiCost = withdrawalGasUsed.mul(gasPrice);

    const expectedWei = ownerWei.add(weiValue).sub(withdrawalWeiCost);

    const newOwnerWei = new BN(await web3.eth.getBalance(owner));

    // Verify the current owner address value against the value before the
    // withdrawal - withdrawal cost + payment.weiValue
    assert.ok(expectedWei.eq(newOwnerWei));
  });

  /**
   * Tests withdraw(address target) function.
   **/
  it('should withdraw balance with target address arg', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = new BN('5000');
    const time = 1;
    await contract.methods.withdraw().send({
      from: owner
    });
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    await new Promise(r => setTimeout(r, 2000));
    await contract.methods.paymentSettle(paymentIndex).send({
      from: owner
    });
    const ownerWei = new BN(await web3.eth.getBalance(owner));
    const receipt = await contract.methods.withdraw(owner).send({
      from: accounts[4],
      gas: 300000
    });

    const expectedWei = ownerWei.add(weiValue);
    const newOwnerWei = new BN(await web3.eth.getBalance(owner));
    // Verify the current owner address value against the value before the
    // withdrawal - withdrawal cost + payment.weiValue
    assert.ok(expectedWei.eq(newOwnerWei));
  });

  /**
   * Tests withdraw(address target, uint256 weiValue) function.
   **/
  it('should withdraw balance with target address and weiValue args', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = new BN('5000');
    const withdrawalWeiValue = new BN('500');
    const targetAddress = web3.eth.accounts.create().address;
    const time = 1;
    await contract.methods.deposit(targetAddress, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    await new Promise(r => setTimeout(r, 2000));
    await contract.methods.paymentSettle(paymentIndex).send({
      from: owner
    });
    await contract.methods.withdraw(targetAddress, withdrawalWeiValue.toString()).send({
      from: owner,
      gas: 300000,
    });
    const targetAddressWei = new BN(await web3.eth.getBalance(targetAddress));
    assert.ok(withdrawalWeiValue.eq(targetAddressWei));
  });

  /**
   * Tests assertPaymentIndexInRange(uint256 paymentIndex) function.
   **/
  it('assertPaymentIndexInRange should fail for out of range index', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    await assert.rejects(
      contract.methods.assertPaymentIndexInRange(-1).call(),
      'Method should throw for negative value'
    );
    const paymentCount = await contract.methods.paymentCount().call();
    await assert.rejects(
      contract.methods.assertPaymentIndexInRange(+paymentCount).call(),
      'Method should throw for value longer than paymentCount'
    );
  });

  /**
   * Run a payment over time and test isPaymentSettled over time.
   **/
  it('isPaymentSettled should evaluate correctly', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    await contract.methods.withdraw().send({
      from: owner
    });
    const time = 60;
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: 100,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    assert.equal(false, await contract.methods.isPaymentSettled(paymentIndex).call());
    await new Promise(r => setTimeout(r, time * 1000 / 4));
    await contract.methods.paymentSettle(paymentIndex).send({
      from: owner,
      gas: 300000
    });
    assert.equal(false, await contract.methods.isPaymentSettled(paymentIndex).call());
    await new Promise(r => setTimeout(r, time * 1000));
    await contract.methods.paymentSettle(paymentIndex).send({
      from: owner,
      gas: 300000
    });
    assert.equal(true, await contract.methods.isPaymentSettled(paymentIndex).call());
  });

  /**
   * Payment should fail for value larger than balance
   **/
  it('should fail to make payment larger than balance', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const balance = await contract.methods.balances(owner).call();
    await assert.rejects(
      contract.methods.pay(accounts[3], +balance + 1, 0).send({
        from: owner,
        gas: 300000
      }),
      'Pay function should fail for weiValue > balance'
    );
  });

  it('should fail to withdraw more than available', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = new BN('5000');
    const withdrawalWeiValue = new BN('50000');
    const targetAddress = web3.eth.accounts.create().address;
    const time = 1;
    await contract.methods.deposit(targetAddress, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    await new Promise(r => setTimeout(r, 2000));
    await contract.methods.paymentSettle(paymentIndex).send({
      from: owner
    });
    await assert.rejects(contract.methods.withdraw(targetAddress, withdrawalWeiValue.toString()).send({
      from: owner,
      gas: 300000,
    }));
  });

  it('should fail to fork if not receiver', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 5000;
    const targetAddress = web3.eth.accounts.create().address;
    const time = 100;
    await contract.methods.deposit(targetAddress, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    await assert.rejects(contract.methods.paymentFork(paymentIndex, owner, 10).send({
      from: owner
    }), 'Non-receiver should not be able to fork payment');
  });

  it('should fail to fork if not enough weiValue remaining', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 5000;
    const time = 100;
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    await new Promise(r => setTimeout(r, 1000 * time / 10));
    await assert.rejects(contract.methods.paymentFork(paymentIndex, owner, weiValue).send({
      from: owner
    }), 'Should not be able to fork full balance partway into payment');
  });

  it('should fail to fork if zero weiValue', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 5000;
    const time = 100;
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    await assert.rejects(contract.methods.paymentFork(paymentIndex, owner, 0).send({
      from: owner
    }), 'Should not be able to fork 0 weiValue');
  });

  it('should fork payment', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 5000;
    const time = 100;
    await contract.methods.deposit(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    await new Promise(r => setTimeout(r, 5000))
    await contract.methods.paymentFork(paymentIndex, owner, weiValue/1000).send({
      from: owner,
      gas: 500000
    });
    const parent = await contract.methods.payments(paymentIndex).call();
    const fork1 = await contract.methods.payments(paymentIndex + 1).call();
    const fork2 = await contract.methods.payments(paymentIndex + 2).call();
    assert.ok(weiValue === +parent.weiValue + +fork1.weiValue + +fork2.weiValue);
    assert.ok(+parent.timestamp + +parent.time === +fork1.timestamp + +fork1.time);
    assert.ok(+parent.timestamp + +parent.time === +fork2.timestamp + +fork2.time);
    assert.ok(fork1.isFork);
    assert.ok(fork2.isFork);
    assert.equal(fork1.parentIndex, paymentIndex);
    assert.equal(fork2.parentIndex, paymentIndex);
    assert.ok(!parent.isFork);
    assert.ok(await contract.methods.isPaymentSettled(paymentIndex).call());
    const forkIndexes = await contract.methods.paymentForkIndexes(paymentIndex).call();
    assert.equal(paymentIndex + 1, forkIndexes[0]);
    assert.equal(paymentIndex + 2, forkIndexes[1]);
  });
});
