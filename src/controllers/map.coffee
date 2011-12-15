app = require('../app')
IpToLocation =  app.db.model('ip_to_location')
IpLocation   =  app.db.model('ip_location')

# Convert ip address string to a ip number
decodeIp = (remoteAddress) ->
    ipParts = remoteAddress.split(".")
    throw new Error("Invalid input string") if ipParts.length != 4
    multipliers = [16777216, 65536, 256, 1]
    ipNumber = 0
    for i in [0..3]
        ipNumber += multipliers[i] * parseInt(ipParts[i])
    return ipNumber

app.get "/ipToLocation", (req, res, next) ->
  console.log req.method, req.url
  # clientIp = req.connection.remoteAddress
  clientIp = "87.252.227.12"
  #todo zhugrov a - Use actual ip address. This need use a valid external ip if you want find any relevant records
  clientIpNumber = decodeIp(clientIp)
  IpToLocation.findOne({start_ip: {$lte: clientIpNumber}, end_ip: {$gte: clientIpNumber}}, (err, ipToLocation) ->
    if err or not ipToLocation
      res.json(status: 'NOT_FOUND', 404)
      return
    else
      IpLocation.findOne({loc_id: ipToLocation.loc_id}, (err, ipLocation) ->
        if err or not ipLocation
          res.json(status: 'NOT_FOUND', 404)
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