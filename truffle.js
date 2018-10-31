const HDWalletProvider = require('truffle-hdwallet-provider');

const rinkebyKey = process.env.RINKEBY_PRIVATE_KEY || 'current pottery pretty miracle vanish release pig fiction balcony retire twist cluster';
const provider = new HDWalletProvider(rinkebyKey, 'https://rinkeby.commontheory.io');

module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*'
    },
    rinkeby: {
      provider,
      network_id: '4'
    },
    live: {
      host: 'eth.commontheory.io',
      port: 80,
      network_id: 1
    }
  }
};
