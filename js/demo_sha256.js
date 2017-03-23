window.addEventListener("load", () => {
  const $notification = document.getElementById("notification");
  const $input = document.getElementById("input");
  const $output = document.getElementById("output");
  const $btnTest = document.getElementById("btn-test");

  // Check WebAssembly support
  // Assume fetch is supported if browser supports WebAssembly
  if(!WebAssembly || !WebAssembly.instantiate) {
    $notification.innerHTML = "Your browser does not support WebAssembly.";
    return;
  }

  let sha256 = new WasmSHA256();

  function runHash() {
    $output.innerHTML = sha256.hashString($input.value);
  };

  function onModuleReady() {
    $notification.innerHTML = "Module has loaded.";
    $input.addEventListener("input", () => { runHash(); });
    runHash();

    $btnTest.addEventListener("click", () => { testSha256(); });
  };

  fetch("modules/sha256.wasm?v=1.0.0")
    .then(res => res.arrayBuffer())
    .then(buffer => {
      sha256.loadWasmBuffer(buffer);

      sha256.on("ready", onModuleReady);
    });

  // Test feature
  function testSha256() {
    fetch("data/sha256-repeat-a-1024.json")
      .then(res => res.json())
      .then(data => {
        for(let i = 0 ; i <= 1024 ; i++) {
          let str = "a".repeat(i);
          let expected = data[i];
          let actual = sha256.hashString(str);

          if(expected !== actual) throw `Hash test failed!<br><code>SHA256("a".repeat(${i}))</code><br>Actual: <code>"${actual}"</code><br>Expected: <code>"${expected}"</code>`;
        }

        throw `Hash test has passed.`;
      })
      .catch(msg => { $notification.innerHTML = msg; });
  }
});
