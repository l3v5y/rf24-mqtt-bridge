mqtt = require("mqtt")
serialport = require "serialport"
SerialPort = serialport.SerialPort
convertHex = require('convert-hex')

class Packet
  constructor: (@status, @hardwareId, @size, rawVersion, rawType, rawPayload) ->
    if rawPayload
      @payload = new Buffer(convertHex.hexToBytes(rawPayload))
    else 
      @payload = null
    @version = parseInt(rawVersion)
    @type = parseInt(rawType)
    
class TemperaturePacket
  constructor: ->
    @temperature = 0

  @decode: (payload) ->
    temperaturePacket = new TemperaturePacket()
    console.log payload
    temperaturePacket.temperature = payload.readInt16LE(0) / 10
    temperaturePacket

class PacketDispatcher
  constructor: ->
    @serialPort = new SerialPort "/dev/tty.usbserial-A6007oLa",
      baudrate: 115200
      parser: serialport.parsers.readline('\r\n')    
    @serialPort.on 'open', @open
    @client = mqtt.connect "tcp://192.168.0.112"

  open: =>
    @serialPort.on 'data', @onPacketArrived

  onPacketArrived: (data) =>
    rawPacket = String(data).trim().split(':')
    packet = new Packet(rawPacket[0], rawPacket[2], rawPacket[3], rawPacket[4], rawPacket[5],  rawPacket[6])


    payload = @decodePayload(packet)
    @dispatchPayload(packet, payload)

  decodePayload: (packet) =>
    if packet.status is 'OK'
      if packet.type is 1
        if packet.version is 1
          TemperaturePacket.decode(packet.payload)
    

  dispatchPayload: (packet, payload) =>
    console.log 'dispatching', payload, 'from', packet.hardwareId
    @client.publish("RF24HOME/#{packet.hardwareId}", JSON.stringify(payload))

packetDispatcher = new PacketDispatcher()