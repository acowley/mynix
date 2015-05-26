with import <nixpkgs> {};
rec {
  ghc = rec {
    "7.8.4-binary" = import ghc/7.8.4-binary.nix;
    "7.10.1-binary" = import ghc/7.10.1-binary.nix;
  };
  "cabal-install" = {
    "1.20.0.6" = import cabal/1.20.0.6.nix;
    "1.22.3.0" = import cabal/1.22.3.0.nix;
    "1.22.4.0" = import cabal/1.22.4.0.nix;
  };
  ghcDefault = callPackage ghc."7.10.1-binary" { libiconv = darwin.libiconv; };
  cabalDefault = callPackage cabal-install."1.22.4.0" { ghc = ghcDefault; };
}
