{-# LANGUAGE OverloadedStrings #-}

module Language.Foveran.Parsing.PrettyPrinter
    ( ppAnnotTerm 
    , ppPlain
    )
    where

import           Data.String
import           Data.Rec (foldAnnot, Rec, foldRec)
import           Text.PrettyPrintPrec
import qualified Text.PrettyPrint as PP
import           Language.Foveran.Syntax.Display
import qualified Data.Text as T

name = fromString . T.unpack
names = hsep . map name

pprint :: TermCon PrecDoc -> PrecDoc
pprint (Var nm) = name nm
pprint (Set 0)  = "Set"
pprint (Set l)  = "Set" <+> int l

pprint (Arr t1 t2)    = paren 10 (hang (down t1 <+> "→") 0 t2)
pprint (Pi nms t1 t2) = paren 10 ("(" <> names nms <+> ":" <+> t1 <> ")" <+> "→" <+> t2)
pprint (Lam [] t)     = t -- FIXME this case shouldn't ever happen, but they get generated by the DataDecl stuff
pprint (Lam nms t)    = paren 10 ("\x03bb" <> names nms <> "." <+> t)
pprint (App t ts)     = paren 01 (t <+> sep (map down ts))

pprint (Prod t1 t2)      = paren 08 (down t1 <+> "×" <+> t2)
pprint (Sigma nms t1 t2) = paren 10 (hang ("(" <> names nms <+> ":" <+> t1 <> ")" <+> "×") 0 {- <+> -} t2)
pprint (Proj1 t)         = paren 01 ("fst" <+> down t)
pprint (Proj2 t)         = paren 01 ("snd" <+> down t)
pprint (Pair t1 t2)      = "«" <> (sep $ punctuate "," [resetPrec t1, resetPrec t2]) <> "»"

pprint (Sum t1 t2)             = paren 09 (down t1 <+> "+" <+> t2)
pprint (Inl t)                 = paren 01 ("inl" <+> down t)
pprint (Inr t)                 = paren 01 ("inr" <+> down t)
pprint (Case t x tP y tL z tR) =
    ("case" <+> t <+> "for" <+> name x <> "." <+> tP <+> "with")
    $$
    nest 2 (("{" <+> hang ("inl" <+> name y <> ".") 3 (resetPrec tL))
            $$
            (";" <+> hang ("inr" <+> name z <> ".") 3 (resetPrec tR))
            $$
            "}")
pprint Unit                = "𝟙"
pprint UnitI               = "()"
pprint Empty               = "𝟘"
pprint ElimEmpty           = "elimEmpty"

pprint Desc                = "Desc"
pprint (Desc_K t)          = paren 01 ("“K”" <+> down t)
pprint Desc_Id             = "“Id”"
pprint (Desc_Prod t1 t2)   = paren 08 (down t1 <+> "“×”" <+> t2)
pprint (Desc_Sum t1 t2)    = paren 09 (down t1 <+> "“+”" <+> t2)
pprint Desc_Elim           = "elimD"
pprint (Mu t)              = paren 01 ("µ" <+> down t)
pprint (Construct t)       = paren 01 ("construct" <+> down t)
pprint Induction           = "induction"

pprint IDesc               = "IDesc"
pprint (IDesc_Id t)        = paren 01 ("“IId”" <+> down t)
pprint (IDesc_Sg t1 t2)    = paren 01 ("“Σ”" <+> down t1 <+> down t2)
pprint (IDesc_Pi t1 t2)    = paren 01 ("“Π”" <+> down t1 <+> down t2)
pprint IDesc_Elim          = "elimID"

pp :: TermPos -> PrecDoc
pp = foldAnnot pprint

ppAnnotTerm :: TermPos -> PP.Doc
ppAnnotTerm x = pp x `atPrecedenceLevel` 10

ppPlain :: Rec TermCon -> PP.Doc 
ppPlain t = foldRec pprint t `atPrecedenceLevel` 10

{-
ppDecl :: Declaration -> PP.Doc
ppDecl (Assumption _ nm tm) =
  PP.hsep [ PP.text "assume", PP.text $ T.unpack nm, PP.text ":", pp tm `atPrecedenceLevel` 10, PP.semi ]
ppDecl (Definition _ nm1 tm1 nm2 tm2) =
  PP.vcat [ PP.hsep [ PP.text $ T.unpack nm1, PP.text ":", pp tm1 `atPrecedenceLevel` 10, PP.semi ]
          , PP.hsep [ PP.text $ T.unpack nm2, PP.text "=", pp tm2 `atPrecedenceLevel` 10, PP.semi ]
          ]
-}
