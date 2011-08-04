var ads, app, bayeux, client, express, faye, lastId;
express = require('express');
faye = require('faye');
bayeux = new faye.NodeAdapter({
  mount: '/bayeux',
  timeout: 45
});
app = express.createServer();
bayeux.attach(app);
client = bayeux.getClient();
app.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  if (req.method === 'OPTIONS') {
    res.header("Access-Control-Allow-Headers", req.header("access-control-request-headers"));
  }
  return next();
});
app.use(express.bodyParser());
app.use(app.router);
ads = [
  {
    id: 0,
    body: "Hello world!",
    created_at: "2011-07-07T19:37:33+03:00",
    updated_at: "2011-07-07T19:37:33+03:00"
  }, {
    id: 1,
    body: "Wow! It's great!",
    created_at: "2011-07-07T19:37:40+03:00",
    updated_at: "2011-07-07T19:37:40+03:00"
  }, {
    id: 2,
    body: "WOW!!!",
    created_at: "2011-07-07T20:39:06+03:00",
    updated_at: "2011-07-07T20:39:06+03:00"
  }
];
lastId = 2;
app.get('/', function(req, res, next) {
  console.log(req.method, req.url);
  return res.send('sells2me api');
});
app.get('/ads', function(req, res, next) {
  console.log(req.method, req.url);
  return res.json(ads);
});
app.post('/ads', function(req, res, next) {
  var new_ad;
  console.log(req.method, req.url);
  new_ad = req.body;
  lastId = new_ad.id = lastId + 1;
  new_ad.created_at = new Date().toString();
  new_ad.updated_at = new Date().toString();
  ads.push(new_ad);
  client.publish('/foo', {
    "class": 'ad',
    action: 'create',
    data: new_ad
  });
  return res.json(new_ad);
});
app.put('/ads/:id', function(req, res, next) {
  var i, status, _ref;
  status = false;
  console.log(req.method, req.url);
  req.body.updated_at = new Date().toString();
  if (parseInt(req.body.id) !== parseInt(req.params.id)) {
    res.send(500);
    return;
  }
  for (i = 0, _ref = ads.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
    if (parseInt(ads[i].id) === parseInt(req.params.id)) {
      console.log('save', i);
      ads[i] = req.body;
      status = true;
      break;
    }
  }
  if (status) {
    client.publish('/foo', {
      "class": 'ad',
      action: 'update',
      data: req.body
    });
    return res.json(req.body);
  } else {
    return res.json({
      status: 'FAIL'
    }, 404);
  }
});
app.del('/ads/:id', function(req, res, next) {
  var i, _ref;
  console.log(req.method, req.url);
  for (i = 0, _ref = ads.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
    if (parseInt(ads[i].id) === parseInt(req.params.id)) {
      console.log('delete', i);
      ads.splice(i, 1);
      client.publish('/foo', {
        "class": 'ad',
        action: 'delete',
        data: req.params.id
      });
      break;
    }
  }
  return res.json({
    status: 'OK'
  });
});
app.listen(4000);
console.log('Express server listening on port 4000');