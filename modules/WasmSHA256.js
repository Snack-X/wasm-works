(function() {
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
