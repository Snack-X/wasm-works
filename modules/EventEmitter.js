// Poor event emitter
// TODO: How should I replace this?

(function() {
  class EventEmitter {
    constructor() {
      this.listeners = {};
    }

    on(type, listener) {
      this.listeners[type] = this.listeners[type] || [];
      this.listeners[type].push(listener);
    }

    emit(type, ...args) {
      let listeners = this.listeners[type] || [];

      listeners.forEach(listener => listener.apply(null, args));
    }
  }

  if(typeof global !== "undefined" && !global.EventEmitter) global.EventEmitter = EventEmitter;
  if(typeof window !== "undefined" && !window.EventEmitter) window.EventEmitter = EventEmitter;
  if(typeof module !== "undefined" && module.exports) module.exports = EventEmitter;
})();
