const CommonDAC = artifacts.require('CommonDAC');
const assert = require('assert');

/**
 * A helper to generate promises that resolve when a certain voting cycle is
 * active.
 **/
const waitForCycle = (cycleNumber, contract) =>
  new Promise(async (rs, rj) => {
    const currentVoteCycle = +(await contract.currentVoteCycle());
    const cycleLength = +(await contract.voteCycleLength());
    const genesisTimestamp = await contract.genesisBlockTimestamp();
    if (currentVoteCycle > +cycleNumber) {
      return rj(new Error('Target vote cycle has passed'));
    } else if (currentVoteCycle == cycleNumber) {
      return rs();
    }
    const now = +(new Date() / 1000);
    const targetTime = cycleLength * cycleNumber + genesisTimestamp;
    if (targetTime <= now) return rs(targetTime);
    setTimeout(rs, (targetTime - now) * 1000);
});

contract('CommonDAC', accounts => {

  it('should initialize with a proposal', async () => {
    const contract = await CommonDAC.deployed();
    const proposalCount = await contract.proposalCount.call();
    assert.notEqual(proposalCount, 0, 'Initial proposal not present.');
  });

  it('should pass a proposal', async () => {
    const contract = await CommonDAC.deployed();
    const oldProposalCount = +(await contract.proposalCount.call());
    const proposalName = 'test proposal';
    const genesisTimestamp = await contract.genesisBlockTimestamp.call();
    await contract.createProposal(proposalName, 0, accounts[1], 50, 0, 0);
    const newProposalCount = oldProposalCount + 1;
    const proposalIndex = newProposalCount - 1;
    // assert.rejects(contract.vote(proposalIndex, false));
    assert.equal(newProposalCount, await contract.proposalCount());
    // proposal is an array of values as defined in the contract
    // abi doesn't automatically map values to keys?
    const proposal = await contract.proposals(proposalIndex);
    assert.equal(proposal[3], proposalName);
    await waitForCycle(proposal[2], contract);
    // assert.equal(await contract.isProposalAccepted(proposalIndex), false);
    // assert.rejects(contract.applyProposal(proposalIndex));
    contract.vote(proposalIndex, true);
    // await new Promise(rs => setTimeout(rs, 15000));
    // assert.equal(await contract.isProposalAccepted(proposalIndex), true);
  });

});
