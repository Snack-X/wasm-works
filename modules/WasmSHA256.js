(function() {
  const K = [ 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2 ];
  const pad = n => ("0000000" + (n >>> 0).toString(16)).substr(-8);

  class WasmSHA256 extends EventEmitter {
    constructor(buffer) {
      super();

      if(!WebAssembly) throw "WebAssembly is not supported!";

      this.memory = new WebAssembly.Memory({ initial: 1 });
      this.module = {};
      this.MEM32 = new Uint32Array(this.memory.buffer);
      this.MEM8 = new Uint8Array(this.memory.buffer);
      this.ready = false;
    }

    loadWasmBuffer(buffer) {
      let wasmImport = {
        env: { memory: this.memory },
      };

      WebAssembly.instantiate(buffer, wasmImport).then(result => {
        for(let i = 0 ; i < K.length ; i++) this.MEM32[64 + i] = K[i];

        this.ready = true;
        this.module = result.instance.exports;
        this.emit("ready");
      });
    }

    hashString(input) {
      if(!this.ready) throw "WebAssembly Module is not loaded.";

      this.module.sha256_init();

      let message = unescape(encodeURIComponent(input));

      for(let i = 0 ; i < message.length ; i++) {
        this.MEM8[i % 64] = message.charCodeAt(i);
        if(i % 64 === 63) this.module.sha256_update();
      }

      this.module.sha256_end(message.length % 64);

      let h0 = pad(this.MEM32[16]),
          h1 = pad(this.MEM32[17]),
          h2 = pad(this.MEM32[18]),
          h3 = pad(this.MEM32[19]),
          h4 = pad(this.MEM32[20]),
          h5 = pad(this.MEM32[21]),
          h6 = pad(this.MEM32[22]),
          h7 = pad(this.MEM32[23]);
      let result = h0 + h1 + h2 + h3 + h4 + h5 + h6 + h7;

      return result;
    }
  }

  if(typeof global !== "undefined" && !global.WasmSHA256) global.WasmSHA256 = WasmSHA256;
  if(typeof window !== "undefined" && !window.WasmSHA256) window.WasmSHA256 = WasmSHA256;
  if(typeof module !== "undefined" && module.exports) module.exports = WasmSHA256;
})();
