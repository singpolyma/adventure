#!/usr/bin/ruby

require 'eventmachine'
require 'adventure'

# This tells the DSL to print the different ways a player can go.
show_directions

# Make us a river! There's a pebble there, you can call it a pebble or just pebble.
room(:a_river, 'A peaceful river.') {
	item :a_pebble, 'A small, smooth stone.', [:pebble]
	direction :north => :a_hill
	direction :west => :the_lake
}

# Make us a hill! The only thing you can do is go south to the river.
room(:a_hill, 'On top of a hill.') {
	direction :south => :a_river
}

# Make us a lake! There's food and a knife here... not too exciting.
room(:the_lake, 'Isn\'t this lake awesome!') {
	direction :east => :a_river
	direction :north => :a_hill
	item :food, 'Some food.'
	item :a_knife, 'A sharp knife.', [:knife]
}

# This is the most complicated command.
# You can hit the pebble, but only if you have it.
command(:hit, [:strike]) { |item|
	if item
		if item === :a_pebble
			if has_item?:a_pebble
				drop(:a_pebble)
				room(current_room) {
					get_item :a_pebble
				}
				'The pebble vanishes.'
			else
				'You do not have a pebble.'
			end
		else
			'You can\t hit that.'
		end
	else
		'Hit what?'
	end
}

# We can make silly commands too.
command(:sing) {
	'You sing a little song.'
}

# The not-so-useful help
command(:help) {
	if has_item?:a_pebble
		'What? Lost? Try hitting the pebble.'
	else
		'Is the pebble gone? Because there\'s really nothing else.'
	end
}

command(:say, [:talk], :broadcast => lambda {|*args| args.join(' ')}) { |*args|
	nil
}

command(:look, [], :broadcast => false)

# Basic telnet interface

$connections = []

class Adventure::Room
	alias to_s_old to_s
	def to_s
		people = $connections.map {|c| c.player.name}.join(', ')
		to_s_old + "\nPeople here: #{people}"
	end
end

class AdventureServer < EventMachine::Connection

	attr_reader :player

	def post_init
		@buffer = ''
		@player = Adventure::Player.new('Anonymous', :a_river)
		send_data("What is your name?\r\n")
	end

	def broadcast(msg, room=nil)
		$connections.each do |conn|
			next if conn == self
			if room
				next unless conn.player.current_room === room
			end
			conn.send_data("#{@player.name}: #{msg}\r\n\r\n")
		end
	end

	def do_broadcast(verb, objects, second=false)
		unless !command(verb) || (bcst = command(verb)[:broadcast]).nil?
			return unless bcst
			room = command(verb)[:visibility] == :global ? nil : player.current_room
			return if second && room
			broadcast(bcst.call(*objects), room)
		else
			broadcast(@buffer, player.current_room)
		end
	end

	def receive_data(data)
		data.force_encoding('binary').each_char { |c| # Make no assumptions about the data
			@buffer += c
			if @buffer[-2..-1] == "\r\n" # Commands are only one line
				@buffer.chomp!

				if @player.name == 'Anonymous'
					@player.name = @buffer
					$connections << self
					send_data("\r\n" + @player.current_room.to_s + "\r\n\r\n")
					broadcast('has joined')
				else
					verb, direct_object, indirect_objects = parse(@buffer)

					if verb == :quit || verb == :exit
						broadcast('quit')
						close_connection
					else
						objects = ([direct_object] + indirect_objects).compact
						do_broadcast(verb, objects)

						old_room = player.current_room
						rtrn = Adventure::player(player, verb => objects)
						if old_room != player.current_room
							do_broadcast(verb, objects, true)
						end

						send_data("\r\n" + rtrn.to_s + "\r\n\r\n") unless rtrn.nil?
					end
				end

				@buffer = ''
			end
		}
	end

end

EM::run {
	EventMachine::start_server '::', 4611, AdventureServer
}
