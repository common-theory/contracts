const digitalocean = require('digitalocean');
const client = digitalocean.client(process.env.DIGITAL_OCEAN_TOKEN);
const fs = require('fs');
const fetch = require('node-fetch');
const { exec } = require('child_process');
const pexec = promisify(exec);

const args = [...process.argv];
if (args.length !== 4) {
  console.log(`
Expected 4 arguments.

Usage: node dns-update.js <domain> <path>

domain: The dns TXT record to update. Subdomains should be prefixed with _dnslink.

path: The filepath to be bound to the domain via dnslink. This will be added to IPFS.

    `);
  process.exit(0);
}

const domainArg = args[2];
const pathArg = args[3];

const domainParts = domainArg.split('.');
if (domainParts.length < 2) {
  console.log('Invalid domain name supplied:', domainArg);
  process.exit(1);
}

const rootDomain = domainParts.slice(-2).join('.');
const subdomain = domainParts.slice(0, -2).join('.') || '@';

(async () => {
  try {
    const daemon = exec('ipfs init && ipfs daemon');
    const hash = (await pexec(`sleep 10 && ipfs add -r ${pathArg} -Q`)).replace(/\s/g, '');
    console.log(`Added static directory at ${hash}`);
    const domains = await client.domains.list();
    const records = await client.domains.listRecords(rootDomain);
    const dnslinkRecord = records.find(record => {
      if (record.type !== 'TXT') return false;
      if (record.data.indexOf('dnslink=') === -1) return false;
      if (record.name !== subdomain) return false;
      return record;
    });
    if (!dnslinkRecord) {
      console.log('Unable to find dnslink record!');
      process.exit(1);
    }
    await client.domains.updateRecord(rootDomain, dnslinkRecord.id, {
      data: `dnslink=/ipfs/${hash}`
    });
    console.log('DNS record updated')
    // Pull the file across the ipfs servers so it's available for at least a bit
    await fetch(`https://ipfs.io/ipfs/${hash}`);
    // Pull commontheory.io 5 times to make sure each ipfs node is hit
    // await Promise.all(Array.apply(null, Array(5)).map(() => fetch('https://commontheory.io')));
    const msWait = 60 * 2 * 1000;
    console.log(`Waiting ${msWait / 1000} seconds before spinning down.`);
    setTimeout(() => process.exit(0), msWait);
  } catch (err) {
    console.log(err);
  }
})();

function promisify(fn) {
  return (...args) => {
    return new Promise((rs, rj) => {
      fn(...args, (err, ..._args) => {
        if (err) return rj(err);
        rs(..._args);
      });
    });
  };
}
