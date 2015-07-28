{stdenv, fetchurl, gmp, ncurses, perl, libiconv, llvm_35}:

stdenv.mkDerivation rec {
  version = "7.10.1";
  name = "ghc-${version}-binary";
  src = if stdenv.system == "x86_64-darwin" then 
          fetchurl { 
            url = "https://downloads.haskell.org/~ghc/7.10.1/ghc-7.10.1-x86_64-apple-darwin.tar.xz";
            sha256 = "bc45de19efc831f7d5a3fe608ba4ebcd24cc0f414cac4bc40ef88a04640583f6";
          }
        else throw "No binary GHC for this platform yet";

  buildInputs = [perl];
  propagatedBuildInputs = [llvm_35];

  # This is copied from the ghc-7.4.2-binary Nix expression
  postUnpack =
    stdenv.lib.optionalString stdenv.isDarwin ''
      export NIX_LDFLAGS+=" -no_dtrace_dof"
    '' +

    # Strip is harmful, see also below. It's important that this happens
    # first. The GHC Cabal build system makes use of strip by default and
    # has hardcoded paths to /usr/bin/strip in many places. We replace
    # those below, making them point to our dummy script.
     ''
      mkdir -p "$TMP/bin"
      for i in strip; do
        echo '#! ${stdenv.shell}' > "$TMP/bin/$i"
        chmod +x "$TMP/bin/$i"
      done
      PATH="$TMP/bin:$PATH"
     '' +
    # We have to patch the GMP paths for the integer-gmp package.
     ''
      find . -name integer-gmp.buildinfo \
          -exec sed -i "s@extra-lib-dirs: @extra-lib-dirs: ${gmp}/lib@" {} \;
     '' + stdenv.lib.optionalString stdenv.isDarwin ''
      find . -name base.buildinfo \
          -exec sed -i "s@extra-lib-dirs: @extra-lib-dirs: ${libiconv}/lib@" {} \;
     '' +
    # On Linux, use patchelf to modify the executables so that they can
    # find editline/gmp.
    stdenv.lib.optionalString stdenv.isLinux ''
      find . -type f -perm +100 \
          -exec patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
          --set-rpath "${ncurses}/lib:${gmp}/lib" {} \;
      sed -i "s|/usr/bin/perl|perl\x00        |" ghc-${version}/ghc/stage2/build/tmp/ghc-stage2
      sed -i "s|/usr/bin/gcc|gcc\x00        |" ghc-${version}/ghc/stage2/build/tmp/ghc-stage2
      for prog in ld ar gcc strip ranlib; do
        find . -name "setup-config" -exec sed -i "s@/usr/bin/$prog@$(type -p $prog)@g" {} \;
      done
     '' + stdenv.lib.optionalString stdenv.isDarwin ''
       # not enough room in the object files for the full path to libiconv :(
       fix () {
         #install_name_tool -change /usr/lib/libiconv.2.dylib @executable_path/libiconv.dylib $1
         install_name_tool -change /usr/lib/libiconv.2.dylib ${libiconv}/lib/libiconv.dylib $1
       }

       ln -s ${libiconv}/lib/libiconv.dylib ghc-${version}/utils/ghc-pwd/dist-install/build/tmp
       ln -s ${libiconv}/lib/libiconv.dylib ghc-${version}/utils/hpc/dist-install/build/tmp
       ln -s ${libiconv}/lib/libiconv.dylib ghc-${version}/ghc/stage2/build/tmp

       for file in ghc-cabal ghc-pwd ghc-stage2 ghc-pkg haddock hsc2hs hpc; do
         fix $(find . -type f -name $file)
       done
     '';

  configurePhase = ''
    LDFLAGS=-L${libiconv}/lib LlcCmd=${llvm_35}/bin/llc OptCmd=${llvm_35}/bin/opt ./configure --prefix=$out \
      --with-gmp-libraries=${gmp}/lib --with-gmp-includes=${gmp}/include \
      ${stdenv.lib.optionalString stdenv.isDarwin "--with-gcc=$CC"} \
  '';

  # Stripping combined with patchelf breaks the executables (they die
  # with a segfault or the kernel even refuses the execve). (NIXPKGS-85)
  dontStrip = true;

  # No building is necessary, but calling make without flags ironically
  # calls install-strip ...
  buildPhase = "true";

  preInstall = stdenv.lib.optionalString stdenv.isDarwin ''
    mkdir -p $out/lib/ghc-${version}
    mkdir -p $out/bin
    # ln -s ${libiconv}/lib/libiconv.dylib $out/bin
    # ln -s ${libiconv}/lib/libiconv.dylib $out/lib/ghc-${version}/libiconv.dylib
    # ln -s ${libiconv}/lib/libiconv.dylib utils/ghc-cabal/dist-install/build/tmp
  '';

  postInstall = ''
    # Sanity check, can ghc create executables?
    cd $TMP
    mkdir test-ghc; cd test-ghc
    cat > main.hs << EOF
      {-# LANGUAGE TemplateHaskell #-}
      module Main where
      main = putStrLn \$([|"yes"|])
    EOF
    $out/bin/ghc --make main.hs || exit 1
    echo compilation ok
    [ $(./main) == "yes" ]
  '';

  meta.license = stdenv.lib.licenses.bsd3;
  meta.platforms = ["x86_64-linux" "i686-linux" "x86_64-darwin"];
}
