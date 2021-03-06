{-# LANGUAGE TupleSections #-}

module Language.Foveran.Parsing.Parser
    ( file )
    where

import           Control.Applicative
import           Data.Maybe
import           Data.Rec
import           Data.Pair
import           Text.ParserCombinators hiding (Return)
import           Text.Position
import qualified Data.Text as T
import qualified Language.Foveran.Parsing.Token as Tok
import           Language.Foveran.Syntax.Display

{------------------------------------------------------------------------------}
binary f t1 t2 = Annot (makeSpan t1 t2) (f t1 t2)

unary :: (TermPos -> TermCon TermPos) -> Span -> TermPos -> TermPos
unary f p t = Annot (makeSpan p t) (f t)

binaryPrefix f p t1 t2 = Annot (makeSpan p t2) (f t1 t2)

keyword :: TermCon TermPos -> Span -> TermPos
keyword c s = Annot s c

leftDelimited f p x y = Annot (makeSpan p y) (f x y)

delimited p1 c p2 = Annot (makeSpan p1 p2) c

optBinary t1 Nothing           = t1
optBinary t1 (Just (conn, t2)) = binary conn t1 t2

{------------------------------------------------------------------------------}

number :: Parser Tok.Token (Int,Span)
number = (\(x,y) -> (read $ T.unpack x,y)) <$> tokenWithText Tok.Number

identifier :: Parser Tok.Token Ident
identifier = fst <$> tokenWithText Tok.Ident

pattern :: Parser Tok.Token Pattern
pattern = PatVar   <$> identifier
          <|>
          PatTuple <$  token Tok.LDoubleAngle <*> ((:) <$> pattern <*> (many (token Tok.Comma *> pattern))) <* token Tok.RDoubleAngle
          <|>
          PatNull  <$  token Tok.Underscore

patternList :: Parser Tok.Token [Pattern]
patternList =
    (:) <$> pattern <*> patternList
    <|>
    pure []

file :: Parser Tok.Token [Declaration]
file = token Tok.LBrace *> declarations <* token Tok.RBrace <* eos

declarations :: Parser Tok.Token [Declaration]
declarations = many (token Tok.Semicolon)
               *> many (declaration <* some (token Tok.Semicolon))

declaration :: Parser Tok.Token Declaration
declaration =
    (\p nm t -> AssumptionDecl (Assume (makeSpan p t) nm t))
        <$> token Tok.Assume
        <*  commit
        <*> identifier
        <*  token Tok.Colon
        <*> term
    <|>
    (\(nm1,p) t1 (nm2,p2) argPatterns t2 ->
         DefinitionDecl $ Definition (makeSpan p t2) nm1 t1 nm2 argPatterns t2)
        <$> tokenWithText Tok.Ident <* commit <* token Tok.Colon  <*> term <*  some (token Tok.Semicolon)
        <*> tokenWithText Tok.Ident
        <*> patternList
        <*  token Tok.Equals <*> term
    <|>
    IDataDecl <$> idata
    <|>
    (\p tm -> Normalise tm)
       <$> token Tok.Normalise
       <*> term

dataParamList :: Parser Tok.Token [DataParameter]
dataParamList =
    (\pl nm t pr params -> DataParameter (makeSpan pl pr) nm t : params)
        <$> token Tok.LParen
        <*> identifier
        <*  token Tok.Colon
        <*> term
        <*> token Tok.RParen
        <*> dataParamList
    <|>
    pure []

--------------------------------------------------------------------------------
idata :: Parser Tok.Token IDataDecl
idata =
    (\pl nm params idxType constrs pr -> IData (makeSpan pl pr) nm params idxType constrs) <$>
    token Tok.Data <*> identifier
                   <*> dataParamList
                   <*  token Tok.Colon <*> optional (term09 <* token Tok.Arrow) <* token Tok.Set
                   <*  token Tok.Where
                   <*  token Tok.LBrace <*> iconstructors <*> token Tok.RBrace

iconstructors :: Parser Tok.Token [IConstructor]
iconstructors =
  (\x xs -> x:xs) <$> iconstructor <*> many (token Tok.Semicolon *> iconstructor)
  <|>
  pure []

iconstructor :: Parser Tok.Token IConstructor
iconstructor =
    (\(nm,p) bits -> IConstructor (makeSpan p bits) nm bits)
    <$> tokenWithText Tok.ConstructorName
    <*  token Tok.Colon
    <*> constructorbits
    where
      constructorbits =
          (\p ident t1 t2 -> Annot (makeSpan p t2) (ConsPi ident t1 t2))
            <$> token Tok.LParen
            <*> identifier
            <*  token Tok.Colon
            <*  commit
            <*> term10
            <*  token Tok.RParen
            <*  token Tok.Arrow
            <*> constructorbits
          <|>
          binary ConsArr <$> term09 <* token Tok.Arrow <*> constructorbits
          <|> -- FIXME: better source position here
          (\(nm,p) ts -> Annot (makeSpan p p) (ConsEnd nm ts)) <$> tokenWithText Tok.Ident <*> many term00

--------------------------------------------------------------------------------
clauses :: Parser Tok.Token [(Ident,[Pattern],TermPos)]
clauses =
  pure [] <|> ((:) <$> clause <*> many (token Tok.Semicolon *> clause))

clause :: Parser Tok.Token (Ident,[Pattern],TermPos)
clause = (,,) <$> (fst <$> tokenWithText Tok.ConstructorName)
              <*> patternList
              <*  token Tok.FullStop
              <*> term

--------------------------------------------------------------------------------
term :: Parser Tok.Token TermPos
term = term10

term10 :: Parser Tok.Token TermPos
term10 =
    leftDelimited Lam <$> token Tok.Lambda <* commit <*> patternList <* token Tok.FullStop <*> term10
    <|>
    (\p patterns t1 con t2 -> Annot (makeSpan p t2) (con patterns t1 t2))
       <$> token Tok.LParen
       <*> patternList
       <*  token Tok.Colon
       <*  commit
       <*> term10
       <*  token Tok.RParen
       <*> ((\nms t1 t2 -> Pi [(nms,t1)] t2) <$ token Tok.Arrow <|> Sigma <$ token Tok.Times)
       <*> term10
    <|>
    -- anonymous Pi/function types
    -- right associative
    optBinary <$> term09 <*> optional ((\x -> Pi [([],x)],) <$ token Tok.Arrow <*> term10)

term09 :: Parser Tok.Token TermPos
term09 =
    -- sum types, and their descriptions
    -- right associative
    optBinary <$> term08 <*> (optional $ (Sum,) <$ token Tok.Plus <*> term09)

term08 :: Parser Tok.Token TermPos
term08 =
    -- product types
    -- right associative
    optBinary <$> term07 <*> (optional $ (Prod,) <$ token Tok.Times <*> term08  
                                         <|>
                                         (Desc_Prod,) <$ token Tok.QuoteTimes <*> term08)

term07 :: Parser Tok.Token TermPos
term07 =
    optBinary <$> term06 <*> (optional $ (Eq,) <$ token Tok.Eq <*> term06)

term06 :: Parser Tok.Token TermPos
term06 =
    optBinary <$> term01 <*> (optional $ (TypeAscrip,) <$ token Tok.Colon <*> term01)

term01 :: Parser Tok.Token TermPos
term01 =
    unary Return <$> token Tok.Return <*> term00
    <|>
    unary Call <$> token Tok.Call <*> term00
    <|>
    -- left injection
    unary Inl <$> token Tok.Inl <*> term00
    <|>
    -- right injection
    unary Inr <$> token Tok.Inr <*> term00
    <|>
    -- constant functor descriptions
    unary Desc_K <$> token Tok.QuoteK <*> term00
    <|>
    unary Construct <$> token Tok.Construct <*> term00
    <|>
    unary IDesc_Id <$> token Tok.Quote_IId <*> term00
    <|>
    binaryPrefix IDesc_Sg <$> token Tok.Quote_Sg <*> term00 <*> term00
    <|>
    binaryPrefix IDesc_Pi <$> token Tok.Quote_Pi <*> term00 <*> term00
    <|>
    (\p t1 t2 -> Annot (makeSpan p t2) (ElimEmpty t1 (Just t2)))
      <$> (token Tok.ElimEmpty <|> token Tok.AbsurdBy)
      <*> term10
      <*  token Tok.For
      <*> term10
    <|>
    (\p t1 -> Annot (makeSpan p t1) (ElimEmpty t1 Nothing))
      <$> (token Tok.ElimEmpty <|> token Tok.AbsurdBy)
      <*> term10
    <|>
    (\p t t1 t2 -> Annot (makeSpan p t2)
                         (ElimEq t t1 t2)) <$>
      (token Tok.ElimEq <|> token Tok.RewriteBy)
      <*> term10
      <*> optional ((\a x t -> (a,x,t)) <$ token Tok.For <*> identifier <*> identifier <* token Tok.FullStop <*> term10)
      <*  token Tok.Then
      <*> term10
    <|>
    (\p x t1 t2 -> Annot (makeSpan p t2) (IDesc_Bind t1 x t2))
      <$> token Tok.Bind
      <*> pattern
      <*  token Tok.LeftArrow
      <*> term10
      <*  token Tok.In
      <*> term10
    <|>
    (\p t1 t2 -> Annot (makeSpan p t2) (Generalise t1 t2))
      <$> token Tok.Generalise
      <*> term10
      <*  token Tok.Then
      <*> term10
    <|>
    -- function application
    -- left associative
    (\t ts -> case ts of [] -> t
                         ts -> Annot (makeSpan t (last ts)) (case t of Annot p (NamedConstructor id _) -> NamedConstructor id ts
                                                                       _ -> App t ts))
      <$> term00
      <*> many term00

term00 :: Parser Tok.Token TermPos
term00 =
    (\p nm args ty p' -> Annot (makeSpan p p') (LabelledType nm args ty))
      <$> token Tok.LAngle
      <*> identifier
      <*> many (Pair <$ token Tok.LParen <*> term10 <* token Tok.Colon <*> term10 <* token Tok.RParen)
      <*  token Tok.Colon
      <*> term10
      <*> token Tok.RAngle
    <|>
    unary Proj1 <$> token Tok.Fst <* commit <*> term00
    <|>
    unary Proj2 <$> token Tok.Snd <* commit <*> term00
    <|>
    (\p (id,p') -> Annot (makeSpan p p') (RecurseOn id)) <$> token Tok.RecurseOn <*> tokenWithText Tok.Ident
    <|>
    binaryPrefix MuI <$> token Tok.MuI <*> term00 <*> term00
    <|>
    (\(nm,p) -> Annot p (NamedConstructor nm [])) <$> tokenWithText Tok.ConstructorName
    <|>
    (\p tD i tA p' -> Annot (makeSpan p p') (SemI tD i tA))
      <$> token Tok.SemI <* token Tok.LSqBracket <*> term10 <* token Tok.Comma <*> pattern <* token Tok.FullStop <*> term10 <*> token Tok.RSqBracket
    <|>
    (\p tD i1 tA i2 tB tf tx p' -> Annot (makeSpan p p') (MapI tD i1 tA i2 tB tf tx))
      <$> token Tok.MapI
      <*  token Tok.LSqBracket
      <*> term10                                   <* token Tok.Comma
      <*> pattern <* token Tok.FullStop <*> term10 <* token Tok.Comma
      <*> pattern <* token Tok.FullStop <*> term10 <* token Tok.Comma
      <*> term10                                   <* token Tok.Comma
      <*> term10
      <*> token Tok.RSqBracket
    <|>
    (\p tD x tA i a tP tx p' -> Annot (makeSpan p p') (LiftI tD x tA i a tP tx))
      <$> token Tok.LiftI
      <*  token Tok.LSqBracket
      <*> term10
      <*  token Tok.Comma
      <*> pattern <* token Tok.FullStop <*> term10
      <*  token Tok.Comma
      <*> pattern <*> pattern <* token Tok.FullStop <*> term10
      <*  token Tok.Comma
      <*> term10
      <*> token Tok.RSqBracket
    <|>
    keyword UnitI <$> token Tok.UnitValue
    <|>
    keyword Refl <$> token Tok.Refl
    <|>
    -- FIXME: extend the left and right positions of the term to include the parens
    token Tok.LParen *> term10 <* token Tok.RParen
    <|>
    (\pl tms pr -> Annot (makeSpan pl pr) $ Tuple tms)
      <$> token Tok.LDoubleAngle
      <*> ((:) <$> term10 <*> many (token Tok.Comma *> term10))
      <*> token Tok.RDoubleAngle
    <|>
    delimited <$> token Tok.Case
              <*  commit
              <*> (Case <$> term10
                        <*> optional ((,) <$ token Tok.For <*> identifier <* token Tok.FullStop <*> term10)
                        <*  token Tok.With
                        <*  token Tok.LBrace
                        <*  token Tok.Inl <*> pattern <* token Tok.FullStop <*> term10
                        <*  token Tok.Semicolon
                        <*  token Tok.Inr <*> pattern <* token Tok.FullStop <*> term10)
              <*> token Tok.RBrace
    <|>
    -- FIXME: this should be more like the Haskell precedence, like Case
    (\p t tP pi px pp tK -> Annot (makeSpan p tK) (Eliminate t tP pi px pp tK))
      <$> token Tok.Eliminate
      <*> term10
      <*> optional ((,,) <$ token Tok.For <*> pattern <*> pattern <* token Tok.FullStop <*> term10)
      <*  token Tok.Then
      <*> pattern
      <*> pattern
      <*> pattern
      <*  token Tok.FullStop
      <*> term10
    <|>
    -- FIXME: probably the FIXME above applies to this too
    delimited <$> token Tok.CasesOn
              <*  commit
              <*> (CasesOn False <$> term10
                                 <*  token Tok.With
                                 <*  token Tok.LBrace
                                 <*> clauses)
              <*> token Tok.RBrace
    <|>
    -- FIXME: probably the FIXME above applies to this too
    delimited <$> token Tok.RecursionOn
              <*  commit
              <*> (CasesOn True <$> term10
                                <*  token Tok.With
                                <*  token Tok.LBrace
                                <*> clauses)
              <*> token Tok.RBrace
    <|>
    (\p x -> case x of Nothing     -> Annot p (Set 0)
                       Just (l,p') -> Annot (makeSpan p p') (Set l)) <$> token Tok.Set <*> optional number
    <|>
    keyword Empty <$> token Tok.EmptyType
    <|>
    keyword Unit <$> token Tok.UnitType
    <|>
    keyword IDesc <$> token Tok.IDesc
    <|>
    keyword IDesc_Elim <$> token Tok.IDesc_Elim
    <|>
    keyword UserHole <$> token Tok.Hole
    <|>
    (\(nm,p) -> Annot p (Var nm)) <$> tokenWithText Tok.Ident
