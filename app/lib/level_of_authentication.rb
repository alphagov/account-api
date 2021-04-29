module LevelOfAuthentication
  def self.name_to_integer(name)
    Integer(name.delete_prefix("level"))
  end

  def self.integer_to_name(integer)
    "level#{integer}"
  end
end
