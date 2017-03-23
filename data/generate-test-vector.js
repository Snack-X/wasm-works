const crypto = require("crypto");
const fs = require("fs");

const sha1 = m => { let c = crypto.createHash("sha1"); c.update(m); return c.digest("hex"); };
const sha256 = m => { let c = crypto.createHash("sha256"); c.update(m); return c.digest("hex"); };

function generate(func) {
  let result = [];

  for(let i = 0 ; i <= 1024 ; i++) {
    let msg = "a".repeat(i);
    let hash = func(msg);

    result.push(hash);
  }

  return result;
}

fs.writeFileSync(__dirname + "/sha1-repeat-a-1024.json", JSON.stringify(generate(sha1)));
fs.writeFileSync(__dirname + "/sha256-repeat-a-1024.json", JSON.stringify(generate(sha256)));
