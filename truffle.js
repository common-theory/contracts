module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*'
    },
    live: {
      host: 'eth.commontheory.io',
      port: 80,
      network_id: 1
    }
  }
};
