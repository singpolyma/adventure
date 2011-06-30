module Adventure

	# Represents a location in the world
	class Room
		@@show_directions = false
		def self.show_directions
			@@show_directions = true
		end

		def initialize(name, description='')
			@name = Adventure::resolve(name)
			@description = description
			@directions = {}
			@items = []
		end

		def name
			@name.to_s.gsub(/_/, ' ').capitalize
		end

		def [](k)
			k = k[0] if k.is_a?Array
			@directions[k] || self
		end

		def to_s
			s = "#{name}\n#{@description}\n"
			if @@show_directions
				@directions.each do |dir,room|
					s << "#{dir.to_s.capitalize}, #{room.name}. "
				end
				s << "\n"
			end
			@items.each do |item|
				s << "\nThere is #{item.name} here."
			end
			s
		end

		def has_item?(name)
			case name
				when Adventure::Item
					return @items.includes?(name)
				else
					@items.each do |item|
						return item if item === name
					end
			end
			false
		end

		def get_item(id)
			@items.each_with_index do |item, idx|
				if item === id
					return @items.delete_at(idx)
				end
			end
			nil
		end

		private

		def item(item, description='', synonyms=[])
			case item
				when Adventure::Item
					@items << item
					return item
				else
					theitem = Adventure::Item.new(item, description, synonyms)
					@items << theitem
					return theitem
			end
		end

		def description(r=nil)
			@description = r if r
			@description
		end

		def direction(params)
			case params
				when Symbol
					@directions[params]
				when Hash
					params.each do |k, v|
						@directions[k] = Adventure::room(v)
					end
				else
					raise "Bad type for #{self.class}#direction #{params.type}"
			end
		end
	end

	# Represents a game player
	class Player
		def initialize(name, start)
			@name = name
			@current_room = Adventure::room(start)
			@items = []
		end

		attr_reader :current_room
		attr_accessor :name

		def go(room=nil)
			return 'Go where?' unless room
			case room
				when Adventure::Room
					@current_room = room
				else
					old_room = @current_room
					@current_room = @current_room[resolve(room)]
					return "No way to go #{room}." if old_room == @current_room
			end
			@current_room
		end

		[:north, :south, :east, :west, :northeast, :nortwest, :southeast, :southwest, :up, :down].each do |d|
			define_method(d) { go d }
		end

		def look(at=nil)
			if at
				return has_item?(at) || @current_room.has_item?(at)
			else
				return @current_room
			end
		end

		def get(id)
			item = @current_room.get_item(id)
			if item
				get_item(item)
				return "You got #{item.name.to_s.gsub(/_/,' ')}."
			else
				return "There is no #{id.to_s.gsub(/_/, ' ')} here."
			end
		end

		def drop(id)
			if i = has_item?(id)
				@items.delete(i)
				room(@current_room) {
					item i
				}
				return "Dropped #{i.name}."
			else
				return "You don't have a #{id}."
			end
		end

		def inventory
			"You are carrying:\n" + (@items.length > 0 ? @items.join("\n") : 'Nothing')
		end

		def has_item?(name)
			case name
				when Adventure::Item
					return @items.includes?(name)
				else
					name = Adventure::resolve(name)
					@items.each do |item|
						return item if item === name
					end
			end
			false
		end

		def method_missing(id, args)
			if has_item?id
				return "Do what with '#{id}'?"
			end
			"I don't understand '#{id}'"
		end

		def to_s
			"#{@name} currently at #{@current_room.name}"
		end

		private

		def get_item(item)
			@items << item
		end
	end

	# Hold data about term resolution
	class Terms
		@@synonyms = {
			:n   => :north,
			:s   => :south,
			:e   => :east,
			:w   => :west,
			:ne  => :northeast,
			:nw  => :northwest,
			:se  => :southeast,
			:sw  => :southwest,
			:u   => :up,
			:d   => :down,
			:inv => :inventory
		}
		@@items = @@synonyms.values.uniq
		@@stopwords = ['at', 'with', 'on']

		def self.synonyms
			@@synonyms
		end

		def self.add_synonym(synonym, of)
			@@synonyms[synonym.to_s.downcase.to_sym] = of.to_s.downcase.to_sym
		end

		def self.stopwords
			@@stopwords
		end
	end

	# A game item
	class Item
		def initialize(name, description, synonyms)
			@name = Adventure::resolve(name)
			@description = description
			synonyms.each do |synonym|
				Adventure::Terms::add_synonym(synonym, @name)
			end
		end

		def name
			@name.to_s.gsub(/_/, ' ')
		end

		def ===(v)
			self == v || @name == Adventure::resolve(v)
		end

		def to_s
			"#{name}: #{@description}"
		end
	end

	# Send commands to a player
	def player(id=nil, params=nil)
		if params.nil?
			params = id
			id = @player
		end

		return id unless params

		if params[:start]
			return 'That player has already started.' if id.is_a?Adventure::Player
			if id
				id = Adventure::Player.new(id, params[:start])
			else
				id = Adventure::Player.new('Player 1', params[:start])
				@player = id
			end
			params.delete :start
		end

		unless id
			raise "You must start a player with player :start before you can send commands."
		end

		rtrn = []
		params.each do |k, v|
			next unless k
			begin
				rtrn << id.send(k.to_sym, *v)
			rescue Exception
				rtrn << "I don't understand what you said, sorry."
			end
		end

		return rtrn.first if rtrn.length < 2
		rtrn
	end

	# Create or modify a room
	@@rooms = {}
	def room(name, description='', &block)
		r = case name
			when Adventure::Room
				name
			else
				name = Adventure::resolve(name)
				@@rooms[name] ||= Adventure::Room.new(name, description)
		end
		r.instance_eval(&block || lambda {})
		r
	end

	# Define new commands
	@@commands = {}
	def command(cmd, synonyms=[], meta={}, &block)
		cmd = Adventure::resolve(cmd)
		return @@commands[cmd] if @@commands[cmd]
		synonyms.each do |synonym|
			Adventure::Terms::add_synonym(synonym, cmd)
		end
		@@commands[cmd] = meta
		if block
			Adventure::Player.class_eval {
				define_method(cmd, block)
			}
		end
	end

	# Create an item
	def item(name, description, synonyms=[])
		Adventure::Item.new(name, description, synonyms)
	end

	# Turn on auto-printing of directions
	def show_directions
		Adventure::Room::show_directions
	end

	# Term resolution
	def resolve(term)
		return nil unless term
		term = term.to_s.downcase.gsub(/\s+/, '_').to_sym
		Adventure::Terms::synonyms[term] || term
	end

	# Command parsing
	def parse(command)
		command = command.chomp.split(/\s+/)
		Adventure::Terms::stopwords.each do |word|
			command.delete(word)
		end
		verb = resolve(command.shift)
		direct_object = resolve(command.shift)
		indirect_objects = []
		command.each do |i|
			indirect_objects << resolve(i)
		end
		[verb, direct_object, indirect_objects]
	end

end

include Adventure
