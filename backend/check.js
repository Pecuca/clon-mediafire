const { Client } = require('pg');
const client = new Client({ user: 'postgres', password: '1234', host: 'localhost', port: 5433, database: 'archive' });
client.connect().then(() => client.query('SELECT archive_id, private_key FROM archive LIMIT 1')).then(res => {
  if(res.rows.length > 0) {
    const crypto = require('crypto');
    try {
      const privateKeyObj = crypto.createPrivateKey(res.rows[0].private_key);
      const pubKeyObj = crypto.createPublicKey(privateKeyObj);
      console.log('Public key exported:', pubKeyObj.export({ type: 'spki', format: 'pem' }).substring(0, 50));
    } catch(e) {
      console.error('Error parsing:', e);
    }
  }
  client.end();
}).catch(console.error);
