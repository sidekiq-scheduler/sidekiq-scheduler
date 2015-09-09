#!/bin/bash

# tarFileName='ruy-page.tar'

rm -rf build
# rm $tarFileName


mkdir build

grunt precompile
./node_modules/jade/bin/jade.js views/home/index.jade --out ./build/ --pretty

cp -r public/* build/

rm -rf ../dist ../fonts ../images ../index.html

cp -r build/* ../

cd ../

echo 'Successfully built .'

git add . --all
git commit -m 'Deploy build.'
git push origin gh-pages

# tar czf $tarFileName ./build