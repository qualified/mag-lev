class String
  def to_base64
    [[self].pack('H*')].pack('m0')
  end

  def to_hex
    self.unpack("m0").first.unpack("H*").first
  end
end