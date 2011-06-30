#!/usr/bin/ruby

# Basic example using "Adventure" DSL
# Define rooms (locations), commands, and items
# Start the player somewhere
# There are some default commands: go, get, drop
require 'adventure'

# This tells the DSL to print the different ways a player can go.
show_directions

# Make us a river! There's a pebble there, you can call it a pebble or just pebble.
room(:a_river, 'A peaceful river.') {
	item :a_pebble, 'A small, smooth stone.', [:pebble] {
		# You can hit the pebble, but only if you have it.
		command(:hit) {
			if player.has_item?(self)

				# Drop and then "get" to nowhere makes it go away
				player.drop(self)
				room(player.current_room) {
					get_item(self)
				}

				'The pebble vanishes.'
			else
				'You do not have a pebble.'
			end
		}
	}
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

# This is just the catch-all for if you do not specify
# something to hit (or what you specify is not there)
# The synonym set up here will be applied globally
command(:hit, [:strike]) { |*args|
	'Hit what?'
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

# Start the player at the river.
player :start => :a_river

# Game interface. Just do the traditional text-based interface.

puts
puts player.current_room

catch :quit do
	loop do
		puts
		verb, objects = parse gets
		puts
		throw :quit if verb == :quit
		throw :quit if verb == :exit
		puts player(verb => objects)
	end
end

puts 'Thanks for playing!'
