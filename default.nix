# This Nix file is a proof of concept for how some additional Dhall-related
# functions should look in Nixpkgs.
#
# This is specifically for
# https://github.com/dhall-lang/dhall-haskell/pull/2304.

let
  nixpkgsSrc = builtins.fetchTarball {
    # nixos-unstable as of 2021-09-16.
    url = "https://github.com/NixOS/nixpkgs/archive/bcd607489d76795508c48261e1ad05f5d4b7672f.tar.gz";
    sha256 = "0yjp9lrhzvyh9dc4b9dl456fr6nlchfmn85adq0vi4pnwfmh90z6";
  };
in

with import nixpkgsSrc {};

rec {

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

  # This is the function suggested in
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
      # most users won't write calls to buildDhallUrl by hand, but calls to
      # buildDhallUrl will be generated automatically by dhall-to-nixpkgs.)
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

  # This is an example of using buildDhallUrl.
  # Try running `nix-build ./default.nix -A myFODDhallFile` and take a look at
  # the result.
  myFODDhallFile = buildDhallUrl {
    url = "https://raw.githubusercontent.com/cdepillabout/example-dhall-repo/c1b0d0327146648dcf8de997b2aa32758f2ed735/example1.dhall";
    hash = "sha256-ZTSiQUXpPbPfPvS8OeK6dDQE6j6NbP27ho1cg9YfENI=";
    dhall-hash = "sha256:6534a24145e93db3df3ef4bc39e2ba743404ea3e8d6cfdbb868d5c83d61f10d2";
  };

  # This is basically an example of what I think
  # `dhall-to-nixpkgs directory --url-fod` should generate.
  #
  # This is very similar to the current output of `dhall-to-nixpkgs directory`,
  # but the dependencies have been inlined with `buildDhallUrl`.
  #
  # You can test this with a command like
  # `nix-build ./default.nix -A myDhallPackage`
  myDhallPackage =
    # XXX: The actual `dhall-to-nixpkgs directory --url-fod` function should
    # generate a function that takes a `buildDhallDirectoryPackage` and
    # `buildDhallUrl` argument so it can be used with
    # `dhallPackages.callPackage`, but I removed that here so it is easier to
    # play around with in the repl.
    dhallPackages.buildDhallDirectoryPackage {
      name = "mydhallfile";
      src = ./.;
      file = "./mydhallfile.dhall";
      source = false;
      document = false;
      dependencies = [
        # Dependencies for `./mydhallfile.dhall`.
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

        # Dependencies for `./upperAndDouble.dhall`, which is a local import in
        # `./mydhallfile.dhall`.
        (buildDhallUrl {
          url = "https://raw.githubusercontent.com/dhall-lang/dhall-lang/9758483fcf20baf270dda5eceb10535d0c0aa5a8/Prelude/Text/upperASCII.dhall";
          hash = "sha256-Ra5PvYFLBHTmXCik7pKyO5eYkvpbtzcwvJlnWueQyik=";
          dhall-hash = "sha256:45ae4fbd814b0474e65c28a4ee92b23b979892fa5bb73730bc99675ae790ca29";
        })
      ];
    };

  # This function is similar to the current dhallToNix function in Nixpkgs, but
  # it takes a Dhall Nix package instead of raw Dhall code.
  #
  # This function is used below in dhallDirectoryToNix.  I imagine adding
  # dhallPackageToNix, since it is a good compliment to the current dhallToNix
  # function, but it is not strictly necessary.  It could be inlined in
  # dhallDirectoryToNix.
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

  # This is an example of using dhallPackageToNix.
  #
  # This calls dhallPackageToNix on myDhallPackage defined above.
  # You can see the output of this in the console:
  #
  # $ nix-instantiate --eval -E '(import ./default.nix).myNixDhallPackage'
  # [ "BILLBILLbillbill" "JANEJANEjanejane" "TESTTESTtesttest" "TESTTESTtesttest" "TESTTESTtesttest" ]
  myNixDhallPackage = dhallPackageToNix myDhallPackage;

  # This function calls `dhall-to-nixpkgs directory --url-fod` within a Nix
  # derivation.
  #
  # This is possible because `dhall-to-nixpkgs directory --url-fod` will turn
  # remote Dhall imports into FOD (with buildDhallUrl above), so
  # no network access is necessary.
  #
  # myDhallPackage above is an example of a Nix file that
  # generateDhallDirectoryPackage would produce.
  #
  # This is another helper function for dhallDirectoryToNix.  It is not
  # necessary to export this in Nixpkgs.  It could be inlined in
  # dhallDirectoryToNix.
  #
  # (Note that this doesn't currently work until
  # `dhall-to-nixpkgs directory --url-fod` actually gets implemented.)
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

  # This function is the culmination of the Nix code in this file.  The above
  # Nix functions have been building to this.
  #
  # dhallDirectoryToNix is similar to the current dhallToNix function in Nixpkgs,
  # but it takes a directory of Dhall files as input.  It turns all Dhall remote imports
  # into FOD for ease-of-use.
  #
  # This first generates a Dhall Nix package with
  # generateDhallDirectoryPackage, and then transforms it to Nix with
  # dhallPackageToNix.
  #
  # This uses IFD, so it won't be possible to use this in Nixpkgs, but it
  # should make it easy for end-users to read the output of a directory of Dhall
  # code in Nix.
  #
  # (Note that this doesn't currently work until generateDhallDirectoryPackage
  # is fully implemented.)
  dhallDirectoryToNix =
    { src
    , file ? "package.dhall"
    }@args:
    dhallPackageToNix (dhallPackages.callPackage (generateDhallDirectoryPackage args) {});

  # This is an example of using dhallDirectoryToNix on the Dhall files in this
  # repo.
  #
  # You can see that this would be quite easy for an end-user to use.  All the
  # heavy-lifting is done behind-the-scenes by generateDhallDirectoryPackage,
  # dhall-to-nixpkgs, and dhallPackageToNix.
  myDhallFile = dhallDirectoryToNix {
    src = ./.;
    file = "mydhallfile.dhall";
  };

}
