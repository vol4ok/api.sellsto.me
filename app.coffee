express  = require('express')
faye     = require('faye')
mongoose = require('mongoose')
color    = require('colors')
fs       = require('fs')
map      = require('./map')
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

#Ip to location

IpToLocationSchema = new mongoose.Schema
  start_ip:     Number
  end_ip:       Number
  loc_id:       Number

IpLocationSchema = new mongoose.Schema
  loc_id:       Number
  country:      String
  region:       String
  city:         String
  postal_code:  String
  latitude:     Number
  longitude:    Number
  metro_code:   Number

IpToLocation =  mongoose.model('ip_to_location', IpToLocationSchema)
IpLocation   =  mongoose.model('ip_location', IpLocationSchema)

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
	ad = new Ad(body: req.body.data.body)
	ad.save (err) ->
		client.publish '/foo',
			class: 'ad'
			action: 'create'
			clientId: req.body.clientId
			data: ad
		res.json(ad)
	
app.put '/ads/:id', (req, res, next) ->
	status = no
	console.log req.method, req.url
	Ad.findById req.params.id, (err, ad) ->	
		if err
			res.json(status: 'NOT_FOUND', 404) 
			return
		ad.body = req.body.data.body;
		ad.updated_at = Date.now()
		ad.save (err) ->
			console.log 'save', ad
			client.publish '/foo',
				class: 'ad'
				action: 'update'
				clientId: req.body.clientId
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
				clientId: req.body.clientId
				data: req.params.id
			res.json(status: 'OK')
			
sleep = (ms) ->
	startTime = new Date().getTime()
	`while (new Date().getTime() < startTime + ms)`
	return
			
app.post '/ads/upload', (req, res, next) ->
	console.log req.method, req.url, req.params
	filename = 'upload/'+Math.round(Math.random()*1000000).toString()+'.jpg'
	ws = fs.createWriteStream(filename, 
		flags: 'w'
		encoding: null
		mode: 0666)
	console.log filename, ws
	req.addListener "data", (data) ->
		console.log '+data', data.length
		ws.write(data)
		#sleep(200) # emulate slow upload
		
	req.addListener "end", ->
		console.log 'end!'
		ws.destroySoon()
		res.json
			status: 'OK'
			url: "http://localhost:4000/#{filename}"
			
app.get '/upload/:file(*)', (req, res, next) ->
	file = req.params.file
	path = "#{__dirname}/upload/#{file}"
	res.download path, (err) ->	
		console.log 'error' if err
		console.log 'transferred %s', path
	,	() ->

app.get "/ipToLocation/:id", (req, res, next) ->
  console.log req.method, req.url
  clientIp = req.connection.remoteAddress
  #todo zhugrov a - Use actual ip address. This need use a valid external ip if you want find any relevant records
  clientIpNumber = map.decodeIp("87.252.227.12")
  IpToLocation.findOne({start_ip: {$lte: clientIpNumber}, end_ip: {$gte: clientIpNumber}}, (err, ipToLocation) ->
    if err or not ipToLocation
      res.json({status: 'NOT_FOUND', 404})
      return
    else
      IpLocation.findOne({loc_id: ipToLocation.loc_id}, (err, ipLocation) ->
        if err or not ipLocation
          res.json({status: 'NOT_FOUND', 404})
          return
        else
          res.json
            status:     "OK"
            country:    ipLocation.country
            region:     ipLocation.region
            city:       ipLocation.city
            latitude:   ipLocation.latitude
            longitude:  ipLocation.longitude
      )
  )

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