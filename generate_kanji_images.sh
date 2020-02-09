#!/bin/bash

size_in_pixels=300
font=KanjiStrokeOrders-Medium
x_shift=10
y_shift=0

i=1
while read -r -n 1 kanji; do
    [[ $kanji ]] || continue
    filename="${i}_$kanji.png"
    echo -n "Creating $filename..."
    if convert -size ${size_in_pixels}x$size_in_pixels xc:white \
        -font "$font" \
        -gravity Center -pointsize "$(( size_in_pixels - 10 ))" \
        -draw "text ${x_shift},${y_shift} \"$kanji\"" "$filename"
    then
        echo 'done.'
    else
        echo 'failed!'
    fi
    (( ++i ))
done
