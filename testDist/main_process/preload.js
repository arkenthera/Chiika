(function() {
  var currentWindow;

  window.ipc = require('electron').ipcRenderer;

  currentWindow = require('electron').remote.getCurrentWindow();

  window.electronWindow = currentWindow;

}).call(this);
