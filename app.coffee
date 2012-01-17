express  = require('express')
require('express-configure')
faye     = require('faye')
Indexer  = require('./services/search/indexer')

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
	
app.use(express.static(__dirname + '/images'))

# parse body
app.use(express.bodyParser())

# and route request
app.use(app.router)

process.nextTick -> app.listen(4000)
app.on 'listening', ->
	console.log('Server listening on port 4000'.green)


## test the indexer work
ad =
  id:           'test-object-id'
  message:      'this is really test message'
  price:        110
  currency:     'USD'
  owner:        'owner-ref-id'

  location:
    latitude:     56.3
    longitude:    23.5

  created_at:   new Date()
  updated_at:   new Date()
  videos:       ['http://www.youtube.com/watch?v=daJ1uue7ejM&feature=related']
  images:       ['http://i3.ytimg.com/vi/2J2dwFVZHsY/default.jpg']
  urls:         []
  tags:         []
  mentions:     []
  description:  'this is really cool product'
  state:        'published'
  searchable:   true
  comments:     []
  messages:     []
  statistics:
    shows:        100
    views:        300
    likes:        34

console.log('prepared to create indexer');
searchIndexer = new Indexer('http://ls.sl.me:8080/ad/update/json')
searchIndexer.on('ready', () ->
  searchIndexer.index( ad )
)


module.exports = app