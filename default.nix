let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;
  lib = pkgs.lib;

  typhonGit = pkgs.fetchFromGitHub {
    owner = "monte-language";
    repo = "typhon";
    rev = "e87524f";
    sha256 = "0nswbi64jgn02gjrl8had7gprvg99gmk8m9xw8mqkylxam22gal1";
  };
  typhon = import typhonGit {};

  callPackage = pkgs.newScope self;
  self = rec {
    inherit lib;

    makeMontePackage = src: let
      typhonVm = typhon.typhonVm;
      mast = typhon.mast;

      json = builtins.fromJSON (builtins.readFile "${src}/mt.json");
      name = json.name;
      paths = json.paths;
      hasEntrypoint = json ? entrypoint;
      entrypoint = if hasEntrypoint then json.entrypoint else "";
      entrypointBin = baseNameOf entrypoint;
      dependencies = lib.attrNames json.dependencies;

      filteredSrc = if builtins.elem "." paths
        then src
        else builtins.filterSource (path: type:
          lib.any (p: lib.hasPrefix p path) paths) src;

      # We tie the knot here, but we'll need to collect the dependency search
      # paths. We emit and read an $out/nix-support/setup-hook script via
      # setupHook, which exports the dependent paths into $MONTE_PATH.
      propagatedBuildInputs = map (d: self.${d}) dependencies;
      dependencySearchPaths = lib.concatStringsSep " "
        (map (x: "-l ${x}") propagatedBuildInputs);
    in stdenv.mkDerivation {
      inherit name propagatedBuildInputs;

      src = filteredSrc;

      setupHook = ./monte-setup-hook.sh;
      montePaths = dependencySearchPaths;

      buildInputs = [ typhonVm mast ];
      buildPhase = ''
        for srcP in ${lib.concatStringsSep " " paths}; do
          for srcF in $(find ./$srcP -name \*.mt); do
            destF=''${srcF%%.mt}.mast
            ${typhonVm}/mt-typhon -l ${mast}/mast ${mast}/loader run montec -mix $srcF $destF
            fail=$?
            if [ $fail -ne 0 ]; then
              exit $fail
            fi
          done
        done
      '';

      doCheck = hasEntrypoint;
      checkPhase = ''
        ${typhonVm}/mt-typhon ${dependencySearchPaths} -l ${mast}/mast -l . ${mast}/loader test ${entrypointBin}
      '';

      installPhase = ''
      mkdir -p $out
      for p in ${lib.concatStringsSep " " paths}; do
        cp -r $p $out/$p
      done
      '' + (if hasEntrypoint then ''
        mkdir -p $out/bin
        tee $out/bin/${entrypointBin} <<EOF
        #!${pkgs.stdenv.shell}
        case \$1 in
          --test)
            shift
            OPERATION=test
            ;;
          --bench)
            shift
            OPERATION=bench
            ;;
          --dot)
            shift
            OPERATION=dot
            ;;
          --run)
            shift
            OPERATION=run
            ;;
          *)
            OPERATION=run
            ;;
        esac
        LOCALPKGPATHS="$MONTE_PATH "
        for p in ${lib.concatStringsSep " " paths}; do
          LOCALPKGPATHS+=" -l $out/$p"
        done
        ${typhonVm}/mt-typhon ${dependencySearchPaths} \$LOCALPKGPATHS -l ${mast}/mast ${mast}/loader \$OPERATION ${entrypoint} "\$@"
        EOF
        chmod +x $out/bin/${entrypointBin}
        '' else "");
    };

    mtFromGitHub = s: makeMontePackage (pkgs.fetchFromGitHub s);

    airbrus = mtFromGitHub {
      owner = "MostAwesomeDude";
      repo = "airbrus";
      rev = "6e9bcee";
      sha256 = "1r1p03r66zxf59c5q7w6rrpll819vk7hz9sn40v0k8hnmvyip1w8";
    };

    IRC = mtFromGitHub {
      owner = "monte-language";
      repo = "mt-irc";
      rev = "3657b6e";
      sha256 = "1gy7fh237s8lfpy582q9ijgark9ybrb0ljwx38cknr13y0k2yj3r";
    };

    loopingCall = mtFromGitHub {
      owner = "monte-language";
      repo = "mt-loopingCall";
      rev = "2c362d6";
      sha256 = "142rg4r12z96mvpv4yimwz82ggvfym0lf315wrg44k280mrwp2bz";
    };

    tokenBucket = mtFromGitHub {
      owner = "monte-language";
      repo = "mt-tokenBucket";
      rev = "d286a6c";
      sha256 = "05c07fyn9zqj8gm9jacpzjmmfzvjhs582jplcapds85r4hcv41zl";
    };
  };
in self
