set -e
set -x

if [ -d jsbuild ]
then
  rm -r jsbuild/
fi

zip -9 -r fortris.love assets/ resources/ src/ jumper/ bitop/ ext/ love.js/ main.lua conf.lua

# build in compatability mode
love.js -c -t fortris fortris.love jsbuild/

# add love-js ffi
  sed -i 's/<title>/<script src = "consolewrapper.js"><\/script>\n    <title>/' jsbuild/index.html
  cp ljsap/*.js jsbuild/

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