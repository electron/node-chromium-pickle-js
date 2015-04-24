# sizeof(T).
SIZE_INT32 = 4
SIZE_UINT32 = 4
SIZE_INT64 = 8
SIZE_UINT64 = 8
SIZE_FLOAT = 4
SIZE_DOUBLE = 8

# The allocation granularity of the payload.
PAYLOAD_UNIT = 64

# Largest JS number.
CAPACITY_READ_ONLY = 9007199254740992

# Aligns 'i' by rounding it up to the next multiple of 'alignment'.
alignInt = (i, alignment) ->
  i + (alignment - (i % alignment)) % alignment

class Pickle
  constructor: (buffer) ->
    if buffer
      @initFromBuffer buffer
    else
      @initEmpty()

  initEmpty: ->
    @header = new Buffer(0)
    @headerSize = SIZE_UINT32
    @capacityAfterHeader = 0
    @writeOffset = 0

    @resize PAYLOAD_UNIT
    @setPayloadSize 0

  initFromBuffer: (buffer) ->
    @header = buffer
    @headerSize = buffer.length - @getPayloadSize()
    @capacityAfterHeader = CAPACITY_READ_ONLY
    @writeOffset = 0

    @headerSize = 0 if @headerSize > buffer.length
    @headerSize = 0 if @headerSize != alignInt @headerSize, SIZE_UINT32
    @header = new Buffer(0) if @headerSize == 0

  createIterator: ->

  toBuffer: ->
    @header.slice 0, @headerSize + @getPayloadSize()

  writeBool: (value) ->
    @writeInt if value then 1 else 0

  writeInt: (value) ->
    @writeBytes value, SIZE_INT32, Buffer.writeInt32LE

  writeUInt32: (value) ->
    @writeBytes value, SIZE_UINT32, Buffer.writeUInt32LE

  writeInt64: (value) ->
    @writeBytes value, SIZE_INT64, Buffer.writeInt64LE

  writeUInt64: (value) ->
    @writeBytes value, SIZE_UINT64, Buffer.writeUInt64LE

  writeFloat: (value) ->
    @writeBytes value, SIZE_FLOAT, Buffer.writeFloatLE

  writeDouble: (value) ->
    @writeBytes value, SIZE_DOUBLE, Buffer.writeDoubleLE

  writeString: (value) ->
    return false unless @writeInt value.length
    @writeBytes value, value.length

  setPayloadSize: (payloadSize) ->
    @header.writeUInt32LE payloadSize, 0

  getPayloadSize: ->
    @header.readUInt32LE 0

  writeBytes: (data, length, method) ->
    dataLength = alignInt length, SIZE_UINT32
    newSize = @writeOffset + dataLength
    if newSize > @capacityAfterHeader
      @resize Math.max(@capacityAfterHeader * 2, newSize)

    if method?
      method.call @header, data, @headerSize + @writeOffset
    else
      @header.write data, @headerSize + @writeOffset, length
    @header.fill 0, @headerSize + length, dataLength - length
    @setPayloadSize newSize
    @writeOffset = newSize

    true

  resize: (newCapacity) ->
    newCapacity = alignInt newCapacity, PAYLOAD_UNIT
    @header = Buffer.concat [@header, new Buffer(newCapacity)]
    @capacityAfterHeader = newCapacity

module.exports = Pickle
