-- | Some pretty printing utilities.

module Language.Foveran.Util.PrettyPrinting
    ( ppPos
    , ppSpan
    )
    where

import Text.PrettyPrint as PP
import Text.Position

ppPos p =
  text "line" <+> int (posLineNum p) PP.<> comma <+> text "col" <+> int (posColumnNum p)

ppSpan (Span l r) =
  text "from" <+> ppPos l <+> text "to" <+> ppPos r

