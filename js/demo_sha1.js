window.addEventListener("load", () => {
  const $notification = document.getElementById("notification");
  const $input = document.getElementById("input");
  const $output = document.getElementById("output");

  // Check WebAssembly support
  // Assume fetch is supported if browser supports WebAssembly
  if(!window.WebAssembly) {
    $notification.innerHTML = "Your browser does not support WebAssembly.";
    return;
  }

  let sha1;

  function runHash() {
    $output.innerHTML = sha1.hashString($input.value);
  }

  fetch("modules/sha1.wasm?v=1.0.0")
    .then(res => res.arrayBuffer())
    .then(buffer => {
      sha1 = new WasmSHA1(buffer);
      sha1.on("ready", () => {
        $notification.innerHTML = "Module has loaded.";
        runHash();
      });

      $input.addEventListener("input", () => { runHash(); });
    });
});
