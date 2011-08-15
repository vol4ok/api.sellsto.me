color    = require('colors')
fs       = require('fs')
# async    = require('async')
# for debug
# util     = require('util')

app = require('./app')
bayeux = app.bayeux
Ad = app.db.model('Ad')

client = bayeux.getClient()

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
		sleep(200) # emulate slow upload
		
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

# create sample data
app.configure (done) ->
	Ad.collection.remove {}, (err, result) ->
		Ad.collection.insert example, ->
			Ad.find (err, docs) -> 
				console.log 'create example data: '.yellow, docs
				done()