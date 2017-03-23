const crypto = require("crypto");

const sha1 = m => { let c = crypto.createHash("sha1"); c.update(m); return c.digest("hex"); };

let result = [];

for(let i = 0 ; i <= 1024 ; i++) {
  let msg = "a".repeat(i);
  let hash = sha1(msg);

  result.push(hash);
}

console.log(JSON.stringify(result));
