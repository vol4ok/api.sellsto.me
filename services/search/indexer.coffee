Hook = require('hook.io').Hook

indexerHook = new Hook(
  name: 'search-indexer'
  debug: true
)

indexerHook.on('hook::ready', () ->
  console.log("event received")
)

indexerHook.start()

testHook = new Hook(
  name: 'hook'
  debug: true
)

testHook.start()
testHook.emit("ready", {name: "test", family: "test"})


