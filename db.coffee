mongoose = require('mongoose')

ObjectId = mongoose.Schema.ObjectId
Schema   = mongoose.Schema

# Ad

Images = new Schema
	name: String
	type: String

AdSchema = new Schema
	id: ObjectId
	body: String
	images: [Images]
	created_at: 
		type: Date
		default: Date.now
	updated_at: 
		type: Date
		default: Date.now
		
#Ip to location

IpToLocationSchema = new Schema
  start_ip:     Number
  end_ip:       Number
  loc_id:       Number

IpLocationSchema = new Schema
  loc_id:       Number
  country:      String
  region:       String
  city:         String
  postal_code:  String
  latitude:     Number
  longitude:    Number
  metro_code:   Number

TestSearchData = new Schema
  id: 					ObjectId
  body:					String
  price:				Number
  location:
    latitude: 	Number
    longitude:	Number
  attachments:	Number
  created_at:
    type: 			Date
    default: 		Date.now
  updated_at:
    type: 			Date
    default: 		Date.now

mongoose.model('Ad', AdSchema)
mongoose.model('ip_to_location', IpToLocationSchema)
mongoose.model('ip_location', IpLocationSchema)
mongoose.model('test_search_data', TestSearchData)

module.exports = () -> mongoose.connect('mongodb://localhost/sells2me_api_dev')