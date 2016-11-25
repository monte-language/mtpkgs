let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;

  typhonGit = pkgs.fetchFromGitHub {
    owner = "monte-language";
    repo = "typhon";
    rev = "a0b3c96";
    sha256 = "0082ww4wg334ndmihc6vcxll2bf2hwn8brlgf3hrnr6x81yj7kwk";
  };
  typhon = import typhonGit {};

  callPackage = pkgs.newScope self;
  self = rec {
    makeMontePackage = src: let
      lockSet = builtins.fromJSON (builtins.readFile "${src}/mt-lock.json");
      montePackage = pkgs.callPackage "${typhon.monte}/nix-support/montePackage.nix" {
        typhonVm = typhon.typhonVm;
        mast = typhon.mast;
      };
    in montePackage lockSet;

    mtFromGitHub = s: makeMontePackage (pkgs.fetchFromGitHub s);

    airbrus = mtFromGitHub {
      owner = "MostAwesomeDude";
      repo = "airbrus";
      rev = "6e9bcee";
      sha256 = "1r1p03r66zxf59c5q7w6rrpll819vk7hz9sn40v0k8hnmvyip1w8";
    };
  };
in self
