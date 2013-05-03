/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

var fs = require('fs');
var in_file  = process.argv[2] || "out.json";
var out_file = process.argv[3] || "out.plantuml";
var png_file = process.argv[4] || "out.png";

fs.readFile(in_file, 'utf8', function (err,text) {
  if (err) {
    return console.log(err);
  }

  var data = JSON.parse(text);
  var dbgServer = data.dbgServerPort;
  var out = fs.createWriteStream(out_file);

  out.write("@startuml " + png_file + "\n");

  data.ports.forEach(function(port) {
    if (port === dbgServer) {
      out.write("actor dbgserver");
    } else if(dbgServer) {
      out.write("actor dbgclient");
    } else {
      out.write("actor dbgactor"+port);
    }
    out.write(" as " + port + "\n");
  });

  var prefix = "";

  data.collectedMessages.forEach(function(pkt) {
   prefix = pkt.src_port + "->" + pkt.dst_port + ":";
   pkt.messages.forEach(function (message) {
     out.write(prefix+JSON.stringify(message,summary,2).replace(/[\n]/g, '\\n')+"\n");
   });
  });

  out.end("@enduml\n");

  return null;
});

function summary(key, value) {
    switch (typeof value) {
    case "string":
        if (value.length > 100) {
            value = "VERY LONG STRING...";
        }
        break;
    case "object":
    case "function":
    }

    return value;
}
