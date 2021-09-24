let upperASCII =
      https://raw.githubusercontent.com/dhall-lang/dhall-lang/9758483fcf20baf270dda5eceb10535d0c0aa5a8/Prelude/Text/upperASCII.dhall sha256:45ae4fbd814b0474e65c28a4ee92b23b979892fa5bb73730bc99675ae790ca29

in  \(t : Text) -> upperASCII t ++ t
