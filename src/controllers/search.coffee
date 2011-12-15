#@author zhugrov alexander
app = require('../app')
mysql = require('mysql')
TestSearchData = app.db.model('test_search_data')

#todo implement paging
app.get '/search', ( req , res , next ) ->
	console.log req.method, req.url
	TestSearchData.find {}, [], {limit: 20} , (error, results) ->
		console.log error if error
		res.json( results )
		return

app.get '/searchBlog', ( req , res , next ) ->
	#is it possible to refactor it using aop like style?
	console.log( req.method , req.url )
	queryStr = req.query['query']
	query = new Query( queryStr , 0 , 20 )
	query.list ( err, results , fields ) ->
		res.json( results )
		return
	return

### Performs query to a sphinx server using mysql connector ###
class Query
	### handles connections to the mysql interface ###
	mysqlClient: mysql.createClient({ port: 9306 })
	### @type {string} search query ###
	query: null
	### @type {number} number of records that being skip ###
	offset: null
	### @type {number} number of records that being returned ###
	limit: null

	### creates a new instance ###
	constructor: ( @query , @offset , @limit ) ->
		return


	# query the sphinx index
	# @param callback {function(err: {Object}, results: {Object}, fields: {Object})}
	list: (callback) ->
		@mysqlClient.query('select original, price , @weight as w from rt where match( ? ) order by w desc limit ?,?', [ @query , @offset , @limit ], callback)
		return this

###indexes the data###
###todo zhugrov - needs to be transformed before the application to the real code###
class Indexer
	###perform operation on search engine using mysql connector protocol###
	mysqlClient: null

	constructor: () ->
		#do nothing for a while
		@mysqlClient = mysql.createClient
			port: 9306
		return

	###submit add for the indexing operation###
	indexAdd: ( ad ) ->
		@mysqlClient.query('insert into rt values( ? , ? , ? , ? , ? )',[ @_idHash(ad._id.toString()) , ad.body , ad.price , ad.location.latitude , ad.location.longitude ], (err, info) =>
			console.log 'info' + info
			console.log 'error occured - ' + err if err
		)
		return this

	###converts string to the suitable id integer###
	_idHash: ( str ) ->
		hash = 0
		return hash if (str.length == 0)
		for i in [0..(str.length - 1)]
			char = str.charCodeAt( i )
			hash = ( ( hash << 5 ) - hash ) + char
			hash = hash & hash #Convert to 32bit integer
		return hash

