// Startup script — fires ControlReady once the controlAddIn container exists.
// On page reopen, cached scripts may execute before BC injects the div.
(function waitAndFire() {
    if (document.getElementById('controlAddIn')) {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlReady', []);
    } else {
        setTimeout(waitAndFire, 50);
    }
})();
