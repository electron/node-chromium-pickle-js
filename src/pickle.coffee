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

# PickleIterator reads data from a Pickle. The Pickle object must remain valid
# while the PickleIterator object is in use.
class PickleIterator
  constructor: (pickle) ->
    @payload = pickle.header
    @payloadOffset = pickle.headerSize
    @readIndex = 0
    @endIndex = pickle.getPayloadSize()

  readBool: ->
    @readInt() != 0

  readInt: ->
    @readBytes SIZE_INT32, Buffer::readInt32LE

  readUInt32: ->
    @readBytes SIZE_UINT32, Buffer::readUInt32LE

  readInt64: ->
    @readBytes SIZE_INT64, Buffer::readInt64LE

  readUInt64: ->
    @readBytes SIZE_UINT64, Buffer::readUInt64LE

  readFloat: ->
    @readBytes SIZE_FLOAT, Buffer::readFloatLE

  readDouble: ->
    @readBytes SIZE_DOUBLE, Buffer::readDoubleLE

  readString: ->
    @readBytes(@readInt()).toString()

  readBytes: (length, method) ->
    readPayloadOffset = @getReadPayloadOffsetAndAdvance length
    if method?
      method.call @payload, readPayloadOffset, length
    else
      @payload.slice readPayloadOffset, readPayloadOffset + length

  getReadPayloadOffsetAndAdvance: (length) ->
    if length > @endIndex - @readIndex
      @readIndex = @endIndex
      throw new Error("Failed to read data with length of #{length}")
    readPayloadOffset = @payloadOffset + @readIndex
    @advance length
    readPayloadOffset

  advance: (size) ->
    alignedSize = alignInt size, SIZE_UINT32
    if @endIndex - @readIndex < alignedSize
      @readIndex = @endIndex
    else
      @readIndex += alignedSize

# This class provides facilities for basic binary value packing and unpacking.
#
# The Pickle class supports appending primitive values (ints, strings, etc.)
# to a pickle instance.  The Pickle instance grows its internal memory buffer
# dynamically to hold the sequence of primitive values.   The internal memory
# buffer is exposed as the "data" of the Pickle.  This "data" can be passed
# to a Pickle object to initialize it for reading.
#
# When reading from a Pickle object, it is important for the consumer to know
# what value types to read and in what order to read them as the Pickle does
# not keep track of the type of data written to it.
#
# The Pickle's data has a header which contains the size of the Pickle's
# payload.  It can optionally support additional space in the header.  That
# space is controlled by the header_size parameter passed to the Pickle
# constructor.
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
    new PickleIterator(this)

  toBuffer: ->
    @header.slice 0, @headerSize + @getPayloadSize()

  writeBool: (value) ->
    @writeInt if value then 1 else 0

  writeInt: (value) ->
    @writeBytes value, SIZE_INT32, Buffer::writeInt32LE

  writeUInt32: (value) ->
    @writeBytes value, SIZE_UINT32, Buffer::writeUInt32LE

  writeInt64: (value) ->
    @writeBytes value, SIZE_INT64, Buffer::writeInt64LE

  writeUInt64: (value) ->
    @writeBytes value, SIZE_UINT64, Buffer::writeUInt64LE

  writeFloat: (value) ->
    @writeBytes value, SIZE_FLOAT, Buffer::writeFloatLE

  writeDouble: (value) ->
    @writeBytes value, SIZE_DOUBLE, Buffer::writeDoubleLE

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
    endOffset = @headerSize + @writeOffset + length
    @header.fill 0, endOffset, endOffset + dataLength - length
    @setPayloadSize newSize
    @writeOffset = newSize

    true

  resize: (newCapacity) ->
    newCapacity = alignInt newCapacity, PAYLOAD_UNIT
    @header = Buffer.concat [@header, new Buffer(newCapacity)]
    @capacityAfterHeader = newCapacity

module.exports = Pickle
