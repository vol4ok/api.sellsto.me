express  = require('express')
faye     = require('faye')
mongoose = require('mongoose')
color    = require('colors')
# async    = require('async')
# for debug
# util     = require('util')

# Model #
mongoose.connect('mongodb://localhost/sells2me_api_dev')

ObjectId = mongoose.Schema.ObjectId
Schema   = mongoose.Schema

AdSchema = new mongoose.Schema
	id: ObjectId
	body: String
	created_at: 
		type: Date
		default: Date.now
	updated_at: 
		type: Date
		default: Date.now
	
Ad = mongoose.model('Ad', AdSchema)
				
# pub-sub #

bayeux = new faye.NodeAdapter(mount: '/bayeux', timeout: 45)
app = express.createServer()
bayeux.attach(app)

client = bayeux.getClient()

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

lastId = 2

# routes

app.get '/', (req, res, next) ->
	console.log req.method, req.url
	res.send('sells2me api')

app.get '/ads', (req, res, next) ->
	console.log req.method, req.url
	Ad.find (err, ads) ->	res.json(ads)
	
app.post '/ads', (req, res, next) ->
	console.log req.method, req.url
	ad = new Ad(body: req.body.body)
	ad.save (err) ->
		client.publish '/foo',
			class: 'ad'
			action: 'create'
			data: ad
		res.json(ad)
	
app.put '/ads/:id', (req, res, next) ->
	status = no
	console.log req.method, req.url
	Ad.findById req.params.id, (err, ad) ->	
		if err
			res.json(status: 'NOT_FOUND', 404) 
			return
		ad.body = req.body.body;
		ad.updated_at = Date.now()
		ad.save (err) ->
			console.log 'save', ad
			client.publish '/foo',
				class: 'ad'
				action: 'update'
				data: ad
			res.json ad
		
app.del '/ads/:id', (req, res, next) ->
	console.log req.method, req.url
	Ad.findById req.params.id, (err, ad) ->	
		if err or not ad
			res.json(status: 'NOT_FOUND', 404) 
			return
		ad.remove (err) ->
			client.publish '/foo',
				class: 'ad'
				action: 'delete'
				data: req.params.id
			res.json(status: 'OK')

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

# create sample data and start the server
Ad.collection.remove {}, (err, result) ->
	Ad.collection.insert example, ->
		Ad.find (err, docs) -> 
			console.log 'create example data: '.yellow, docs
			app.listen(4000)
			console.log('Express server listening on port 4000'.green)