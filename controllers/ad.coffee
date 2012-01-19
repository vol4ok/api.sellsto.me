color    = require('colors')
fs       = require('fs')
crypto   = require('crypto')
mime     = require('mime')
gm       = require('gm')
async    = require('async')
# for debug
# util     = require('util')

app = require('../app')
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
	console.log req.body.data.body
	ad = new Ad(body: req.body.data.body)
	ad.images.push(name: name) for name in req.body.data.images
	console.log ad
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
	
rand = (n) ->
	return Math.round(Math.random()*n)
	
	
gen_name = (n) ->
	a = "abcdefghijklmnopqrstuvwxyz123456789"
	r = []
	for i in [0..n]
		r.push(a[rand(a.length-1)])
	return r.join('')
			
app.post '/ads/upload', (req, res, next) ->
	console.log req.method, req.url, req.params
	console.log req.headers['content-type']
	name = gen_name(8)
	filename = 'upload/'+name
	ws = fs.createWriteStream(filename, 
		flags: 'w'
		encoding: null
		mode: 0666)
	console.log filename, ws
	
	req.addListener "data", (data) ->
		console.log '+data', data.length
		ws.write(data)
		#sleep(50) # emulate slow upload
		
	req.addListener "end", ->
		console.log 'end!'
		ws.destroySoon()
		img = gm(filename)
		img.identify (err, info) ->
			if err
				res.json(status: 'FAIL', 500)
				return
			console.log info
			task1 = (callback) ->
				if info.size.width < 640 and info.size.height < 640
					img
						.noProfile()
						.write("images/m_#{name}.#{info.format}".toLowerCase(), callback)					
				else
					img
						.noProfile()
						.resize(640, 640)
						.write("images/m_#{name}.#{info.format}".toLowerCase(), callback)
			task2 = (callback) ->
				img
					.noProfile()
					.resize(50, 50)
					.write("images/t_#{name}.#{info.format}".toLowerCase(), callback)
			async.parallel [task1, task2], (err) ->
				fs.unlink filename, (err) ->
					console.log 'OK!'
					res.json
						status: 'OK'
						name: name
			
# app.get '/images/:type/:name', (req, res, next) ->
# 	console.log req.params
# 	#TODO Filter request
# 	name = req.params.name
# 	path = "images/#{name}"
# 	res.header('Content-Type', mime.lookup(name, 'application/octet-stream'));
# 	res.download path, (err) ->	
# 		console.log 'error' if err
# 		console.log 'transferred %s', path
# 	,	() ->
			
app.get '/upload/remove/:id', (req, res, next) ->
	file = req.params.file
	path = "#upload/#{file}"
	res.download path, (err) ->	
		console.log 'error' if err
		console.log 'transferred %s', path
	,	() ->
		

# example data
example = [
  body:       "Hello world!"
  price:      "100$"
  count:      "1"
  images:     [
                name: "item-1"
                type: "png"
              ]
  created_at: "2011-07-07T19:37:33+03:00"
  updated_at: "2011-07-07T19:37:33+03:00"
,
  body: "Wow! It's great!",
  price:      "100$"
  count:      "1"
  images:     [
    name: "item-1"
    type: "png"
  ]
  created_at: "2011-07-07T19:37:40+03:00",
  updated_at: "2011-07-07T19:37:40+03:00"
,
  body: "WOW!!!"
  price:      "100$"
  count:      "1"
  images:     [
    name: "item-1"
    type: "png"
  ]
  created_at: "2011-07-07T20:39:06+03:00"
  updated_at: "2011-07-07T20:39:06+03:00"
]

app.configure (done) ->
	console.log 'cleen uploads...'.yellow
	re = /^\..*/i
	for f in fs.readdirSync 'upload/'
		unless re.test(f)
			fs.unlinkSync 'upload/'+f
	re = /\.(jpeg|png|gif)$/i
	for f in fs.readdirSync 'images/'
		if re.test(f)
			fs.unlinkSync 'images/'+f
	Ad.collection.remove {}, (err, result) ->
		Ad.collection.insert example, ->
			Ad.find (err, docs) -> 
				console.log 'create example data...'.yellow
				done()