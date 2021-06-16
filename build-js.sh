set -e
set -x

rm -r jsbuild/
zip -9 -r fortris.love assets/ resources/ src/ jumper/ bitop/ main.lua conf.lua
love.js -t fortris fortris.love jsbuild/

if [ "$1" == "--publish" ]
then
  if [ -d docs/ ]
  then
    rm -r docs/
  fi
  mkdir docs/
  cp -r jsbuild/* docs/
  rm docs/theme/bg.png
  echo "Now commit and push on main branch to publish to github pages."
fi