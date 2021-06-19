set -e
set -x

if [ -d jsbuild ]
then
  rm -r jsbuild/
fi

zip -9 -r fortris.love assets/ resources/ src/ jumper/ bitop/ ext/ main.lua conf.lua
#build in normal mode
love.js -t fortris fortris.love jsbuild/
# build again in compatability mode
love.js -c -t fortris fortris.love jsbuild/firefox/

if [ "$1" == "--publish" ]
then
  if [ -d docs/ ]
  then
    rm -r docs/
  fi
  mkdir docs/
  cp -r jsbuild/* docs/
  rm docs/theme/bg.png
  rm docs/firefox/theme/bg.png
  echo "Now commit and push on main branch to publish to github pages."
fi