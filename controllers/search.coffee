#@author zhugrov alexander
app = require('../app')
TestSearchData = app.db.model('test_search_data')

#todo implement paging
app.get '/search', (req, res, next) ->
  console.log req.method, req.url
  TestSearchData.find {}, [], {limit: 20} , (error, results) ->
    console.log error if error
    res.json( results )
    return
