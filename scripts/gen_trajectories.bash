#! /usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail
set -o errtrace

nth_angle() {
  local count="$1"
  local n="$2"

  bc -l <<< "180 / ($count - 1) * $n"
}

y_offset() {
  local a="$1"
  local distance="$2"

  if (( a <= 90 )); then
    bc -l <<< "$distance * -s ($a)"
  else
    a=$(( 180 - a ))
    bc -l <<< "-$distance * -s ($a)"
  fi
}

x_offset() {
  local a="$1"
  local distance="$2"

  if (( a <= 90 )); then
    bc -l <<< "$distance * -c ($a)"
  else
    a=$(( 180 - a ))
    bc -l <<< "-$distance * -c ($a)"
  fi
}

distance=$1
segments=$2

# segments=$(( segments / 2 ))

for (( i = 0; i < segments; i++ )); do
  a="$( nth_angle "$segments" "$i" )"

  y=$( y_offset "$a" "$distance")
  x=$( x_offset "$a" "$distance")

  printf "[%02d] %.0f / %.1f, %.1f\n" "$i" "$a" "$x" "$y"
done

