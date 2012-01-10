// Transparent TCP proxy for single connection only
// Zoran Tomicic ztomicic (at) gmail.com
// 

var sys = require('util');
var tcp = require('net');

var encoding = "binary"
var localActive = false;  // flag to make sure that only one connection
                          // to remote is active

var verbose = false; 

if (process.argv.length < 4) {
  sys.puts
  ("Usage: node tcpproxy.js <local port> <remote host> <remote port> [-v]\n"+
   "                        -v for verbose operation\n");
  process.exit(1);
}

if (process.argv[5] === "-v")
  verbose = true;

function log(s) {
  if (verbose)
    sys.puts("tcpproxy: "+ s);
}


var localPort  = process.argv[2];
var remoteHost = process.argv[3];
var remotePort = process.argv[4];

var remote;

var local = tcp.createServer(function (socket) {

  socket.addListener("connect", function () {
    if (localActive === false) {
      localActive = true;
      socket.setEncoding(encoding);
      socket.setTimeout(0);
      log("Local connect");
    } else {
      log("Local reject");
      socket.end();
      return;
    }

    remote = tcp.createConnection(remotePort, remoteHost);
    remote.setEncoding(encoding);
    remote.setTimeout(0);

    log("Connecting to remote");
    remote.addListener("connect", function() {
      log("Remote connect");
    });

    remote.addListener("data", function(data) {
      socket.write(data, encoding);
      log("Remote: ("+data.length+ ")\n"+data);
    });

    remote.addListener("end", function () {
      log("Remote close");
      socket.end();
      remote.end();
    });

  });

  socket.addListener("data", function (data) {
    remote.write(data, encoding);
    log("Local: ("+data.length+ ")\n"+data);
  });

  socket.addListener("end", function () {
    log("Local close");
    socket.end();
    remote.end();
    localActive = false;
  });

});

log("Starting to listen at "+ localPort +" ...");
local.listen(localPort);