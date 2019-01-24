const Syndicate = artifacts.require('Syndicate');
const assert = require('assert');
const BN = require('bn.js');

/**
 * Syndicate contract tests
 **/
contract('Syndicate', accounts => {

  /**
   * Tests pay(address payable _receiver, uint256 _time) with a zero _time
   * argument.
   **/
  it('should fail to pay instantly', async () => {
    const _contract = await Syndicate.deployed();
    // Get a reference to a normal web3.eth.Contract, not a TruffleContract
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 100;
    const time = 0;
    await assert.rejects(contract.methods.pay(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    }));
  });

  /**
   * Tests pay(address payable _receiver, uint256 _time) with non-zero _time
   * argument.
   *
   * - Send Ether to Syndicate via pay()
   * - Verify payment settlement every network block rate (or 1 second) until
   *   30 seconds after payment settlement.
   **/
  it('should pay over time', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 2491;
    const time = process.env.CI ? 150 : 30;
    // Time past the payment completion time to test
    const overrunTime = 30;
    const gasPrice = new BN(await web3.eth.getGasPrice());
    // Deposit from owner address
    await contract.methods.pay(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    const payment = await contract.methods.payments(paymentIndex).call();

    const ownerWei = new BN(await web3.eth.getBalance(owner));

    // Check payment values over time
    while (true) {
      // Wait 1 second between loop iterations
      await new Promise(r => setTimeout(r, 1000));
      // Settle the Payment at the current point in time
      const receipt = await contract.methods.paymentSettle(paymentIndex).send({
        from: owner,
        gas: 300000,
        gasPrice
      });
      const weiCost = new BN(receipt.cumulativeGasUsed).mul(gasPrice);
      ownerWei.isub(weiCost);

      const _payment = await contract.methods.payments(paymentIndex).call();
      const now = Math.floor(new Date() / 1000);
      const totalWeiOwed = +payment.weiValue * Math.min(now - +payment.timestamp, +payment.time) / +payment.time;
      // Ensure that weiPaid is less than the logically calculated owed wei at
      // the loop timestamp (which should always be >= block.timestamp)
      assert.ok(+_payment.weiPaid <= totalWeiOwed);

      if (now > +payment.timestamp + +payment.time + overrunTime) break;
    }

    const newOwnerWei = new BN(await web3.eth.getBalance(owner));

    // Ensure the address balance is properly updated
    assert.equal(newOwnerWei.sub(ownerWei).toString(), weiValue.toString());
    // Verify that isPaymentSettled() is operating sanely
    assert.ok(await contract.methods.isPaymentSettled(paymentIndex));
  });

  /**
   * Tests pay via fallback function, should fail.
   **/
  it('fallback should fail', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[1];
    const weiValue = 100;
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
    await assert.rejects(contract.methods.pay(owner, time).send({
      from: owner,
      gas: 300000
    }));
  });

  /**
   * Tests requirePaymentIndexInRange(uint256 paymentIndex) function.
   **/
  it('requirePaymentIndexInRange should fail for out of range index', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    await assert.rejects(
      contract.methods.requirePaymentIndexInRange(-1).call(),
      'Method should throw for negative value'
    );
    const paymentCount = await contract.methods.paymentCount().call();
    await assert.rejects(
      contract.methods.requirePaymentIndexInRange(+paymentCount).call(),
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
    const time = 60;
    await contract.methods.pay(owner, time).send({
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

  it('should fail to fork if not receiver', async () => {
    const _contract = await Syndicate.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const owner = accounts[0];
    const weiValue = 5000;
    const targetAddress = web3.eth.accounts.create().address;
    const time = 100;
    await contract.methods.pay(targetAddress, time).send({
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
    await contract.methods.pay(owner, time).send({
      from: owner,
      value: weiValue,
      gas: 300000
    });
    const paymentIndex = await contract.methods.paymentCount().call() - 1;
    await new Promise(r => setTimeout(r, 1000 * time / 10));
    await contract.methods.paymentSettle(paymentIndex).send({
      from: owner
    });
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
    await contract.methods.pay(owner, time).send({
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
    await contract.methods.pay(owner, time).send({
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
    const updatedParent = await contract.methods.payments(paymentIndex).call();
    assert.equal(true, updatedParent.isForked);
    assert.equal(false, updatedParent.isFork);
    assert.equal(paymentIndex + 1, updatedParent.fork1Index);
    assert.equal(paymentIndex + 2, updatedParent.fork2Index);
  });

});
