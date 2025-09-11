// Offscreen page: keeps the service worker alive via a long-lived port.
// No direct native messaging here (MV3 restricts it to the SW context).

(function() {
  let swPort = null;

  function connectSW() {
    try {
      swPort = chrome.runtime.connect({ name: 'bt-keepalive' });
      console.log('[offscreen] Connected keepalive port to service worker');

      // Send a periodic ping to ensure activity
      const pingInterval = setInterval(() => {
        try { swPort.postMessage({ type: 'ping', ts: Date.now() }); } catch (_) {}
      }, 20000);

      swPort.onDisconnect.addListener(() => {
        clearInterval(pingInterval);
        console.warn('[offscreen] Keepalive port disconnected');
        // Attempt to reconnect shortly
        setTimeout(connectSW, 1000);
      });
    } catch (e) {
      console.error('[offscreen] Failed to connect to SW', e);
      setTimeout(connectSW, 2000);
    }
  }

  connectSW();
})();
