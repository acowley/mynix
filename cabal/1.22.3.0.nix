{stdenv, fetchurl, ghc, curl, which, cacert}:

stdenv.mkDerivation rec {
  version = "1.22.3.0";
  name = "cabal-install-${version}";
  src = fetchurl {
          url = "http://hackage.haskell.org/package/cabal-install-${version}/cabal-install-${version}.tar.gz";
          sha256 = "28554eb6875ef54ee27edd1ec2272d7be58bf670504faec19838a8a5a0f88b4c";
        };
  buildInputs = [stdenv.cc ghc curl which cacert];
  CURL_CA_BUNDLE="${cacert}/etc/ca-bundle.crt";
  LD="${stdenv.cc}/bin/ld";
  PLAT= if stdenv.isDarwin then
          "x86_64-osx"
        else throw "Only Darwin is supported so far";
  builder = builtins.toFile "builder.sh" ''
    source $stdenv/setup
    mkdir $out
    tar xf "$src" --strip=1

    # Make our own sandbox
    export DBPATH="$out/.cabal-sandbox/$PLAT-ghc-$(ghc --numeric-version)-packages.conf.d"
    ghc-pkg init "$DBPATH"
    export SCOPE_OF_INSTALLATION="--package-db=$DBPATH"
    # Remove the bootstrap program's ld detection
    sed -e 's/LD=\$LINK//' bootstrap.sh > bootstrap2.sh
    chmod u+x bootstrap2.sh
    PREFIX=$out ./bootstrap2.sh
  '';
  meta.license = stdenv.lib.licenses.bsd3;
  meta.platforms = [ "x86_64-linux" "i686-linux" "x86_64-darwin" ];
}

