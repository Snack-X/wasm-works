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

  let sha1 = new WasmSHA1();

  function runHash() {
    $output.innerHTML = sha1.hashString($input.value);
  };

  function onModuleReady() {
    $notification.innerHTML = "Module has loaded.";
    $input.addEventListener("input", () => { runHash(); });
    runHash();

    $btnTest.addEventListener("click", () => { testSha1(); });
  };

  fetch("modules/sha1.wasm?v=1.0.0")
    .then(res => res.arrayBuffer())
    .then(buffer => {
      sha1.loadWasmBuffer(buffer);

      sha1.on("ready", onModuleReady);
    });

  // Test feature
  function testSha1() {
    fetch("data/sha1-repeat-a-1024.json")
      .then(res => res.json())
      .then(data => {
        for(let i = 0 ; i <= 1024 ; i++) {
          let str = "a".repeat(i);
          let expected = data[i];
          let actual = sha1.hashString(str);

          if(expected !== actual) throw `Hash test failed!<br><code>SHA1("a".repeat(${i}))</code><br>Actual: <code>"${actual}"</code><br>Expected: <code>"${expected}"</code>`;
        }

        throw `Hash test has passed.`;
      })
      .catch(msg => { $notification.innerHTML = msg; });
  }
});
