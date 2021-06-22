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

# remove background
rm jsbuild/theme/bg.png

# get version number
version=`grep "k_version =" main.lua | sed 's/k_version = "Fortris //' | sed 's/"//g'`

if [ "$1" == "--publish" ]
then
  if ! [ -d "docs/" ]
  then
    mkdir docs/
  fi
  if ! [ -d "docs/$version" ]
  then
    mkdir "docs/$version"
  fi
  cp -r jsbuild/* docs/
  cp -r jsbuild/* docs/$version/

  echo "Now commit and push on main branch to publish to github pages."
fi