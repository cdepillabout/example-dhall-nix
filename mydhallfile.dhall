
let mkUsersList = https://raw.githubusercontent.com/cdepillabout/example-dhall-repo/c1b0d0327146648dcf8de997b2aa32758f2ed735/example1.dhall

let map = https://raw.githubusercontent.com/dhall-lang/dhall-lang/9758483fcf20baf270dda5eceb10535d0c0aa5a8/Prelude/List/map.dhall

let UserInfo : Type =
      { home : Text
      , privateKey : Text
      , publicKey : Text
      , name : Text
      }

in map UserInfo Text (\(r : UserInfo) -> r.name) (mkUsersList 3)
  
