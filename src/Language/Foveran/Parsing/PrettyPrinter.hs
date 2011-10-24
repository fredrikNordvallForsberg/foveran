{-# LANGUAGE OverloadedStrings #-}

module Language.Foveran.Parsing.PrettyPrinter
    ( ppAnnotTerm 
    , ppAnnotTermLev
    , ppPlain
    , ppIDataDecl
    , ppIdent
    )
    where

import           Data.String
import           Data.Functor ((<$>))
import           Data.Maybe (fromMaybe)
import           Data.Rec (foldAnnot, Rec, foldRec, AnnotRec (..))
import           Text.PrettyPrintPrec
import qualified Text.PrettyPrint as PP
import           Language.Foveran.Syntax.Display
import qualified Data.Text as T

ppIdent :: IsString a => T.Text -> a -- FIXME: define a type class for pretty printers
ppIdent = fromString . T.unpack
ppIdents = hsep . map ppIdent

ppPattern :: Pattern -> PrecDoc
ppPattern (PatVar nm) = ppIdent nm
ppPattern DontCare    = "_"

ppPatterns :: [Pattern] -> PrecDoc
ppPatterns = hsep . map ppPattern

pprint :: TermCon PrecDoc -> PrecDoc
pprint (Var nm) = ppIdent nm
pprint (Set 0)  = "Set"
pprint (Set l)  = "Set" <+> int l

pprint (Pi bs t) = paren 10 $ sep (map doBinder bs ++ [t])
    where doBinder ([], t) = down t <+> "→"
          doBinder (nms,t) = "(" <> ppIdents nms <+> ":" <+> t <> ")" <+> "→"
pprint (Lam [] t)     = t -- FIXME this case shouldn't ever happen, but they get generated by the DataDecl stuff
pprint (Lam nms t)    = paren 10 (sep ["\x03bb" <> ppPatterns nms <> ".", nest 2 t])
pprint (App t ts)     = paren 01 (sep (t:map (nest 2 . down) ts))

pprint (Prod t1 t2)      = paren 08 (down t1 <+> "×" <+> t2)
pprint (Sigma nms t1 t2) = paren 10 (hang ("(" <> ppIdents nms <+> ":" <+> t1 <> ")" <+> "×") 0 t2)
pprint (Proj1 t)         = paren 01 ("fst" <+> down t) -- These precs are a hack to make the output look less weird
pprint (Proj2 t)         = paren 01 ("snd" <+> down t)
pprint (Pair t1 t2)      = "«" <> (sep $ punctuate "," [resetPrec t1, resetPrec t2]) <> "»"

pprint (Sum t1 t2)             = paren 09 (down t1 <+> "+" <+> t2)
pprint (Inl t)                 = paren 01 ("inl" <+> down t)
pprint (Inr t)                 = paren 01 ("inr" <+> down t)
pprint (Case t x tP y tL z tR) =
    ("case" <+> t <+> "for" <+> ppIdent x <> "." <+> resetPrec tP <+> "with")
    $$
    nest 2 (("{" <+> hang ("inl" <+> ppPattern y <> ".") 3 (resetPrec tL))
            $$
            (";" <+> hang ("inr" <+> ppPattern z <> ".") 3 (resetPrec tR))
            $$
            "}")
pprint Unit                = "𝟙"
pprint UnitI               = "()"
pprint Empty               = "𝟘"
pprint (ElimEmpty t1 Nothing)   = paren 01 ("absurdBy" <+> resetPrec t1)
pprint (ElimEmpty t1 (Just t2)) = paren 01 ("absurdBy" <+> resetPrec t1 $$ nest 6 "for" <+> resetPrec t2)

pprint (Eq t1 t2)          = paren 07 (sep [down t1, nest 2 "≡", t2])
pprint Refl                = "refl"
pprint (ElimEq t Nothing t2) = paren 01 ("rewriteBy" <+> resetPrec t <+> "then" $$ resetPrec t2)
pprint (ElimEq t (Just (a, e, t1)) t2) = paren 01 ("rewriteBy" <+> resetPrec t
                                                   $$ nest 3 "for" <+> ppIdent a <+> ppIdent e <> "." <+> resetPrec t1
                                                   $$ nest 2 "then" <+> resetPrec t2)

pprint Desc                = "Desc"
pprint (Desc_K t)          = paren 01 ("“K”" <+> down t)
pprint Desc_Id             = "“Id”"
pprint (Desc_Prod t1 t2)   = paren 08 (down t1 <+> "“×”" <+> t2)
pprint (Desc_Sum t1 t2)    = paren 09 (down t1 <+> "“+”" <+> t2)
pprint Desc_Elim           = "elimD"
pprint Sem                 = "sem"
pprint (Mu t)              = paren 01 ("µ" <+> down t)
pprint (Construct t)       = paren 01 ("construct" <+> down t)
pprint Induction           = "induction"

pprint IDesc               = "IDesc"
pprint (IDesc_Id t)        = paren 01 ("“IId”" <+> down t)
pprint (IDesc_Sg t1 t2)    = paren 01 ("“Σ”" <+> (down t1 $$ down t2))
pprint (IDesc_Pi t1 t2)    = paren 01 ("“Π”" <+> down t1 <+> down t2)
pprint IDesc_Elim          = "elimID"
pprint (MuI t1 t2)         = paren 01 ("µI" <+> down t1 <+> down t2)
pprint InductionI          = "inductionI"

ppAnnotTerm :: TermPos -> PP.Doc
ppAnnotTerm t = foldAnnot pprint t `atPrecedenceLevel` 10

ppAnnotTermLev :: Int -> TermPos -> PP.Doc
ppAnnotTermLev l t = foldAnnot pprint t `atPrecedenceLevel` l

ppPlain :: Rec TermCon -> PP.Doc
ppPlain t = foldRec pprint t `atPrecedenceLevel` 10

--------------------------------------------------------------------------------
ppIDataDecl :: IDataDecl -> PP.Doc
ppIDataDecl d = doc `atPrecedenceLevel` 10
    where
      doc = ("data" <+>
             ppIdent (dataName d) <+>
             hsep [ "(" <> ppIdent nm <+> ":" <+> fromDoc (ppAnnotTerm t) <> ")" | DataParameter _ nm t <- dataParameters d ] <+>
             ":" <+> fromMaybe "" (fromDoc . ppAnnotTermLev 9 <$> dataIndexType d) <+> "→" <+> "Set" <+> "where")
            $$ nest 2 (doConstructors (dataConstructors d))

      doConstructors []     = "{ };"
      doConstructors (c:cs) = vcat (("{" <+> doConstructor c) : map (\c -> ";" <+> doConstructor c) cs) $$ "};"

      doConstructor c = ppIdent (consName c) <+> ":" <+> sep (doBits (consBits c))

      doBits (Annot p (ConsPi nm t xs)) = ("(" <> ppIdent nm <+> ":" <+> fromDoc (ppAnnotTerm t) <> ")" <+> "→") : doBits xs
      doBits (Annot p (ConsArr t xs))   = (fromDoc (ppAnnotTermLev 9 t) <+> "→") : doBits xs
      doBits (Annot p (ConsEnd nm ts))  = [ppIdent nm <+> sep (map (fromDoc . ppAnnotTermLev 0) ts)]
