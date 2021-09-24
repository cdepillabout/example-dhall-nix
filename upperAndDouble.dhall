
let upperASCII = https://raw.githubusercontent.com/dhall-lang/dhall-lang/9758483fcf20baf270dda5eceb10535d0c0aa5a8/Prelude/Text/upperASCII.dhall

in \(t : Text) -> upperASCII t ++ t
