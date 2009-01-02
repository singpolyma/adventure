class Object
	def dref
		self
	end
end

class Extern
	@@externs = {}
	def self.externs
		@@externs
	end
	def initialize(id)
		@id = id
	end
	def dref
		@@externs[@id]
	end
	def to_s
		dref.to_s
	end
	def inspect
		"Extern: #{dref.inspect}"
	end
	def method_missing(id, *args)
		if args.length > 0
			dref.send(id, args)
		else
			dref.send(id)
		end
	end
end

def extern(*args)
	if args[0].is_a?Hash
		args[0].each do |k, v|
			Extern::externs[k] = v
		end
	else
		args.each do |k|
			Extern::externs[k] = nil
		end
	end
end

def ref(id=nil)
	instance_variables.each do |i|
		extern i.sub(/^./,'').to_sym => instance_variable_get(i)
	end
	return Extern::externs[id] if Extern::externs[id]
	Extern.new(id)
end

ref
