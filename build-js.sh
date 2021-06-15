set -e
set -x

rm -r jsbuild/
zip -9 -r fortris.love assets/ resources/ src/ jumper/ bitop/ main.lua conf.lua
love.js -t fortris fortris.love jsbuild/

