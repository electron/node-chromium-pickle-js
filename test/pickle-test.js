var assert = require('assert')
var Pickle = require('..')

describe('Pickle', function () {
  it('supports multi-byte characters', function () {
    var write = Pickle.createEmpty()
    write.writeString('女の子.txt')

    var read = Pickle.createFromBuffer(write.toBuffer())
    assert.equal(read.createIterator().readString(), '女の子.txt')
  })
})
