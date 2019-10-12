#! /usr/bin/env ruby

class Trajectory
  def initialize(angle, count)
    @angle = angle.to_i
    @count = count.to_i
  end

  def nth_angle(n)
    @angle / (@count.to_f - 1) * n.to_f
  end

  def angles
    (0...@count).map do |i|
      self.nth_angle i.to_f
    end
  end

  def self.offset_for(angle, distance)
    # convert degrees to radians
    angle = (angle.to_f / 360) * 2 * Math::PI

    # calculate the deltas
    dx = distance * Math.cos(angle)
    dy = distance * Math.sin(angle)

    # flip the sign for dx since we want 0 to be 9 o'clock
    # flip the sign for dy since 0,0 is the upper left, not lower-left.
    Offset.new(-dx, -dy)
  end

  # calculate the trajectory, starting from the origin
  # with an offset
  # this will output an array of integers
  def trajectory_for_angle(angle, offset, distance)
    starting_point_offset = Trajectory.offset_for(angle, offset)
    offset = Trajectory.offset_for(angle, distance)

    # now let's collect points until we're offscreen
    starting_x = ORIGIN_X + starting_point_offset.dx
    starting_y = ORIGIN_Y + starting_point_offset.dy

    warn "Starting point: #{starting_x}, #{starting_y}"

    p = Point.new(starting_x, starting_y)

    points = []

    16.times do
      points << p.dup
      p.offset_by(offset)
    end
    # calculate all of the points
    # until p.offscreen? do
      # points << p.dup
      # p.offset_by(offset)
    # end

    points.map do |p|
      p.to_ituple
    end
    # points
  end
end

class Point
  def initialize(x, y)
    @x = x
    @y = y

    @original_x = x
    @original_y = y
  end

  def offset_by(offset)
    @x += offset.dx
    @y += offset.dy
  end

  def offscreen?
    @x < 0 || @y < 0 || @x > MAX_X || @y > MAX_Y
  end

  def to_tuple
    [@x, @y]
  end

  def to_ituple
    [ @x.to_i, @y.to_i ]
  end

  def to_s
    "(#{@x}, #{@y})"
  end
end

class Offset
  attr_reader :dx, :dy

  def initialize(dx, dy)
    @dx = dx
    @dy = dy
  end

  def swap
    old_dx = @dx
    @dx = @dy
    @dy = old_dx
  end
end

def dedup_stream(stream, final_size)
  pattern = []
  # warn "stream length: #{stream.length}"

  stream.each do |s|
    pattern << s
    # warn "Current pattern: #{pattern.inspect}"

    # how many repetitions
    new_array = []
    while new_array.length < stream.length do
      new_array = new_array.concat(pattern)
    end

    new_array = new_array.slice(0, stream.length)

    # warn "Comparing: #{new_array.inspect}"

    if new_array == stream
      return new_array.slice(0, final_size)
    end
  end
end

def point_to_asm_byte(point)
  x, y = point

  new_x = x.abs
  new_y = y.abs

  if x < 0
    new_x |= 0b1000
  end

  if y < 0
    new_y |= 0b1000
  end

  (new_x << 4) | new_y
end

ANGLE = 180
DISTANCE = 3
SEGMENTS = 32

# origin of turret
ORIGIN_X = 125
ORIGIN_Y = 180

# min/max values to figure out when we are ending
MIN_X = 0
MIN_Y = 0
MAX_X = 249
MAX_Y = 239

# number of frames of animation we want to store
ANIM_SIZE = 8

t = Trajectory.new(ANGLE, SEGMENTS)

reticle_positions = []
shot_animation_frames = []

t.angles.each_with_index do |angle, index|
  offsets = t.trajectory_for_angle(angle, 16, DISTANCE)

  first = offsets.shift
  results = offsets.reduce({:acc => [], :memo => first}) do |acc, offset|
    acc[:acc] << [ offset.first - acc[:memo].first, offset.last - acc[:memo].last ]

    acc[:memo] = offset

    acc
  end

  results = results[:acc]
  warn "Angle: #{angle}"
  dedup_results = dedup_stream(results, ANIM_SIZE)
  warn "[#{dedup_results.length}] #{dedup_results.inspect}"
  warn ""

  reticle_positions << first
  shot_animation_frames << dedup_results
end

puts "turret_reticle_x:"
puts "  .byte #{reticle_positions.map { |p| p.first.to_s(16) }.map { |p| "$#{p}" }.join(", ") }"
puts "turret_reticle_y:"
puts "  .byte #{reticle_positions.map { |p| p.last.to_s(16) }.map { |p| "$#{p}" }.join(", ") }"

puts ""

shot_animation_frames.each_with_index do |offsets, index|
  asm_frames =
    offsets
      .map { |point| point_to_asm_byte(point).to_s(16) }
      .map { |point| "$#{point.rjust(2, '0')}"}
      .join(', ')
  puts "shot_anim_frames_#{index}:"
  # puts "  ; #{offsets.inspect}"
  puts "  .byte #{asm_frames}"
end

# reduce

# 1 2 2 2 1 2 2 2 1 2 2 2
# best guess: 1 2 2 2

# t.angles.each do |a|
  # # t = Trajectory.offset_for(a, DISTANCE)

  # p t.trajectory_for_angle(a, 10, DISTANCE)
# end

