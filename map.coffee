
# Convert ip address string to a ip number
decodeIp = (remoteAddress) ->
    ipParts = remoteAddress.split(".")
    throw new Error("Invalid input string") if ipParts.length != 4
    multipliers = [16777216, 65536, 256, 1]
    ipNumber = 0
    for i in [0..3]
        ipNumber += multipliers[i] * parseInt(ipParts[i])
    return ipNumber

# export all utility function
module.exports.decodeIp = decodeIp