#!/usr/bin/ruby

# Basic example using "Adventure" DSL
# Define rooms (locations), commands, and items
# Start the player somewhere
# There are some default commands: go, get, drop
require 'adventure'

# This is for the ref(:id) syntax
require 'extern'

# This tells the DSL to print the different ways a player can go.
show_directions

# Make us a river! There's a pebble there, you can call it a pebble or just pebble.
@river = room('A river', 'A peaceful river.') {
	item :a_pebble, 'A small, smooth stone.', [:pebble]
	direction :north => ref(:hill)
	direction :west => ref(:lake)
}

# Make us a hill! The only thing you can do is go south to the river.
@hill = room('A hill', 'On top of a hill.') {
	direction :south => ref(:river)
}

# Make us a lake! There's food and a knife here... not too exciting.
@lake = room('The lake', 'Isn\'t this lake awesome!') {
	direction :east => ref(:river)
	direction :north => ref(:hill)
	item :food, 'Some food.'
	item :a_knife, 'A sharp knife.', [:knife]
}

# This is the most complicated command.
# You can hit the pebble, but only if you have it.
command(:hit, [:strike]) { |item|
	if item
		if item == :a_pebble
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

# Start the player at the river.
player :start => ref(:river)

# Game interface. Just do the traditional text-based interface.

puts
puts player.current_room

catch :quit do
	loop do
		puts
		verb, direct_object, indirect_objects = parse gets
		puts
		throw :quit if verb == :quit
		throw :quit if verb == :exit
		puts player(verb => direct_object)
	end
end

puts 'Thanks for playing!'
