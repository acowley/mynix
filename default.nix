with import <nixpkgs> {};
rec {
  ghc = rec {
    "7.8.4-binary" = import ghc/7.8.4-binary.nix;
  };
  "cabal-install" = {
    "1.20.0.6" = import cabal/1.20.0.6.nix;
  };
  ghcDefault = callPackage ghc."7.8.4-binary" { libiconv = darwin.libiconv; };
  cabalDefault = callPackage cabal-install."1.20.0.6" { ghc = ghcDefault; };
}
