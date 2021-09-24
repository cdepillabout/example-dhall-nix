
let
  nixpkgsSrc = builtins.fetchTarball {
    # nixos-unstable as of 2021-09-16.
    url = "https://github.com/NixOS/nixpkgs/archive/bcd607489d76795508c48261e1ad05f5d4b7672f.tar.gz";
    sha256 = "0yjp9lrhzvyh9dc4b9dl456fr6nlchfmn85adq0vi4pnwfmh90z6";
  };
in

with import nixpkgsSrc {};

let

  fetchDhallUrl =
    { url, hash, dhall-hash }:
    runCommand
      (baseNameOf url)
      {
        outputHashAlgo = null;
        outputHash = hash;
        name = baseNameOf url;
        nativeBuildInputs = [ cacert ];
      }
      ''
        echo "${url} ${dhall-hash}" > in-dhall-file
        ${dhall}/bin/dhall --alpha --plain --file in-dhall-file | ${dhall}/bin/dhall encode > $out
      '';

  buildDhallUrl =
    { url, hash, dhall-hash }:
    let
      # file = writeText "${name}.dhall" code;

      cache = ".cache";

      data = ".local/share";

      cacheDhall = "${cache}/dhall";

      dataDhall = "${data}/dhall";

      sourceFile = "source.dhall";

    in
    runCommand
      (baseNameOf url)
      {
        outputHashAlgo = null;
        outputHash = hash;
        name = baseNameOf url;
        nativeBuildInputs = [ cacert ];
      }
      # ''
      #   mkdir -p ${cacheDhall}

      #   export XDG_CACHE_HOME=$PWD/${cache}

      #   mkdir -p $out/${cacheDhall}

      #   ${dhall}/bin/dhall --alpha --plain --file '${file}' > $out/${sourceFile}

      #   SHA_HASH=$(${dhallNoHTTP}/bin/dhall hash <<< $out/${sourceFile})

      #   HASH_FILE="''${SHA_HASH/sha256:/1220}"

      #   ${dhallNoHTTP}/bin/dhall encode --file $out/${sourceFile} > $out/${cacheDhall}/$HASH_FILE

      #   echo "missing $SHA_HASH" > $out/binary.dhall
      # '';
      ''
        echo "${url} ${dhall-hash}" > in-dhall-file
        ${dhall}/bin/dhall --alpha --plain --file in-dhall-file | ${dhall}/bin/dhall encode > $out
      '';

  myFODDhallFile = buildDhallUrl {
    url = "https://raw.githubusercontent.com/cdepillabout/example-dhall-repo/c1b0d0327146648dcf8de997b2aa32758f2ed735/example1.dhall";
    hash = "sha256-ZTSiQUXpPbPfPvS8OeK6dDQE6j6NbP27ho1cg9YfENI=";
    dhall-hash = "sha256:6534a24145e93db3df3ef4bc39e2ba743404ea3e8d6cfdbb868d5c83d61f10d2";
  };

  myDhallPackage =
    # { buildDhallDirectoryPackage }:
    dhallPackages.buildDhallDirectoryPackage {
      name = "mydhallfile";
      src = ./.;
      file = "./mydhallfile.dhall";
      source = false;
      document = false;
      dependencies = [
        myFODDhallFile
        # (buildDhallUrl {
        #   url = "https://raw.githubusercontent.com/dhall-lang/dhall-lang/9758483fcf20baf270dda5eceb10535d0c0aa5a8/Prelude/List/map.dhall";
        #   hash = "sha256-3YRf+0Vo1AMn8qgX60LRxhOLkpynWNULwzES7zyIVoA=";
        # })

        # ((fetchurl {
        #     url = "https://gist.githubusercontent.com/cdepillabout/2683131f078753fd24723ab8bf1e1b74/raw/7e1b26ff812000e868a4ff108b33a21d03a9a591/example-normal.dhall";
        #     hash = "sha256-FfUuz5HJTBuqwC1aSWSy7Y+kAWQaLIqV6DBux8HjuNI=";
        #     downloadToTemp = true;
        #     postFetch = "${dhall}/bin/dhall --alpha --plain --file \"\$downloadedFile\" | ${dhall}/bin/dhall encode > \$out";
        #   }).overrideAttrs (oldAttrs: {
        #     nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ cacert ];
        #   }))
        ];
      };

  # myDhallFile = dhallToNixUrlFOD {
  #   src = ./.;
  #   file = "mydhallfile.dhall";
  # };

in

# myDhallPackage

myFODDhallFile
