set -e

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

  if ! [ -z "$(git status -s | grep '^ ')" ]
  then
    echo "unstaged changes are present. Cannot commit."
    exit 1
  fi

  if ! [ -d "docs/" ]
  then
    mkdir docs/
  fi
  if ! [ -d "docs/$version" ]
  then
    mkdir "docs/$version"
    cp -r jsbuild/* docs/$version/
  else
    echo ""
    echo "error: $version already published."
    echo "rm -r docs/$version to replace"
    exit 1
  fi
  cp -r jsbuild/* docs/

  git add docs/
  git commit -m "publish $version"
fi