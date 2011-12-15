express  = require('express')
require('express-configure')
faye  = require('faye')
cfg = require('./config')

app = express.createServer()
app.db = require('./db')()
app.bayeux = new faye.NodeAdapter(mount: '/bayeux', timeout: 45)
app.bayeux.attach(app)

# allow Cross Origin Resource Sharing 
app.use (req, res, next) ->
	res.header("Access-Control-Allow-Origin", "*") 
	res.header("Access-Control-Allow-Methods", 
	           "GET, POST, PUT, DELETE, OPTIONS")
	if req.method == 'OPTIONS'
		res.header("Access-Control-Allow-Headers",
		           req.header("access-control-request-headers"))
	next()
	
app.use(express.static(cfg.static + '/images'))

# parse body
app.use(express.bodyParser())

# and route request
app.use(app.router)

process.nextTick -> app.listen(cfg.port, cfg.interface)
app.on 'listening', ->
	console.log("Server listening on #{cfg.interface}:#{cfg.port}".green)
	
module.exports = app