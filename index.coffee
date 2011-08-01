express = require('express')
faye    = require('faye')

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

# example data
ads = [
	{
		_id: 0
		body: "Hello world!"
		created_at: "2011-07-07T19:37:33+03:00"
		updated_at: "2011-07-07T19:37:33+03:00"
	},{
		_id: 1,
		body: "Wow! It's great!",
		created_at: "2011-07-07T19:37:40+03:00",
		updated_at: "2011-07-07T19:37:40+03:00"
	},{
		_id: 2
		body: "WOW!!!"
		created_at: "2011-07-07T20:39:06+03:00"
		updated_at: "2011-07-07T20:39:06+03:00"
	}
]

lastId = 2

# routes

app.get '/', (req, res, next) ->
	console.log req.method, req.url
	res.send('sells2me api')

app.get '/ads', (req, res, next) ->
	console.log req.method, req.url
	res.json(ads)
	
app.post '/ads', (req, res, next) ->
	console.log req.method, req.url
	new_ad = req.body
	lastId = new_ad._id = lastId+1
	new_ad.created_at = new Date().toString()
	new_ad.updated_at = new Date().toString()
	ads.push new_ad
	client.publish '/foo',
		action: 'create'
		ad: new_ad
	res.json new_ad
	
app.put '/ads/:id', (req, res, next) ->
	status = no
	console.log req.method, req.url
	req.body.updated_at = new Date().toString()
	if parseInt(req.body._id) isnt parseInt(req.params.id)
		res.send(500)
		return
	for i in [0...ads.length]
		if parseInt(ads[i]._id) is parseInt(req.params.id)
			console.log 'save', i
			ads[i] = req.body
			status = yes
			break
	if status
		client.publish '/foo',
			action: 'update'
			ad: req.body
		res.json req.body
	else
		res.send(404)
		
app.del '/ads/:id', (req, res, next) ->
	console.log req.method, req.url
	for i in [0...ads.length]
		if parseInt(ads[i]._id) is parseInt(req.params.id)
			console.log 'delete', i
			ads.splice(i,1)
			client.publish '/foo',
				action: 'delete'
				_id: req.params.id
			break
	res.send(200)

app.listen(4000)
console.log('Express server listening on port 4000')