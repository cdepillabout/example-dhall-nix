
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
      dhallNoHTTP = haskell.lib.appendConfigureFlag dhall "-f-with-http";

      cache = ".cache";

      data = ".local/share";

      cacheDhall = "${cache}/dhall";

      dataDhall = "${data}/dhall";

      sourceFile = "source.dhall";

      downloadedEncodedFile =
        runCommand
          (baseNameOf url + "-encoded")
          {
            outputHashAlgo = null;
            outputHash = hash;
            name = baseNameOf url;
            nativeBuildInputs = [ cacert ];
          }
          ''
            echo "${url} ${dhall-hash}" > in-dhall-file
            ${dhall}/bin/dhall --alpha --plain --file in-dhall-file | ${dhallNoHTTP}/bin/dhall encode > $out
          '';

      fileWithCache =
        runCommand
          (baseNameOf url + "-cache")
          { }
          # TODO: Optionally delete the source file.  Also add an option for producing documentation.
          # Also, we can probably create the cache file directly without explicitly encoding the source
          # file again.  We can probably create the binary.dhall file directly, since the buildDhallUrl
          # function already knows the hash.
          ''
            set -x
            mkdir -p ${cacheDhall}

            export XDG_CACHE_HOME=$PWD/${cache}

            mkdir -p $out/${cacheDhall}

            ${dhallNoHTTP}/bin/dhall decode --file ${downloadedEncodedFile} > $out/${sourceFile}

            SHA_HASH=$(${dhallNoHTTP}/bin/dhall hash <<< $out/${sourceFile})

            echo $SHA_HASH

            HASH_FILE="''${SHA_HASH/sha256:/1220}"

            echo $HASH_FILE

            ${dhallNoHTTP}/bin/dhall encode --file $out/${sourceFile} > $out/${cacheDhall}/$HASH_FILE

            echo "missing $SHA_HASH" > $out/binary.dhall
          '';

    in

      fileWithCache;

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
      ];
    };

  # myDhallFile = dhallToNixUrlFOD {
  #   src = ./.;
  #   file = "mydhallfile.dhall";
  # };

in

# myDhallPackage

myFODDhallFile
