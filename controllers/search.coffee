#@author zhugrov alexander
app = require('../app')
TestSeachData = app.db.model('test_search_data')

console.log(app.db)
#todo implement paging
app.get '/search', (req, res, next) ->
  console.log req.method, req.url
  TestSearchData.find {}, [], {limit: 20} , (error, results) ->
    res.json( results )
    return

  res.send("Not implemented yet")

