# This Nix file is a proof of concept for how some additional Dhall-related
# functions should look in Nixpkgs.
#
# This is specifically for https://github.com/dhall-lang/dhall-haskell/pull/2304.

let
  nixpkgsSrc = builtins.fetchTarball {
    # nixos-unstable as of 2021-09-16.
    url = "https://github.com/NixOS/nixpkgs/archive/bcd607489d76795508c48261e1ad05f5d4b7672f.tar.gz";
    sha256 = "0yjp9lrhzvyh9dc4b9dl456fr6nlchfmn85adq0vi4pnwfmh90z6";
  };
in

with import nixpkgsSrc {};

let

  # This is a helper function that gives an easy way to use Dhall's remote
  # importing capabilities for downloading a Dhall file.
  # The output Dhall file has all imports resolved, and then is
  # alpha-normalized and binary-encoded.
  #
  # This is used internally in the next function, buildDhallUrl.
  # fetchDhallUrl could just be defined internally in buildDhallUrl if we don't
  # want expose this functionality to end users.
  fetchDhallUrl =
    { # URL to have Dhall download.
      url
    , # Nix hash.
      hash
      # Dhall hash.
    , dhall-hash
    }:
    let
      dhallNoHTTP = haskell.lib.appendConfigureFlag dhall "-f-with-http";
    in
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
        ${dhall}/bin/dhall --alpha --plain --file in-dhall-file | ${dhallNoHTTP}/bin/dhall encode > $out
      '';

  # This is a function suggested in
  # https://github.com/dhall-lang/dhall-haskell/pull/2304#issuecomment-924597654.
  #
  # buildDhallUrl is similar to buildDhallDirectoryPackage or
  # buildDhallGitHubPackage, but instead builds a Nixpkgs Dhall package
  # based on a hashed URL.  This will generally be a URL that has an integrity
  # check in a Dhall file.
  #
  # Similar to buildDhallDirectoryPackage and buildDhallGitHubPackage, the output
  # of this function is a derivation that has a binary.dhall file, along with
  # a .cache/ directory with the actual contents of the Dhall file from the
  # suppiled URL.
  #
  # This function would need to be a new function in Nixpkgs.  This function
  # may make it easier to package arbitrary Dhall files in Nixpkgs.
  #
  # This function will be used by the new functionality added to
  # `dhall-to-nixpkgs --url-fod` in order to include arbitrary URLs as
  # dependencies.
  buildDhallUrl =
    { # URL of the input Dhall file.
      # example: https://raw.githubusercontent.com/cdepillabout/example-dhall-repo/c1b0d0327146648dcf8de997b2aa32758f2ed735/example1.dhall
      url
    , # Nix hash of the input Dhall file.
      # example: sha256-ZTSiQUXpPbPfPvS8OeK6dDQE6j6NbP27ho1cg9YfENI=
      hash
    , # Dhall hash of the input Dhall file.
      # example: sha256:6534a24145e93db3df3ef4bc39e2ba743404ea3e8d6cfdbb868d5c83d61f10d2
      # (TODO: I imagine it would be possible to programmatically compute a
      # Dhall-compatible hash given a Nix-compatible hash.  I didn't attempt
      # that here, so this function just takes both.  In practice, I imagine
      # most users won't write calls to buildDhallUrl by hand, but they will
      # instead by generated automatically by dhall-to-nixpkgs.)
      dhall-hash
    }@args:
    let
      dhallNoHTTP = haskell.lib.appendConfigureFlag dhall "-f-with-http";

      cache = ".cache";

      data = ".local/share";

      cacheDhall = "${cache}/dhall";

      dataDhall = "${data}/dhall";

      sourceFile = "source.dhall";

      downloadedEncodedFile = fetchDhallUrl args;

      fileWithCache =
        runCommand
          (baseNameOf url + "-cache")
          { }
          # TODO: Optionally delete the source file.  Also add an option for
          # producing documentation.
          #
          # TODO: We can probably create the cache file directly without
          # explicitly encoding the source file again.  We can probably create
          # the binary.dhall file directly, since the buildDhallUrl function
          # already knows the hash.
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
        (buildDhallUrl {
          url = "https://raw.githubusercontent.com/cdepillabout/example-dhall-repo/c1b0d0327146648dcf8de997b2aa32758f2ed735/example1.dhall";
          hash = "sha256-ZTSiQUXpPbPfPvS8OeK6dDQE6j6NbP27ho1cg9YfENI=";
          dhall-hash = "sha256:6534a24145e93db3df3ef4bc39e2ba743404ea3e8d6cfdbb868d5c83d61f10d2";
        })
        (buildDhallUrl {
          url = "https://raw.githubusercontent.com/dhall-lang/dhall-lang/9758483fcf20baf270dda5eceb10535d0c0aa5a8/Prelude/List/map.dhall";
          hash = "sha256-3YRf+0Vo1AMn8qgX60LRxhOLkpynWNULwzES7zyIVoA=";
          dhall-hash = "sha256:dd845ffb4568d40327f2a817eb42d1c6138b929ca758d50bc33112ef3c885680";
        })

        # This is used in ./upperAndDouble.dhall.
        (buildDhallUrl {
          url = "https://raw.githubusercontent.com/dhall-lang/dhall-lang/9758483fcf20baf270dda5eceb10535d0c0aa5a8/Prelude/Text/upperASCII.dhall";
          hash = "sha256-Ra5PvYFLBHTmXCik7pKyO5eYkvpbtzcwvJlnWueQyik=";
          dhall-hash = "sha256:45ae4fbd814b0474e65c28a4ee92b23b979892fa5bb73730bc99675ae790ca29";
        })
      ];
    };

  dhallPackageToNix = dhallPackage:
    let
      drv = stdenv.mkDerivation {
        name = "dhall-compiled.nix";

        buildCommand = ''
          # Dhall requires that the cache is writable, even if it is never written to.
          # We copy the cache from the input package to the current directory and
          # set the cache as writable.
          cp -r "${dhallPackage}/.cache" ./
          export XDG_CACHE_HOME=$PWD/.cache
          chmod -R +w ./.cache

          dhall-to-nix <<< "${dhallPackage}/binary.dhall" > $out
        '';

        buildInputs = [ dhall-nix ];
      };

    in
      import drv;

  myNixDhallPackage = dhallPackageToNix myDhallPackage;

  generateDhallDirectoryPackage =
    { src
    , file ? "package.dhall"
    }:
    stdenv.mkDerivation {
      name = "dhall-directory-package.nix";

      buildCommand = ''
        dhall-to-nixpkgs directory --url-fod --file "${file}" "${src}" > $out
      '';

      buildInputs = [ dhall-nixpkgs ];
    };

  dhallDirectoryToNix =
    { src
    , file ? "package.dhall"
    }@args:
    dhallPackageToNix (dhallPackages.callPackage (generateDhallDirectoryPackage args) {});

  myDhallFile = dhallDirectoryToNix {
    src = ./.;
    file = "mydhallfile.dhall";
  };

in

myNixDhallPackage
