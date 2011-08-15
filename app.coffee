express  = require('express')
faye     = require('faye')

app = express.createServer()
app.db = require('./db')()
app.bayeux = new faye.NodeAdapter(mount: '/bayeux', timeout: 45)
app.bayeux.attach(app)

# allow Cross Origin Resource Sharing 
app.use (req, res, next) ->
	res.header("Access-Control-Allow-Origin", "*") 
	res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	if req.method == 'OPTIONS'
		res.header("Access-Control-Allow-Headers", req.header("access-control-request-headers"))
	next()

# parse body
app.use(express.bodyParser())

# and route request
app.use(app.router)

# example data
example = [
	body: "Hello world!"
	created_at: "2011-07-07T19:37:33+03:00"
	updated_at: "2011-07-07T19:37:33+03:00"
,
	body: "Wow! It's great!",
	created_at: "2011-07-07T19:37:40+03:00",
	updated_at: "2011-07-07T19:37:40+03:00"
,
	body: "WOW!!!"
	created_at: "2011-07-07T20:39:06+03:00"
	updated_at: "2011-07-07T20:39:06+03:00"
]

Ad = app.db.model('Ad')

# create sample data and start the server
Ad.collection.remove {}, (err, result) ->
	Ad.collection.insert example, ->
		Ad.find (err, docs) -> 
			console.log 'create example data: '.yellow, docs
			app.listen(4000)
			console.log('Express server listening on port 4000'.green)
			
module.exports = app